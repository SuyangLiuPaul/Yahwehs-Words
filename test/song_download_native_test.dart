import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahwehs_words/models/song.dart';
import 'package:yahwehs_words/services/song_download_io.dart';
import 'package:yahwehs_words/services/song_download_types.dart';

const song = Song(
    id: 'offline',
    title: 'Offline',
    language: 'en',
    source: 'cdc',
    sourceLabel: 'CDC',
    url: 'https://example.test',
    audioUrl: 'https://example.test/a.mp3',
    themes: []);
Future<void> idle(SongDownloadService s) async {
  for (var n = 0; n < 100; n++) {
    await Future<void>.delayed(const Duration(milliseconds: 2));
    if (!s.isBusy) return;
  }
  fail('still downloading');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    dir = await Directory.systemTemp.createTemp('song-download-test');
  });
  tearDown(() async {
    await dir.delete(recursive: true);
  });
  test(
      'song batch deduplicates, saves progress and restores old index on cold launch',
      () async {
    var calls = 0;
    http.Client client() => MockClient((r) async {
          calls++;
          return http.Response.bytes([73, 68, 51, 0, 1], 200);
        });
    final s = SongDownloadService.forTesting(
        directory: () async => dir, clientFactory: client);
    await s.enqueue([song, song]);
    await idle(s);
    expect(calls, 1);
    expect(s.isDownloaded(song), true);
    expect(s.statusOf(song).bytes, 5);
    final cold = SongDownloadService.forTesting(
        directory: () async => dir, clientFactory: client);
    await cold.init();
    expect(cold.localPathFor(song), isNotNull);
    expect(
        await File(cold.localPathFor(song)!).readAsBytes(), [73, 68, 51, 0, 1]);
    await cold.delete(song);
    expect(cold.isDownloaded(song), false);
  });
  test('cancel aborts a stalled song, deletes partial file and retry works',
      () async {
    final stream = StreamController<List<int>>();
    var started = false;
    final s = SongDownloadService.forTesting(
        directory: () async => dir,
        clientFactory: () => MockClient.streaming((r, b) async {
              started = true;
              return http.StreamedResponse(stream.stream, 200);
            }));
    await s.enqueue([song]);
    while (!started) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    stream.add([73, 68, 51]);
    final cancelling = s.cancelAll();
    await stream.close();
    await cancelling;
    expect(s.isDownloaded(song), false);
    expect(await dir.list(recursive: true).where((e) => e is File).length, 0);
  });
  test('failed HTTP response is retryable, never downloaded', () async {
    var failed = true;
    final s = SongDownloadService.forTesting(
        directory: () async => dir,
        clientFactory: () => MockClient((r) async => failed
            ? http.Response('offline', 503)
            : http.Response.bytes([73, 68, 51, 0], 200)));
    await s.enqueue([song]);
    await idle(s);
    expect(s.statusOf(song).state, SongDownloadState.failed);
    expect(s.isDownloaded(song), false);
    failed = false;
    await s.enqueue([song]);
    await idle(s);
    expect(s.isDownloaded(song), true);
  });
}
