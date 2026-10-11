import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'offline_audio_storage.dart';
import 'offline_audio_types.dart';
export 'offline_audio_types.dart';

/// A recorded talk is downloaded part by part. A failed part never makes
/// the whole talk look ready, and cancellation cannot commit a late response.
class OfflineAudioDownloads extends ChangeNotifier {
  OfflineAudioDownloads({OfflineAudioStorage? storage})
      : _storage = storage ?? PlatformOfflineAudioStorage();
  static final instance = OfflineAudioDownloads();
  static const _indexKey = 'sermons.downloads.v1';
  static const _queueKey = 'sermons.download.queue.v1';
  final _retained = <String, AudioDownloadRecord>{};
  bool _paused = false;
  Future<void> _queueWrites = Future.value();
  Future<void>? _pausing;
  bool get paused => _paused;
  int get pendingCount => _queue.length + _active.length;
  final OfflineAudioStorage _storage;
  final _records = <String, AudioDownloadRecord>{};
  final _status = <String, AudioDownloadStatus>{};
  final _items = <String, AudioDownloadItem>{};
  final _queue = <AudioDownloadItem>[];
  final _active = <String, DownloadCancellation>{};
  final _tasks = <Future<void>>{};
  final _tasksById = <String, Future<void>>{};
  Future<void>? _initializing, _cancelling;
  bool _loaded = false;
  bool get supported => _storage.supported;
  List<AudioDownloadRecord> get records => List.unmodifiable(_records.values);
  List<AudioDownloadItem> get items => List.unmodifiable(_items.values);
  int get totalBytes => _records.values.fold(0, (a, b) => a + b.bytes);
  AudioDownloadStatus? status(String id) => _status[id];
  String? sourceFor(String id) =>
      _records.containsKey(id) ? _storage.sourceFor(id) : null;
  bool isReady(Iterable<AudioDownloadItem> parts) =>
      parts.isNotEmpty && parts.every((p) => _records[p.id]?.item.url == p.url);
  Future<void> init() => _loaded ? Future.value() : (_initializing ??= _load());
  Future<void> _load() async {
    try {
      if (!supported) return;
      await _storage.init();
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_indexKey);
      if (raw != null) {
        // Keep the previous schema intact before any later user command writes.
        if (!prefs.containsKey('$_indexKey.pre-recovery')) {
          await prefs.setString('$_indexKey.pre-recovery', raw);
        }
        for (final j in (jsonDecode(raw) as List)) {
          AudioDownloadRecord rec;
          try {
            rec = AudioDownloadRecord.fromJson(
                (j as Map).cast<String, dynamic>());
          } catch (_) {
            continue;
          }
          _retained[rec.item.id] = rec;
          _items[rec.item.id] = rec.item;
          try {
            final storage = _storage;
            final journalKey = 'sermons.download.replace.${rec.item.id}';
            final previousRaw = prefs.getString(journalKey);
            if (previousRaw != null && storage is RecoverableAudioStorage) {
              // The persisted index decides whether a replacement committed.
              final previous = AudioDownloadRecord.fromJson(
                  (jsonDecode(previousRaw) as Map).cast<String, dynamic>());
              if (previous.item.url == rec.item.url &&
                  previous.bytes == rec.bytes) {
                await (storage as RecoverableAudioStorage)
                    .rollback(rec.item.id);
              } else {
                await (storage as RecoverableAudioStorage).commit(rec.item.id);
              }
              await prefs.remove(journalKey);
            }
            final valid = storage is RecoverableAudioStorage
                ? await (storage as RecoverableAudioStorage)
                    .validate(rec.item.id, rec.bytes)
                : await storage.contains(rec.item.id);
            if (valid) {
              _records[rec.item.id] = rec;
              _status[rec.item.id] = AudioDownloadStatus(
                  AudioDownloadState.downloaded,
                  received: rec.bytes,
                  total: rec.bytes);
            } else {
              _status[rec.item.id] = const AudioDownloadStatus(
                  AudioDownloadState.failed,
                  error:
                      'Saved audio is missing or incomplete. Its original download record is retained.');
            }
          } catch (e) {
            _status[rec.item.id] = AudioDownloadStatus(
                AudioDownloadState.failed,
                error: 'Storage unavailable: $e');
          }
        }
      }
      // Initialization is read-only for the main index. A missing file or
      // temporary read error must never erase its recovery metadata.
      final queueRaw = prefs.getString(_queueKey);
      if (queueRaw != null) {
        try {
          for (final j in jsonDecode(queueRaw) as List) {
            try {
              final item = AudioDownloadItem.fromJson(
                  (j as Map).cast<String, dynamic>());
              if (_records[item.id]?.item.url == item.url ||
                  _queue.any((p) => p.id == item.id)) {
                continue;
              }
              _items[item.id] = item;
              _queue.add(item);
              _status[item.id] =
                  const AudioDownloadStatus(AudioDownloadState.paused);
            } catch (_) {
              /* One malformed row must not hide later pending items. */
            }
          }
          _paused = _queue.isNotEmpty;
        } catch (_) {/* Retain the original queue on disk for recovery. */}
      }
      _loaded = true;
      notifyListeners();
    } finally {
      _initializing = null;
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(
        _indexKey,
        jsonEncode({..._retained, ..._records}
            .values
            .map((r) => r.toJson())
            .toList()))) {
      throw StateError('Could not save the download index');
    }
  }

  Future<void> _persistQueue() {
    final ids = {..._active.keys, ..._queue.map((p) => p.id)};
    final raw = jsonEncode([
      for (final id in ids)
        if (_items[id] != null) _items[id]!.toJson(),
    ]);
    return _queueWrites =
        _queueWrites.catchError((Object _) {}).then((_) async {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(_queueKey, raw)) {
        throw StateError('Could not save the pending download queue');
      }
    });
  }

  Future<void> refresh() async {
    if (pendingCount != 0) return;
    _loaded = false;
    _records.clear();
    _status.clear();
    await init();
  }

  Future<void> pauseAll() => _pausing ??= _pause().whenComplete(() {
        _pausing = null;
      });

  Future<void> _pause() async {
    await _cancelling;
    await init();
    _paused = true;
    final interrupted = [for (final id in _active.keys) _items[id]!];
    for (final token in _active.values) {
      token.cancel();
    }
    await Future.wait(_tasks.toList());
    for (final item in interrupted) {
      if (_records[item.id]?.item.url != item.url &&
          !_queue.any((q) => q.id == item.id)) {
        _queue.insert(0, item);
      }
    }
    for (final item in _queue) {
      _status[item.id] = const AudioDownloadStatus(AudioDownloadState.paused);
    }
    await _persistQueue();
    notifyListeners();
  }

  Future<void> resumeAll() async {
    await _pausing;
    await init();
    _paused = false;
    for (final item in _queue) {
      _status[item.id] = const AudioDownloadStatus(AudioDownloadState.queued);
    }
    notifyListeners();
    _pump();
  }

  Future<void> retryFailed() => enqueue(_items.values
      .where((p) => _status[p.id]?.state == AudioDownloadState.failed)
      .toList());

  Future<void> enqueue(Iterable<AudioDownloadItem> requested) async {
    if (!supported) return;
    await _cancelling;
    await _pausing;
    await init();
    for (final item in requested) {
      if (_records[item.id]?.item.url == item.url ||
          _active.containsKey(item.id) ||
          _queue.any((q) => q.id == item.id)) {
        continue;
      }
      _items[item.id] = item;
      _queue.add(item);
      _status[item.id] = AudioDownloadStatus(
          _paused ? AudioDownloadState.paused : AudioDownloadState.queued);
    }
    await _persistQueue();
    notifyListeners();
    _pump();
  }

  void _pump() {
    if (_cancelling != null || _paused) return;
    // Sermon parts can exceed 30 MB. One stream bounds mobile memory/IO.
    if (_active.isNotEmpty || _queue.isEmpty) return;
    final item = _queue.removeAt(0);
    final token = DownloadCancellation();
    _active[item.id] = token;
    late Future<void> task;
    task = _download(item, token).whenComplete(() {
      _active.remove(item.id);
      _tasks.remove(task);
      _tasksById.remove(item.id);
      unawaited(_persistQueue().catchError((Object _) {}));
      notifyListeners();
      _pump();
    });
    _tasks.add(task);
    _tasksById[item.id] = task;
    unawaited(task);
  }

  Future<void> _download(
      AudioDownloadItem item, DownloadCancellation token) async {
    _status[item.id] =
        const AudioDownloadStatus(AudioDownloadState.downloading);
    notifyListeners();
    final previous = _records[item.id];
    var wroteFile = false;
    var protected = false;
    final storage = _storage;
    try {
      if (previous != null && storage is RecoverableAudioStorage) {
        final prefs = await SharedPreferences.getInstance();
        if (!await prefs.setString('sermons.download.replace.${item.id}',
            jsonEncode(previous.toJson()))) {
          throw StateError('Could not save replacement recovery record');
        }
        await (storage as RecoverableAudioStorage).protect(item.id);
        protected = true;
      }
      final bytes = await _storage.download(item, token, (n, total) {
        if (!token.cancelled) {
          _status[item.id] = AudioDownloadStatus(AudioDownloadState.downloading,
              received: n, total: total);
          notifyListeners();
        }
      });
      wroteFile = true;
      token.check();
      _records[item.id] = AudioDownloadRecord(item, bytes);
      _retained[item.id] = _records[item.id]!;
      await _persist();
      token.check();
      // The index now describes the committed bytes. Removing the recovery
      // copy is cleanup only; a cleanup failure must not roll back good audio.
      if (protected) {
        try {
          await (storage as RecoverableAudioStorage).commit(item.id);
          await (await SharedPreferences.getInstance())
              .remove('sermons.download.replace.${item.id}');
        } catch (_) {}
      }
      _status[item.id] = AudioDownloadStatus(AudioDownloadState.downloaded,
          received: bytes, total: bytes);
    } catch (e) {
      _records.remove(item.id);
      try {
        if (protected) {
          await (storage as RecoverableAudioStorage).rollback(item.id);
          _records[item.id] = previous!;
          _retained[item.id] = previous;
        } else {
          if (previous == null || wroteFile) await _storage.remove(item.id);
          if (previous != null && !wroteFile) _records[item.id] = previous;
        }
        await _persist();
        if (protected) {
          await (await SharedPreferences.getInstance())
              .remove('sermons.download.replace.${item.id}');
        }
      } catch (_) {}
      if (token.cancelled || e is DownloadCancelled) {
        _status.remove(item.id);
      } else {
        _status[item.id] =
            AudioDownloadStatus(AudioDownloadState.failed, error: '$e');
      }
    }
    notifyListeners();
  }

  Future<void> cancelAll() {
    return _cancelling ??= _cancel().whenComplete(() {
      _cancelling = null;
      _pump();
    });
  }

  Future<void> _cancel() async {
    await _pausing;
    for (final q in _queue) {
      _status.remove(q.id);
    }
    _queue.clear();
    _paused = false;
    for (final token in _active.values) {
      token.cancel();
    }
    await Future.wait(_tasks.toList());
    await _persistQueue();
    notifyListeners();
  }

  Future<void> delete(String id) async {
    await _pausing;
    await _cancelling;
    await init();
    _queue.removeWhere((p) => p.id == id);
    _active[id]?.cancel();
    await _tasksById[id];
    final previous = _retained[id];
    try {
      // Only this writer is canceled. Other queued downloads keep their place.
      await _storage.remove(id);
      _records.remove(id);
      _retained.remove(id);
      await _persist();
      _status.remove(id);
      _items.remove(id);
      await _persistQueue();
    } catch (e) {
      if (previous != null) _retained[id] = previous;
      _status[id] = AudioDownloadStatus(
          _records.containsKey(id)
              ? AudioDownloadState.downloaded
              : AudioDownloadState.failed,
          received: _records[id]?.bytes ?? 0,
          error: 'Could not finish deleting this download: $e');
      notifyListeners();
      rethrow;
    }
    notifyListeners();
    _pump();
  }
}
