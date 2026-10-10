import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';
import 'package:web/web.dart' as web;
import 'offline_audio_types.dart';

class PlatformOfflineAudioStorage implements OfflineAudioStorage {
  PlatformOfflineAudioStorage(
      {this.cacheName = 'sermon-media-v1', this.keyFor});
  final String cacheName;
  final String Function(String)? keyFor;
  final _urls = <String, String>{};
  String _key(String id) =>
      keyFor?.call(id) ??
      '${web.window.location.origin}/offline-audio/${Uri.encodeComponent(id)}';
  @override
  bool get supported {
    try {
      return (web.window as JSObject).has('caches');
    } catch (_) {
      return false;
    }
  }

  Future<web.Cache> _cache() async =>
      await web.window.caches.open(cacheName).toDart;
  @override
  Future<void> init() async {}
  @override
  Future<bool> contains(String id) async {
    final hit = await (await _cache()).match(_key(id).toJS).toDart;
    if (hit == null) return false;
    final blob = await hit.blob().toDart;
    if (blob.size == 0) return false;
    final old = _urls.remove(id);
    if (old != null) web.URL.revokeObjectURL(old);
    _urls[id] = web.URL.createObjectURL(blob);
    return true;
  }

  @override
  String? sourceFor(String id) => _urls[id];
  @override
  Future<void> remove(String id) async {
    final old = _urls.remove(id);
    if (old != null) web.URL.revokeObjectURL(old);
    await (await _cache()).delete(_key(id).toJS).toDart;
  }

  @override
  Future<int> download(AudioDownloadItem item, DownloadCancellation token,
      void Function(int, int) progress) async {
    final controller = web.AbortController();
    token.abort = () => controller.abort();
    try {
      try {
        await web.window.navigator.storage.persist().toDart;
      } catch (_) {}
      final res = await web.window
          .fetch(mediaProxyPath(item.url).toJS,
              web.RequestInit(signal: controller.signal))
          .toDart
          .timeout(const Duration(seconds: 15), onTimeout: () {
        controller.abort();
        throw TimeoutException("Server did not respond");
      });
      if (!res.ok) throw StateError('HTTP ${res.status}');
      final total = int.tryParse(res.headers.get('Content-Length') ?? '') ?? 0;
      final reader = res.body?.getReader() as web.ReadableStreamDefaultReader?;
      if (reader == null) throw StateError('Empty response');
      final chunks = <JSAny>[];
      final prefix = <int>[];
      var bytes = 0;
      try {
        while (true) {
          token.check();
          final next = await reader
              .read()
              .toDart
              .timeout(const Duration(seconds: 30), onTimeout: () {
            controller.abort();
            throw TimeoutException("Download stalled");
          });
          if (next.done) break;
          final data = (next.value as JSUint8Array).toDart;
          if (prefix.length < 64) prefix.addAll(data.take(64 - prefix.length));
          chunks.add(Uint8List.fromList(data).toJS);
          bytes += data.length;
          progress(bytes, total);
        }
      } finally {
        reader.releaseLock();
      }
      token.check();
      if (bytes == 0 || !validAudioPrefix(prefix)) {
        throw const FormatException('Not an audio file');
      }
      final blob = web.Blob(
          chunks.toJS,
          web.BlobPropertyBag(
              type: Uri.parse(item.url).path.toLowerCase().endsWith('.m4a')
                  ? 'audio/mp4'
                  : 'audio/mpeg'));
      final cache = await _cache();
      await cache.put(_key(item.id).toJS, web.Response(blob)).toDart;
      token.check();
      final old = _urls.remove(item.id);
      if (old != null) web.URL.revokeObjectURL(old);
      _urls[item.id] = web.URL.createObjectURL(blob);
      return bytes;
    } finally {
      token.abort = null;
    }
  }
}
