@TestOn('browser')
library;

import 'dart:js_interop';
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;
import 'package:yahwehs_words/services/offline_audio_storage_web.dart';
import 'package:yahwehs_words/services/offline_audio_types.dart';

@JS('eval')
external JSAny? evaluate(JSString code);
void js(String code) => evaluate(code.toJS);
const item = AudioDownloadItem(
    id: 'web-a',
    title: 'Audio',
    url: 'https://example.test/song.m4a',
    sermonId: 'talk');
void main() {
  const cache = 'offline-audio-test';
  setUp(() async {
    await web.window.caches.delete(cache).toDart;
    js('globalThis.originalFetch=globalThis.fetch;');
  });
  tearDown(() async {
    js('globalThis.fetch=globalThis.originalFetch;');
    await web.window.caches.delete(cache).toDart;
  });
  test('real browser cache restores blob on cold service and removes it',
      () async {
    js("globalThis.fetch=async()=>new Response(new Uint8Array([73,68,51,1,2,3]),{headers:{'Content-Length':'6'}});");
    final s = PlatformOfflineAudioStorage(cacheName: cache);
    expect(await s.download(item, DownloadCancellation(), (_, total) {}), 6);
    expect(s.sourceFor(item.id), startsWith('blob:'));
    final cold = PlatformOfflineAudioStorage(cacheName: cache);
    expect(await cold.contains(item.id), true);
    final hit = await (await web.window.caches.open(cache).toDart)
        .match('${web.window.location.origin}/offline-audio/web-a'.toJS)
        .toDart;
    expect((await hit!.blob().toDart).type, 'audio/mp4');
    await cold.remove(item.id);
    expect(await cold.contains(item.id), false);
  });
  test('HTML HTTP 200 and network failure do not enter browser cache',
      () async {
    for (final mock in [
      "async()=>new Response('<html>error</html>')",
      "async()=>{throw new TypeError('Failed to fetch');}"
    ]) {
      js('globalThis.fetch=$mock;');
      final s = PlatformOfflineAudioStorage(cacheName: cache);
      await expectLater(s.download(item, DownloadCancellation(), (_, total) {}),
          throwsA(anything));
      expect(await s.contains(item.id), false);
    }
  });
  test('abort reaches fetch; partial response is never marked downloaded',
      () async {
    js("globalThis.fetch=async(url,opts)=>new Response(new ReadableStream({start(c){c.enqueue(new Uint8Array([73,68,51]));opts.signal.addEventListener('abort',()=>c.error(new DOMException('aborted','AbortError')));}}));");
    final token = DownloadCancellation();
    final s = PlatformOfflineAudioStorage(cacheName: cache);
    await expectLater(s.download(item, token, (_, total) => token.cancel()),
        throwsA(anything));
    expect(await s.contains(item.id), false);
  });
  test('quota failure propagates; storage is never reported ready', () async {
    js("globalThis.fetch=async()=>new Response(new Uint8Array([73,68,51,1]));globalThis.originalOpen=caches.open.bind(caches);caches.open=async()=>({put:async()=>{throw new DOMException('full','QuotaExceededError');}});");
    try {
      final s = PlatformOfflineAudioStorage(cacheName: cache);
      await expectLater(s.download(item, DownloadCancellation(), (_, total) {}),
          throwsA(anything));
      expect(s.sourceFor(item.id), null);
    } finally {
      js('caches.open=globalThis.originalOpen;');
    }
  });
}
