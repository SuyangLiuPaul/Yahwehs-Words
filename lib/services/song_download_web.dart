import 'dart:async';
import 'offline_audio_storage_web.dart';
import 'offline_audio_types.dart';
import 'dart:convert';
import 'dart:js_interop';
// For `has` — Cache Storage is absent in non-secure contexts, so its
// presence has to be probed rather than assumed.
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web/web.dart' as web;

import 'package:yahwehs_words/models/song.dart';
import 'package:yahwehs_words/services/song_download_types.dart';
import 'package:yahwehs_words/services/song_player_service.dart';

/// Web build of the download service — real offline downloads, backed
/// by the Cache Storage API.
///
/// This used to be a no-op stub on the reasoning that a browser gives
/// no managed file system. It does give one: Cache Storage, which
/// holds whole responses on disk under a quota the page can ask to
/// have made durable.
///
/// Playback reads it **directly**, not through a Service Worker. The
/// worker route was tried and abandoned: a worker only sees requests
/// from pages inside its scope, and root scope already belongs to
/// Flutter's own generated worker — two scripts cannot share one.
/// Instead a downloaded song's cached body is turned into a blob URL
/// and handed to the audio element, which needs no interception, works
/// with the tab offline, and sidesteps Range requests entirely because
/// a blob URL is never fetched over HTTP.
///
/// Two honest differences from the native builds, both surfaced rather
/// than hidden:
///
///  * **The browser may evict it.** `navigator.storage.persist()` is
///    requested on first download, which on most browsers makes the
///    cache exempt from routine eviction, but it is a request and not
///    a guarantee. Downloads are re-checked against the cache on every
///    launch, so an evicted song reverts to "not downloaded" instead of
///    lying about being available.
///  * **The quota is not ours to set.** `estimate()` reports what is
///    left, and a download that would not fit fails with that reason
///    rather than filling the disk and dying halfway.
class SongDownloadService extends ChangeNotifier {
  SongDownloadService._();

  static final SongDownloadService instance = SongDownloadService._();

  /// Cache Storage is on every browser this app supports, but it is
  /// absent in non-secure contexts — so check rather than assume.
  static bool get isSupported {
    try {
      return (web.window as JSObject).has('caches');
    } catch (_) {
      return false;
    }
  }

  /// Kept as `song-media-v1` so anything an earlier build cached is
  /// still found. index.html's self-heal deliberately exempts every
  /// `song-media-` bucket from its cache sweep — downloads live here.
  static const _cacheName = 'song-media-v1';
  static const _indexKey = 'songs.downloads.web.v1';

  /// One at a time. The native service runs three, but every byte here
  /// crosses our own Netlify proxy rather than going direct to the
  /// church, so this is the download that costs us bandwidth — and a
  /// browser tab is a worse place to run three large streams.
  static const _maxConcurrent = 1;

  final Map<String, _WebDownload> _index = {};

  /// songId → object URL for its cached audio.
  ///
  /// Built up front rather than on demand because the player resolves
  /// a source SYNCHRONOUSLY: reading Cache Storage at play time would
  /// mean an await between the user's tap and `play()`, which is
  /// exactly what costs the gesture activation iOS requires. An object
  /// URL is only a handle to a blob the browser already has on disk,
  /// so holding a few hundred of them is cheap.
  final Map<String, String> _blobUrls = {};

  /// Blob URLs for cached sheet music, keyed by song id. Separate from
  /// [_blobUrls] because a song can have audio offline and no score, or
  /// (after a failed PDF) the reverse never — but the two are fetched
  /// independently and must be revoked independently.
  final Map<String, String> _scoreBlobUrls = {};
  final Map<String, SongDownloadStatus> _status = {};
  final List<Song> _queue = [];
  final Set<String> _active = {};

  final _tokens = <String, DownloadCancellation>{};
  final _tasks = <Future<void>>{};
  Future<void>? _cancelFuture, _initFuture;
  bool _loaded = false;
  bool _cancelled = false;
  int _batchTotal = 0;
  int _batchDone = 0;
  int _batchFailed = 0;
  String? _lastError;

  Future<void> init() => _loaded ? Future.value() : (_initFuture ??= _load());
  Future<void> _load() async {
    if (!isSupported) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_indexKey);
      if (raw != null) {
        final decoded = json.decode(raw) as Map<String, dynamic>;
        for (final e in decoded.entries) {
          final m = e.value as Map<String, dynamic>;
          _index[e.key] = _WebDownload(
            url: m['url'] as String,
            bytes: (m['bytes'] as num?)?.toInt() ?? 0,
            scoreUrl: m['scoreUrl'] as String?,
          );
        }
      }

      // Reconcile against the cache, exactly as the native service
      // reconciles against the filesystem. The browser can evict
      // without telling us, and an index that still claims a song is
      // downloaded would send a plane passenger to a dead play button.
      final cache = await _cache();
      final gone = <String>[];
      for (final e in _index.entries) {
        final hit = await cache.match(e.value.url.toJS).toDart;
        if (hit == null) gone.add(e.key);
      }
      for (final id in gone) {
        _index.remove(id);
      }
      if (gone.isNotEmpty) await _persist();

      for (final e in _index.entries) {
        _status[e.key] = SongDownloadStatus(
          state: SongDownloadState.done,
          bytes: e.value.bytes,
        );
        await _makeBlobUrl(e.key, e.value.url, cache);
        final scoreUrl = e.value.scoreUrl;
        if (scoreUrl != null) {
          final hit = await cache.match(scoreUrl.toJS).toDart;
          if (hit != null) {
            _scoreBlobUrls[e.key] =
                web.URL.createObjectURL(await hit.blob().toDart);
          }
        }
      }
      _loaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('[SongDownloadService/web] init failed: $e');
      _lastError = 'Download storage unavailable: $e';
      notifyListeners();
    } finally {
      _initFuture = null;
    }
  }

  /// Turn a cached response into an object URL the player can use.
  Future<void> _makeBlobUrl(String songId, String url,
      [web.Cache? open]) async {
    try {
      final cache = open ?? await _cache();
      final hit = await cache.match(url.toJS).toDart;
      if (hit == null) return;
      final blob = await hit.blob().toDart;
      _blobUrls[songId] = web.URL.createObjectURL(blob);
    } catch (e) {
      // Falling back to the network URL is correct here: the song
      // simply streams instead of playing from disk.
      debugPrint('[SongDownloadService/web] blob url failed: $e');
    }
  }

  void _revoke(String songId) {
    for (final u in [
      _blobUrls.remove(songId),
      _scoreBlobUrls.remove(songId),
    ]) {
      if (u == null) continue;
      try {
        web.URL.revokeObjectURL(u);
      } catch (_) {/* already gone */}
    }
  }

  /// Cache [song]'s sheet music alongside its audio. Never throws — the
  /// score is a bonus and its failure must not touch the song's status.
  Future<void> _downloadScore(Song song, DownloadCancellation token) async {
    final source = song.scoreUrl;
    if (source == null || _scoreBlobUrls.containsKey(song.id)) return;
    final url = SongPlayerService.resolvePlaybackUrl(source);
    try {
      final controller = web.AbortController();
      token.abort = () => controller.abort();
      token.check();
      final res = await web.window
          .fetch(url.toJS, web.RequestInit(signal: controller.signal))
          .toDart
          .timeout(const Duration(seconds: 15), onTimeout: () {
        controller.abort();
        throw TimeoutException('Score download stalled');
      });
      if (!res.ok) return;
      final blob = await res.blob().toDart.timeout(const Duration(seconds: 30),
          onTimeout: () {
        controller.abort();
        throw TimeoutException('Score download stalled');
      });
      token.check();
      if (blob.size.toInt() < 5) return;
      final prefix =
          (await blob.slice(0, 5).arrayBuffer().toDart).toDart.asUint8List();
      if (!String.fromCharCodes(prefix).startsWith('%PDF-')) return;
      final cache = await _cache();
      await cache.put(url.toJS, web.Response(blob as JSAny, _pdfInit())).toDart;
      token.check();
      _scoreBlobUrls[song.id] = web.URL.createObjectURL(blob);
      final audio = _index[song.id];
      if (audio != null) {
        _index[song.id] =
            _WebDownload(url: audio.url, bytes: audio.bytes, scoreUrl: url);
        await _persist();
      }
    } catch (e) {
      debugPrint('[SongDownloadService/web] ${song.id} score failed: $e');
    } finally {
      token.abort = null;
      if (token.cancelled) {
        final old = _scoreBlobUrls.remove(song.id);
        if (old != null) web.URL.revokeObjectURL(old);
        try {
          await (await _cache()).delete(url.toJS).toDart;
          final audio = _index[song.id];
          if (audio != null) {
            _index[song.id] = _WebDownload(url: audio.url, bytes: audio.bytes);
            await _persist();
          }
        } catch (_) {/* Cancellation must finish even if storage is full. */}
      }
    }
  }

  /// Same reasoning as [_audioInit]: a blob stored without a type comes
  /// back as `application/octet-stream`, and a PDF viewer handed that
  /// will refuse it.
  static web.ResponseInit _pdfInit() => web.ResponseInit(
        status: 200,
        statusText: 'OK',
        headers: {'Content-Type': 'application/pdf'}.jsify() as JSObject,
      );

  /// The source playback should use for [song] — the offline copy when
  /// there is one, else null so the caller falls back to the network.
  String? offlineSourceFor(Song song) => _blobUrls[song.id];

  Future<web.Cache> _cache() async =>
      (await web.window.caches.open(_cacheName).toDart);

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setString(
      _indexKey,
      json.encode({
        for (final e in _index.entries)
          e.key: {
            'url': e.value.url,
            'bytes': e.value.bytes,
            'scoreUrl': e.value.scoreUrl
          },
      }),
    );
    if (!saved) {
      throw StateError('Could not save download index');
    }
  }

  // ── Queries ─────────────────────────────────────────────────────

  SongDownloadStatus statusOf(Song song) =>
      _status[song.id] ?? const SongDownloadStatus();

  bool isDownloaded(Song song) => _index.containsKey(song.id);

  /// Always null: on web there is no filesystem path. The offline copy
  /// is reached through a blob URL instead — see [offlineSourceFor]
  /// and [resolveSongSource].
  String? localPathFor(Song song) => null;

  /// Always null, for the same reason as [localPathFor]. Present so the
  /// score viewer can ask both builds the same two questions without a
  /// `kIsWeb` branch: a path first, then a blob URL.
  String? localScorePathFor(Song song) => null;

  /// Blob URL of the cached sheet music, when it was downloaded.
  String? offlineScoreSourceFor(Song song) => _scoreBlobUrls[song.id];

  bool hasOfflineScore(Song song) => _scoreBlobUrls.containsKey(song.id);

  int get downloadedCount => _index.length;
  int get totalBytes => _index.values.fold(0, (sum, d) => sum + d.bytes);
  int get pendingCount => _queue.length + _active.length;
  bool get isBusy => pendingCount > 0;
  int get batchTotal => _batchTotal;
  int get batchDone => _batchDone;

  /// See the native service: "N / M" alone cannot tell a slow batch
  /// from one where every request is failing.
  int get batchFailed => _batchFailed;
  String? get lastError => _lastError;
  double get batchProgress =>
      _batchTotal == 0 ? 0 : (_batchDone / _batchTotal).clamp(0.0, 1.0);

  /// Rough size of a selection, for the confirm dialog.
  ///
  /// Same arithmetic as the native build — duration at a typical
  /// 128 kbps, flat 4 MB where the source publishes no duration — so
  /// both platforms quote the same figure for the same selection. A
  /// cruder guess here would have had web and phone disagree about the
  /// size of an identical download.
  static int estimateBytes(Iterable<Song> songs) {
    var total = 0;
    for (final s in songs) {
      if (!s.hasPlayableAudio) continue;
      final secs = s.durationSec;
      total += secs != null && secs > 0
          ? (secs * 128 * 1000 / 8).round()
          : 4 * 1024 * 1024;
    }
    return total;
  }

  static String formatBytes(int bytes) => formatDownloadBytes(bytes);

  // ── Commands ────────────────────────────────────────────────────

  Future<void> enqueue(Iterable<Song> songs) async {
    if (!isSupported) return;
    await _cancelFuture;
    await init();
    _cancelled = false;

    // Ask to be exempt from routine eviction. Best-effort: Firefox
    // prompts, Safari decides on its own, and a refusal only means the
    // cache is evictable — which the reconcile on init already handles.
    try {
      await web.window.navigator.storage.persist().toDart;
    } catch (_) {/* not fatal */}

    final wanted = [
      for (final s in songs)
        if (s.hasPlayableAudio && !isDownloaded(s) && !_isQueued(s)) s,
    ];
    if (wanted.isEmpty) return;

    _queue.addAll(wanted);
    _batchTotal += wanted.length;
    for (final s in wanted) {
      _status[s.id] = const SongDownloadStatus(state: SongDownloadState.queued);
    }
    notifyListeners();
    _pump();
  }

  bool _isQueued(Song song) =>
      _active.contains(song.id) || _queue.any((s) => s.id == song.id);

  Future<void> cancelAll() => _cancelFuture ??= _cancel().whenComplete(() {
        _cancelFuture = null;
      });
  Future<void> _cancel() async {
    _cancelled = true;
    for (final song in _queue) {
      _status.remove(song.id);
    }
    _queue.clear();
    for (final token in _tokens.values.toList()) {
      token.cancel();
    }
    await Future.wait(_tasks.toList());
    _batchTotal = _batchDone = _batchFailed = 0;
    _lastError = null;
    notifyListeners();
  }

  Future<void> delete(Song song) async {
    await cancelAll();
    final entry = _index.remove(song.id);
    _status.remove(song.id);
    _revoke(song.id);
    if (entry != null) {
      try {
        final cache = await _cache();
        await cache.delete(entry.url.toJS).toDart;
        if (entry.scoreUrl != null) {
          await cache.delete(entry.scoreUrl!.toJS).toDart;
        }
      } catch (e) {
        debugPrint('[SongDownloadService/web] delete failed: $e');
      }
      await _persist();
    }
    notifyListeners();
  }

  Future<void> deleteAll() async {
    await cancelAll();
    final urls = [
      for (final d in _index.values) ...[
        d.url,
        if (d.scoreUrl != null) d.scoreUrl!
      ]
    ];
    for (final id in _index.keys.toList()) {
      _revoke(id);
    }
    _index.clear();
    _status.clear();
    try {
      final cache = await _cache();
      for (final u in urls) {
        await cache.delete(u.toJS).toDart;
      }
    } catch (e) {
      debugPrint('[SongDownloadService/web] deleteAll failed: $e');
    }
    await _persist();
    notifyListeners();
  }

  // ── Worker ──────────────────────────────────────────────────────

  void _pump() {
    while (_active.length < _maxConcurrent && _queue.isNotEmpty) {
      if (_cancelled) return;
      final song = _queue.removeAt(0);
      _active.add(song.id);
      late Future<void> task;
      task = _download(song).whenComplete(() {
        _active.remove(song.id);
        _tasks.remove(task);
        _batchDone++;
        if (_queue.isEmpty && _active.isEmpty) {
          _batchTotal = _batchDone = 0;
        }
        notifyListeners();
        if (!_cancelled) _pump();
      });
      _tasks.add(task);
      unawaited(task);
    }
  }

  Future<void> _download(Song song) async {
    final source = song.audioUrl ??
        (song.audioTracks.isEmpty ? null : song.audioTracks.first.url);
    if (source == null) return;
    final url = SongPlayerService.resolvePlaybackUrl(source);
    final storage =
        PlatformOfflineAudioStorage(cacheName: _cacheName, keyFor: (id) => id);
    final token = DownloadCancellation();
    _tokens[song.id] = token;
    _status[song.id] =
        const SongDownloadStatus(state: SongDownloadState.downloading);
    notifyListeners();
    try {
      final bytes = await storage.download(
          AudioDownloadItem(
              id: url, title: song.title, url: source, sermonId: ''),
          token, (n, total) {
        if (token.cancelled) return;
        _status[song.id] = SongDownloadStatus(
            state: SongDownloadState.downloading,
            bytes: n,
            progress: total > 0 ? (n / total).clamp(0, 1) : null);
        notifyListeners();
      });
      token.check();
      _index[song.id] = _WebDownload(url: url, bytes: bytes);
      _status[song.id] =
          SongDownloadStatus(state: SongDownloadState.done, bytes: bytes);
      _blobUrls[song.id] = storage.sourceFor(url)!;
      await _persist();
      token.check();
      if (!token.cancelled) await _downloadScore(song, token);
    } catch (e) {
      _index.remove(song.id);
      _revoke(song.id);
      try {
        await storage.remove(url);
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
}

class _WebDownload {
  final String url;
  final int bytes;
  final String? scoreUrl;
  const _WebDownload({required this.url, required this.bytes, this.scoreUrl});
}

/// Where playback should read [song] from.
///
/// A downloaded song resolves to a blob URL backed by Cache Storage —
/// no network, so it plays with the tab offline. Everything else
/// resolves to the same-origin proxy path, which is what makes web
/// playback possible at all (the church servers send no CORS headers).
String? resolveSongSource(Song song, String url) {
  final primary = song.audioUrl ??
      (song.audioTracks.isEmpty ? null : song.audioTracks.first.url);
  return (url == primary
          ? SongDownloadService.instance.offlineSourceFor(song)
          : null) ??
      SongPlayerService.resolvePlaybackUrl(url);
}
