import 'dart:async';
import 'dart:io';
import 'dart:convert';
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
  test(
      'temporarily unavailable song file does not rewrite original index or require network',
      () async {
    var calls = 0;
    http.Client client() => MockClient((r) async {
          calls++;
          return http.Response.bytes([73, 68, 51, 0, 1], 200);
        });
    final service = SongDownloadService.forTesting(
        directory: () async => dir, clientFactory: client);
    await service.enqueue([song]);
    await idle(service);
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('songs.downloads.v1');
    final file = File(service.localPathFor(song)!);
    final held = await file.rename('${file.path}.held');
    final unavailable = SongDownloadService.forTesting(
        directory: () async => dir, clientFactory: client);
    await unavailable.init();
    expect(unavailable.isDownloaded(song), false);
    expect(unavailable.statusOf(song).state, SongDownloadState.failed);
    expect(prefs.getString('songs.downloads.v1'), raw);
    expect(prefs.getString('songs.downloads.v1.pre-recovery'), raw);
    await held.rename(file.path);
    final restored = SongDownloadService.forTesting(
        directory: () async => dir, clientFactory: client);
    await restored.init();
    expect(restored.isDownloaded(song), true);
    expect(calls, 1);
  });
  test('already-saved batch planning preserves native index and audio bytes',
      () async {
    var requests = 0;
    final service = SongDownloadService.forTesting(
        directory: () async => dir,
        clientFactory: () => MockClient((r) async {
              requests++;
              return http.Response.bytes([73, 68, 51, 0, 1], 200);
            }));
    await service.enqueue([song]);
    await idle(service);
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('songs.downloads.v1');
    final path = service.localPathFor(song)!;
    final cold = SongDownloadService.forTesting(
        directory: () async => dir,
        clientFactory: () => throw StateError('No new download expected'));
    await cold.init();
    final plan = SongDownloadBatchPlan([song],
        isDownloaded: cold.isDownloaded, statusOf: cold.statusOf);
    expect(plan.pending, isEmpty);
    expect(plan.emptyMessageKey, 'songsDownloadsAlreadySaved');
    expect(cold.downloadedCount, 1);
    expect(prefs.getString('songs.downloads.v1'), raw);
    expect(await File(path).readAsBytes(), [73, 68, 51, 0, 1]);
    expect(requests, 1);
  });
  test(
      'corrupt saved song is not ready and its bytes and recovery index remain intact',
      () async {
    final service = SongDownloadService.forTesting(
        directory: () async => dir,
        clientFactory: () => MockClient(
            (r) async => http.Response.bytes([73, 68, 51, 0, 1], 200)));
    await service.enqueue([song]);
    await idle(service);
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('songs.downloads.v1');
    final file = File(service.localPathFor(song)!);
    await file.writeAsString('<html');
    final cold = SongDownloadService.forTesting(
        directory: () async => dir,
        clientFactory: () => throw StateError('No network permitted'));
    await cold.init();
    expect(cold.isDownloaded(song), false);
    expect(await file.readAsString(), '<html');
    expect(prefs.getString('songs.downloads.v1'), raw);
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
  test(
      'saved pending songs restore paused without network, resume and clear queue',
      () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'songs.downloads.v1.queue', jsonEncode([songQueueRecord(song)]));
    var calls = 0;
    final service = SongDownloadService.forTesting(
        directory: () async => dir,
        clientFactory: () => MockClient((r) async {
              calls++;
              return http.Response.bytes([73, 68, 51, 0], 200);
            }));
    await service.init();
    expect(service.paused, true);
    expect(service.pendingCount, 1);
    expect(service.statusOf(song).state, SongDownloadState.paused);
    expect(calls, 0);
    await service.enqueue([song]);
    expect(service.pendingCount, 1);
    await service.resumeAll();
    await idle(service);
    expect(calls, 1);
    expect(service.isDownloaded(song), true);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(jsonDecode(prefs.getString('songs.downloads.v1.queue')!), isEmpty);
  });
  test('pause retains interrupted song and cancel clears only pending queue',
      () async {
    final stream = StreamController<List<int>>();
    var started = false;
    final service = SongDownloadService.forTesting(
        directory: () async => dir,
        clientFactory: () => MockClient.streaming((r, b) async {
              started = true;
              return http.StreamedResponse(stream.stream, 200);
            }));
    await service.enqueue([song]);
    while (!started) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    stream.add([73, 68, 51]);
    final pausing = service.pauseAll();
    await stream.close();
    await pausing;
    expect(service.paused, true);
    expect(service.pendingCount, 1);
    expect(service.statusOf(song).state, SongDownloadState.paused);
    final prefs = await SharedPreferences.getInstance();
    expect(
        jsonDecode(prefs.getString('songs.downloads.v1.queue')!), hasLength(1));
    await service.cancelAll();
    expect(service.pendingCount, 0);
    expect(jsonDecode(prefs.getString('songs.downloads.v1.queue')!), isEmpty);
  });
}
