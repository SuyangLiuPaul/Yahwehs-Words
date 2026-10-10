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
  final OfflineAudioStorage _storage;
  final _records = <String, AudioDownloadRecord>{};
  final _status = <String, AudioDownloadStatus>{};
  final _items = <String, AudioDownloadItem>{};
  final _queue = <AudioDownloadItem>[];
  final _active = <String, DownloadCancellation>{};
  final _tasks = <Future<void>>{};
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
        for (final j in (jsonDecode(raw) as List)) {
          try {
            final rec = AudioDownloadRecord.fromJson(
                (j as Map).cast<String, dynamic>());
            if (await _storage.contains(rec.item.id)) {
              _records[rec.item.id] = rec;
              _items[rec.item.id] = rec.item;
              _status[rec.item.id] = AudioDownloadStatus(
                  AudioDownloadState.downloaded,
                  received: rec.bytes,
                  total: rec.bytes);
            }
          } catch (_) {
            /* One corrupt record cannot hide the other downloads. */
          }
        }
      }
      await _persist();
      _loaded = true;
      notifyListeners();
    } finally {
      _initializing = null;
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(_indexKey,
        jsonEncode(_records.values.map((r) => r.toJson()).toList()))) {
      throw StateError('Could not save the download index');
    }
  }

  Future<void> enqueue(Iterable<AudioDownloadItem> requested) async {
    if (!supported) return;
    await _cancelling;
    await init();
    for (final item in requested) {
      if (_records[item.id]?.item.url == item.url ||
          _active.containsKey(item.id) ||
          _queue.any((q) => q.id == item.id)) {
        continue;
      }
      _items[item.id] = item;
      _queue.add(item);
      _status[item.id] = const AudioDownloadStatus(AudioDownloadState.queued);
    }
    notifyListeners();
    _pump();
  }

  void _pump() {
    if (_cancelling != null) return;
    // Sermon parts can exceed 30 MB. One stream bounds mobile memory/IO.
    if (_active.isNotEmpty || _queue.isEmpty) return;
    final item = _queue.removeAt(0);
    final token = DownloadCancellation();
    _active[item.id] = token;
    late Future<void> task;
    task = _download(item, token).whenComplete(() {
      _active.remove(item.id);
      _tasks.remove(task);
      notifyListeners();
      _pump();
    });
    _tasks.add(task);
    unawaited(task);
  }

  Future<void> _download(
      AudioDownloadItem item, DownloadCancellation token) async {
    _status[item.id] =
        const AudioDownloadStatus(AudioDownloadState.downloading);
    notifyListeners();
    try {
      final bytes = await _storage.download(item, token, (n, total) {
        if (!token.cancelled) {
          _status[item.id] = AudioDownloadStatus(AudioDownloadState.downloading,
              received: n, total: total);
          notifyListeners();
        }
      });
      token.check();
      _records[item.id] = AudioDownloadRecord(item, bytes);
      await _persist();
      token.check();
      _status[item.id] = AudioDownloadStatus(AudioDownloadState.downloaded,
          received: bytes, total: bytes);
    } catch (e) {
      _records.remove(item.id);
      try {
        await _storage.remove(item.id);
        await _persist();
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
    for (final q in _queue) {
      _status.remove(q.id);
    }
    _queue.clear();
    for (final token in _active.values) {
      token.cancel();
    }
    await Future.wait(_tasks.toList());
    notifyListeners();
  }

  Future<void> delete(String id) async {
    // Wait for the writer before removal; otherwise it can recreate the file.
    await cancelAll();
    await _storage.remove(id);
    _records.remove(id);
    _status.remove(id);
    _items.remove(id);
    await _persist();
    notifyListeners();
  }
}
