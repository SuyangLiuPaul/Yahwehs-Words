@TestOn('browser')
library;

import 'dart:convert';
import 'dart:js_interop';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web/web.dart' as web;
import 'package:yahwehs_words/services/song_cache_probe_web.dart';

void main() {
  late web.Cache cache;
  const bucket = 'words-isolated-probe-test';
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await web.window.caches.delete(bucket).toDart;
    cache = await web.window.caches.open(bucket).toDart;
  });
  tearDown(() async => web.window.caches.delete(bucket).toDart);
  Future<void> put(String key, String body, {String? vary}) async {
    final headers = web.Headers();
    if (vary != null) headers.set('Vary', vary);
    await cache
        .put(key.toJS,
            web.Response(body.toJS, web.ResponseInit(headers: headers)))
        .toDart;
  }

  test('missing bucket and missing key have distinct reasons', () async {
    expect((await probeSongCache(null, 'a', '/audio', 3)).report['reason'],
        'cache_bucket_missing');
    expect((await probeSongCache(cache, 'a', '/audio', 3)).report['reason'],
        'cache_entry_missing');
  });
  test('records actual byte count and prefix, without modifying body',
      () async {
    await put('/audio', 'ID3abc');
    final result = await probeSongCache(cache, 'a', '/audio', 6);
    expect(result.valid, true);
    expect(result.report['actualBytes'], 6);
    expect(result.report['prefixHex'], '494433616263');
    expect(await (await cache.match('/audio'.toJS).toDart)!.text().toDart,
        'ID3abc');
    expect((await probeSongCache(cache, 'a', '/audio', 7)).report['reason'],
        'size_mismatch');
    await put('/bad', '<html>');
    expect((await probeSongCache(cache, 'b', '/bad', 6)).report['reason'],
        'invalid_prefix');
    await put('/empty', '');
    expect((await probeSongCache(cache, 'c', '/empty', 0)).report['reason'],
        'empty_body');
  });
  test('Vary mismatch is diagnosed instead of reporting missing audio',
      () async {
    final request = web.Request(
        '/vary'.toJS,
        web.RequestInit(
            headers: web.Headers({'X-Test': 'original'}.jsify() as JSObject)));
    final headers = web.Headers();
    headers.set('Vary', 'X-Test');
    await cache
        .put(request,
            web.Response('ID3'.toJS, web.ResponseInit(headers: headers)))
        .toDart;
    expect((await probeSongCache(cache, 'a', '/vary', 3)).report['reason'],
        'vary_mismatch');
  });
  test('first failure survives subsequent recovery; index remains unchanged',
      () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('songs.downloads.web.v1', 'original-index');
    await retainSongValidationFailure(
        prefs, {'id': 'a', 'reason': 'size_mismatch', 'actualBytes': 2});
    await retainSongValidationFailure(
        prefs, {'id': 'a', 'reason': 'cache_entry_missing'});
    await retainSongValidationFailure(prefs, {'id': 'a', 'reason': 'valid'});
    expect(
        jsonDecode(prefs.getString(songValidationEvidenceKey)!)['a']['reason'],
        'size_mismatch');
    expect(prefs.getString('songs.downloads.web.v1'), 'original-index');
  });
}
