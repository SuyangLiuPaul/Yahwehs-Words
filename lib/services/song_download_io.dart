import 'dart:async';
import 'offline_audio_storage_io.dart';
import 'offline_audio_types.dart';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yahwehs_words/models/song.dart';
import 'package:yahwehs_words/services/song_download_types.dart';
import 'package:yahwehs_words/services/song_player_service.dart';

/// Downloads song audio for offline listening.
///
/// **This file is the native half.** The browser is not unsupported —
/// it has its own full implementation in `song_download_web.dart`,
/// backed by Cache Storage instead of files, with the same queue,
/// progress, cancel, delete and space accounting. The split exists
/// only because this file imports `dart:io`, which does not compile
/// for web at all.
///
/// The two differ in what they can promise, and both say so: files
/// here are ours until deleted, whereas a browser may evict its cache
/// under quota pressure.
///
/// Design notes:
///
///  • **Only the primary audio** is fetched by default. Pulling every
///    mix, MV and score for all 543 songs would be many gigabytes;
///    someone wanting a specific instrumental can queue that song's
///    other tracks explicitly.
///  • **Bounded concurrency.** Three at a time — enough to saturate a
///    normal connection without opening 500 sockets against three
///    small church servers.
///  • **Failure is per-song.** One dead URL marks that song failed and
///    the queue keeps going; a batch of 300 is not lost to one 404.
///  • **Resumes across restarts** at song granularity: the index only
///    records completed files, and a partial file is written to
///    `.part` and renamed on success, so an interrupted download is
///    never mistaken for a finished one.
class SongDownloadService extends ChangeNotifier {
  SongDownloadService._()
      : _directory = getApplicationSupportDirectory,
        _clientFactory = http.Client.new;
  @visibleForTesting
  SongDownloadService.forTesting(
      {required Future<Directory> Function() directory,
      required http.Client Function() clientFactory})
      : _directory = directory,
        _clientFactory = clientFactory;
  final Future<Directory> Function() _directory;
  final http.Client Function() _clientFactory;

  static final SongDownloadService instance = SongDownloadService._();

  /// File downloads exist on native only — see the class docs.
  static bool get isSupported => !kIsWeb;

  static const _indexKey = 'songs.downloads.v1';
  static const _maxConcurrent = 3;

  /// songId → relative filename of the completed download.
  final Map<String, _DownloadRecord> _index = {};
  final Map<String, _DownloadRecord> _retained = {};
  final Map<String, SongDownloadStatus> _status = {};
  final List<Song> _queue = [];
  final Set<String> _active = {};
  final Map<String, Song> _items = {};
  final Map<String, Future<void>> _tasksById = {};
  Future<void>? _pausing;
  Future<void> _queueWrites = Future.value();
  bool _paused = false;
  bool get paused => _paused;
  static const _queueKey = "$_indexKey.queue";
  final Map<String, DownloadCancellation> _tokens = {};
  final Set<Future<void>> _tasks = {};
  Future<void>? _cancelFuture, _initFuture;

  Directory? _dir;
  bool _loaded = false;
  bool _cancelled = false;

  // ── Lifecycle ───────────────────────────────────────────────────

  /// Reads the on-disk index. Safe to call repeatedly.
  Future<void> init() => _loaded ? Future.value() : (_initFuture ??= _load());

  Future<void> _load() async {
    if (!isSupported) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_indexKey);
      if (raw != null) {
        if (!prefs.containsKey('$_indexKey.pre-recovery')) {
          await prefs.setString('$_indexKey.pre-recovery', raw);
        }
        final decoded = json.decode(raw) as Map<String, dynamic>;
        for (final entry in decoded.entries) {
          try {
            final record = _DownloadRecord.fromJson(
                (entry.value as Map).cast<String, dynamic>());
            _index[entry.key] = record;
            _retained[entry.key] = record;
          } catch (_) {/* Original malformed row remains in the backup. */}
        }
      }
      // Reconcile against reality: a user can clear app storage, and
      // the OS can evict caches. An index entry whose file is gone
      // would otherwise render as "downloaded" and then fail to play.
      await _mediaDir();
      final missing = <String>[];
      for (final entry in _index.entries) {
        final storage = PlatformOfflineAudioStorage(
            directory: _mediaDir,
            directoryName: '',
            fileName: entry.value.filename);
        try {
          if (!await storage.validate(entry.key, entry.value.bytes)) {
            missing.add(entry.key);
          }
        } catch (_) {
          // Retain this record; a per-file read error must not hide others.
          missing.add(entry.key);
        }
      }
      for (final id in missing) {
        _index.remove(id);
        _status[id] = const SongDownloadStatus(
            state: SongDownloadState.failed,
            error:
                'Saved audio is missing or incomplete; its original record is retained.');
      }
      // Do not rewrite the legacy index because a file is unavailable.

      for (final entry in _index.entries) {
        _status[entry.key] = SongDownloadStatus(
          state: SongDownloadState.done,
          bytes: entry.value.bytes,
        );
      }
      final queueRaw = prefs.getString(_queueKey);
      if (queueRaw != null) {
        try {
          for (final row in jsonDecode(queueRaw) as List) {
            try {
              final song = Song.fromJson((row as Map).cast<String, dynamic>());
              if (_index.containsKey(song.id) ||
                  _queue.any((s) => s.id == song.id)) {
                continue;
              }
              _items[song.id] = song;
              _queue.add(song);
              _status[song.id] =
                  const SongDownloadStatus(state: SongDownloadState.paused);
            } catch (_) {/* Keep malformed queue rows on disk. */}
          }
        } catch (_) {/* Do not erase a damaged queue during startup. */}
      }
      _paused = _queue.isNotEmpty;
      _batchTotal = _queue.length;
      _loaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('[SongDownloadService] init failed: $e');
      _lastError = 'Download storage unavailable: $e';
      notifyListeners();
    } finally {
      _initFuture = null;
    }
  }

  Future<Directory> _mediaDir() async {
    if (_dir != null) return _dir!;
    // Application *support*, not documents: this is a reproducible
    // cache the user did not author, so it should not show up in
    // file browsers or iCloud backups.
    final base = await _directory();
    final dir = Directory('${base.path}/song_media');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    _dir = dir;
    return dir;
  }

  Future<void> _persistQueue() {
    final raw = jsonEncode([
      for (final id in {..._active, ..._queue.map((s) => s.id)})
        if (_items[id] != null && !_index.containsKey(id))
          songQueueRecord(_items[id]!),
    ]);
    return _queueWrites =
        _queueWrites.catchError((Object _) {}).then((_) async {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(_queueKey, raw)) {
        throw StateError('Could not save pending songs');
      }
    });
  }

  Future<void> pauseAll() => _pausing ??= _pause().whenComplete(() {
        _pausing = null;
      });
  Future<void> _pause() async {
    await _cancelFuture;
    await init();
    _paused = true;
    final interrupted = [for (final id in _active) _items[id]!];
    for (final token in _tokens.values.toList()) {
      token.cancel();
    }
    await Future.wait(_tasks.toList());
    for (final song in interrupted) {
      if (!_index.containsKey(song.id) && !_queue.any((s) => s.id == song.id)) {
        _queue.insert(0, song);
      }
    }
    for (final song in _queue) {
      _status[song.id] =
          const SongDownloadStatus(state: SongDownloadState.paused);
    }
    _batchTotal = _queue.length;
    _batchDone = 0;
    await _persistQueue();
    notifyListeners();
  }

  Future<void> resumeAll() async {
    await _pausing;
    await _cancelFuture;
    await init();
    _paused = false;
    _cancelled = false;
    for (final song in _queue) {
      _status[song.id] =
          const SongDownloadStatus(state: SongDownloadState.queued);
    }
    await _persistQueue();
    notifyListeners();
    _pump();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(
        _indexKey,
        json.encode({
          for (final e in {..._retained, ..._index}.entries)
            e.key: e.value.toJson()
        }))) {
      throw StateError('Could not save download index');
    }
  }

  // ── Queries ─────────────────────────────────────────────────────

  SongDownloadStatus statusOf(Song song) =>
      _status[song.id] ?? const SongDownloadStatus();

  bool isDownloaded(Song song) => _index.containsKey(song.id);

  /// Local file for [song]'s audio, when it has been downloaded.
  /// Returns null on web and for anything not downloaded.
  String? localPathFor(Song song) {
    final rec = _index[song.id];
    if (rec == null || _dir == null) return null;
    return '${_dir!.path}/${rec.filename}';
  }

  /// Local sheet-music PDF for [song], when one was downloaded with it.
  /// Null for songs that publish no score, whose score failed, or that
  /// were downloaded before scores were included.
  String? localScorePathFor(Song song) {
    final rec = _index[song.id];
    final name = rec?.scoreFilename;
    if (name == null || _dir == null) return null;
    return '${_dir!.path}/$name';
  }

  bool hasOfflineScore(Song song) => _index[song.id]?.scoreFilename != null;

  /// Always null on native — the offline score is a real file, reached
  /// through [localScorePathFor]. Present so the score viewer can ask
  /// both builds the same two questions without a `kIsWeb` branch.
  String? offlineScoreSourceFor(Song song) => null;

  int get downloadedCount => _index.length;

  /// Counts the scores too — this figure is what the Downloads page
  /// reports as space used, and it has to match what is actually on
  /// disk or the page is lying about the user's storage.
  int get totalBytes =>
      _index.values.fold<int>(0, (sum, r) => sum + r.bytes + r.scoreBytes);

  int get pendingCount => _queue.length + _active.length;

  bool get isBusy => pendingCount > 0;

  /// Overall progress across the current batch, 0.0–1.0.
  double get batchProgress {
    if (_batchTotal == 0) return 0;
    return (_batchDone / _batchTotal).clamp(0.0, 1.0);
  }

  int get batchTotal => _batchTotal;
  int get batchDone => _batchDone;

  /// How many of [batchDone] failed, and why the last one did.
  ///
  /// Without these the UI could only show "N / M", which is the same
  /// display whether songs are downloading slowly or every single one
  /// is failing — the user's report was "我其实看不到下载进程都不知道到底
  /// 有没有真的下载", and they were right that the screen could not
  /// tell them.
  int get batchFailed => _batchFailed;
  String? get lastError => _lastError;

  int _batchTotal = 0;
  int _batchDone = 0;
  int _batchFailed = 0;
  String? _lastError;

  /// How long to wait for a server to start answering.

  /// What [songs] would cost to download, in bytes.
  ///
  /// The catalogue does not publish file sizes, so this is an estimate
  /// from duration at a typical 128 kbps, falling back to a flat 4 MB
  /// where the source publishes no duration either. Deliberately shown
  /// as approximate in the UI — quoting a precise figure we cannot
  /// know would be worse than admitting the range.
  static int estimateBytes(Iterable<Song> songs) {
    var total = 0;
    for (final s in songs) {
      if (!s.hasPlayableAudio) continue;
      final secs = s.durationSec;
      total += secs != null && secs > 0
          ? (secs * 128 * 1000 / 8).round()
          : 4 * 1024 * 1024;
      // Sheet music now comes down with the audio. A flat 400 KB: the
      // scores are 1-4 page engravings and the catalogue publishes no
      // sizes, so this is the same honest guess the audio figure is,
      // and leaving it out would under-quote 579 of 606 songs.
      if (s.scoreUrl != null) total += 400 * 1024;
    }
    return total;
  }

  /// Shared with the web stub so the estimate shown before a download
  /// and the total shown after it read identically.
  static String formatBytes(int bytes) => formatDownloadBytes(bytes);

  // ── Commands ────────────────────────────────────────────────────

  /// Queue [songs] for download. Already-downloaded and audio-less
  /// entries are skipped, so "download all" is idempotent and a
  /// re-run after a partial failure only retries what is missing.
  Future<void> enqueue(Iterable<Song> songs) async {
    if (!isSupported) return;
    await _cancelFuture;
    await _pausing;
    await init();
    if (!_loaded) {
      throw StateError(_lastError ?? 'Download storage unavailable');
    }
    _cancelled = false;

    final seen = <String>{};
    final toAdd = songs
        .where((s) => s.hasPlayableAudio)
        .where((s) => !_index.containsKey(s.id))
        .where((s) => !_active.contains(s.id))
        .where((s) => !_queue.any((q) => q.id == s.id))
        .where((s) => seen.add(s.id))
        .toList();
    if (toAdd.isEmpty) return;

    for (final s in toAdd) {
      _items[s.id] = s;
      _status[s.id] = SongDownloadStatus(
          state: _paused ? SongDownloadState.paused : SongDownloadState.queued);
    }
    _queue.addAll(toAdd);
    _batchTotal += toAdd.length;
    notifyListeners();
    await _persistQueue();
    _pump();
  }

  /// Stop the batch. In-flight downloads are aborted and their partial
  /// files removed; completed ones stay.
  Future<void> cancelAll() => _cancelFuture ??= _cancel().whenComplete(() {
        _cancelFuture = null;
      });
  Future<void> _cancel() async {
    await _pausing;
    await init();
    _cancelled = true;
    _paused = false;
    for (final song in _queue) {
      _status.remove(song.id);
    }
    _queue.clear();
    for (final token in _tokens.values.toList()) {
      token.cancel();
    }
    await Future.wait(_tasks.toList());
    _batchTotal = _batchDone = _batchFailed = 0;
    await _persistQueue();
    _lastError = null;
    notifyListeners();
  }

  Future<void> delete(Song song) async {
    await _pausing;
    await _cancelFuture;
    await init();
    _queue.removeWhere((s) => s.id == song.id);
    _tokens[song.id]?.cancel();
    await _tasksById[song.id];
    await _deleteId(song.id);
    _items.remove(song.id);
    _status.remove(song.id);
    await _persistQueue();
    notifyListeners();
  }

  Future<void> _deleteId(String id) async {
    final rec = _index[id] ?? _retained[id];
    if (rec == null) return;
    try {
      final dir = await _mediaDir();
      for (final name in [rec.filename, rec.scoreFilename]) {
        if (name == null) continue;
        final file = File('${dir.path}/$name');
        final type = await FileSystemEntity.type(file.path, followLinks: false);
        if (type == FileSystemEntityType.directory) {
          throw FileSystemException(
              'Expected an audio file, found a directory', file.path);
        }
        if (type != FileSystemEntityType.notFound) await file.delete();
      }
      _index.remove(id);
      _retained.remove(id);
      await _persist();
      _status.remove(id);
    } catch (e) {
      _retained[id] = rec;
      _status[id] = SongDownloadStatus(
          state: SongDownloadState.failed,
          error: 'Could not finish deleting download: $e');
      _lastError = '$e';
      notifyListeners();
      rethrow;
    }
    notifyListeners();
  }

  /// Delete known downloaded media only; never erase an index after a
  /// filesystem error or recursively sweep unindexed files.
  Future<void> deleteAll() async {
    await cancelAll();
    for (final id in {..._retained.keys, ..._index.keys}) {
      await _deleteId(id);
    }
  }

  // ── Worker ──────────────────────────────────────────────────────

  void _pump() {
    if (_paused) return;
    if (_cancelled) return;
    while (_active.length < _maxConcurrent && _queue.isNotEmpty) {
      final song = _queue.removeAt(0);
      _active.add(song.id);
      late Future<void> task;
      task = _download(song).whenComplete(() {
        _active.remove(song.id);
        _tasks.remove(task);
        _tasksById.remove(song.id);
        unawaited(_persistQueue().catchError((Object e) {
          _lastError = '$e';
          notifyListeners();
        }));
        _batchDone++;
        if (_queue.isEmpty && _active.isEmpty) {
          _batchTotal = _batchDone = 0;
        }
        notifyListeners();
        if (!_cancelled) _pump();
      });
      _tasks.add(task);
      _tasksById[song.id] = task;
      unawaited(task);
    }
  }

  Future<void> _download(Song song) async {
    final url = song.audioUrl ??
        (song.audioTracks.isNotEmpty ? song.audioTracks.first.url : null);
    if (url == null) return;
    final token = DownloadCancellation();
    _tokens[song.id] = token;
    final name = _filenameFor(song.id, url);
    final storage = PlatformOfflineAudioStorage(
        directory: _mediaDir,
        directoryName: '',
        fileName: name,
        clientFactory: _clientFactory);
    _status[song.id] = const SongDownloadStatus(
        state: SongDownloadState.downloading, progress: 0);
    notifyListeners();
    try {
      final bytes = await storage.download(
          AudioDownloadItem(
              id: song.id, title: song.title, url: url, sermonId: ''),
          token, (n, total) {
        if (token.cancelled) return;
        _status[song.id] = SongDownloadStatus(
            state: SongDownloadState.downloading,
            progress: total > 0 ? (n / total).clamp(0, 1) : null,
            bytes: n);
        notifyListeners();
      });
      token.check();
      _index[song.id] = _DownloadRecord(filename: name, bytes: bytes);
      await _persist();
      token.check();
      _status[song.id] =
          SongDownloadStatus(state: SongDownloadState.done, bytes: bytes);
      if (!token.cancelled) await _downloadScore(song, token);
    } catch (e) {
      _index.remove(song.id);
      try {
        await storage.remove(song.id);
        await _persist();
      } catch (_) {}
      if (token.cancelled || e is DownloadCancelled) {
        _status.remove(song.id);
      } else {
        _status[song.id] =
            SongDownloadStatus(state: SongDownloadState.failed, error: '$e');
        _batchFailed++;
        _lastError = '$e';
      }
    } finally {
      _tokens.remove(song.id);
      notifyListeners();
    }
  }

  /// Fetch [song]'s sheet music next to its audio. Best-effort by
  /// design — see the call site. Never throws.
  ///
  /// Not streamed: scores are a few hundred KB against several MB of
  /// audio, so there is no progress worth reporting and a plain `get`
  /// keeps the failure surface small. It is also not cancellable, for
  /// the same reason — by the time it runs the expensive part is done.
  Future<void> _downloadScore(Song song, DownloadCancellation token) async {
    final url = song.scoreUrl;
    final rec = _index[song.id];
    if (url == null || rec == null || rec.scoreFilename != null) return;
    final client = _clientFactory();
    token.abort = client.close;
    File? partial;
    try {
      token.check();
      final resp =
          await client.get(Uri.parse(url)).timeout(const Duration(seconds: 30));
      token.check();
      if (resp.statusCode != 200 || resp.bodyBytes.isEmpty) return;
      // The churches' sites answer a missing file with an HTML page and
      // a 200, so a "successful" fetch can be the site's 404 page. A
      // PDF starts with %PDF-; anything else is not sheet music and
      // storing it would show the user a broken viewer later.
      final b = resp.bodyBytes;
      if (b.length < 5 ||
          b[0] != 0x25 ||
          b[1] != 0x50 ||
          b[2] != 0x44 ||
          b[3] != 0x46) {
        debugPrint('[SongDownloadService] ${song.id} score is not a PDF — '
            'the site probably served an error page with HTTP 200');
        return;
      }
      final dir = await _mediaDir();
      final name = '${sha1.convert(utf8.encode(song.id))}.pdf';
      final tmp = File('${dir.path}/$name.part');
      partial = tmp;
      await tmp.writeAsBytes(b, flush: true);
      token.check();
      await tmp.rename('${dir.path}/$name');
      _index[song.id] = rec.withScore(name, b.length);
      await _persist();
      notifyListeners();
    } catch (e) {
      debugPrint('[SongDownloadService] ${song.id} score failed: $e');
    } finally {
      client.close();
      token.abort = null;
      if (partial != null && await partial.exists()) {
        await partial.delete();
      }
    }
  }

  /// Stable filename: the song id is not filesystem-safe (it contains
  /// `:` and, for Cahaya, arbitrary title text), so hash it and keep
  /// the source extension.
  static String _filenameFor(String songId, String url) {
    final digest = sha1.convert(utf8.encode(songId)).toString();
    final ext = (Uri.tryParse(url)?.path.toLowerCase() ?? '').endsWith('.m4a')
        ? 'm4a'
        : 'mp3';
    return '$digest.$ext';
  }
}

class _DownloadRecord {
  final String filename;
  final int bytes;

  /// The sheet-music PDF stored alongside the audio, when the song has
  /// one and it downloaded. Null covers three different cases that all
  /// behave the same way — the song publishes no score, the score
  /// failed, or the record predates scores being downloaded at all.
  final String? scoreFilename;
  final int scoreBytes;

  const _DownloadRecord({
    required this.filename,
    required this.bytes,
    this.scoreFilename,
    this.scoreBytes = 0,
  });

  /// Short keys because this is re-encoded into SharedPreferences on
  /// every completed download. The two score keys are omitted when
  /// absent so existing records keep their current size, and
  /// [fromJson] tolerates their absence — an index written by an older
  /// build must keep loading, or an upgrade silently forgets every
  /// download the user has.
  Map<String, dynamic> toJson() => {
        'f': filename,
        'b': bytes,
        if (scoreFilename != null) 's': scoreFilename,
        if (scoreBytes > 0) 'sb': scoreBytes,
      };

  factory _DownloadRecord.fromJson(Map<String, dynamic> j) => _DownloadRecord(
        filename: j['f'] as String,
        bytes: (j['b'] as num?)?.toInt() ?? 0,
        scoreFilename: j['s'] as String?,
        scoreBytes: (j['sb'] as num?)?.toInt() ?? 0,
      );

  _DownloadRecord withScore(String name, int size) => _DownloadRecord(
        filename: filename,
        bytes: bytes,
        scoreFilename: name,
        scoreBytes: size,
      );
}

/// Resolve what the player should actually open for [song].
///
/// A downloaded file wins over the network every time — that is the
/// whole point of downloading it, and it also means a user on a train
/// keeps listening when the connection drops mid-song.
String? resolveSongSource(Song song, String url) {
  if (SongDownloadService.isSupported) {
    final local = SongDownloadService.instance.localPathFor(song);
    // Only the primary audio is downloaded, so an alternate mix still
    // streams even when the song shows as downloaded.
    final primary = song.audioUrl ??
        (song.audioTracks.isEmpty ? null : song.audioTracks.first.url);
    if (local != null && url == primary) return local;
  }
  return SongPlayerService.resolvePlaybackUrl(url);
}
