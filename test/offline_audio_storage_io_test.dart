import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yahwehs_words/services/offline_audio_storage_io.dart';
import 'package:yahwehs_words/services/offline_audio_types.dart';

const item = AudioDownloadItem(
    id: 'a', title: 'a', url: 'https://example.test/a.mp3', sermonId: 'talk');
void main() {
  late Directory dir;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('offline-audio-test');
  });
  tearDown(() async {
    await dir.delete(recursive: true);
  });
  PlatformOfflineAudioStorage storage(http.Client client) =>
      PlatformOfflineAudioStorage(
          directory: () async => dir, clientFactory: () => client);
  test('streams and atomically saves audio with cold source and delete',
      () async {
    final s =
        storage(MockClient.streaming((r, b) async => http.StreamedResponse(
            Stream.fromIterable([
              [73, 68, 51],
              [1, 2, 3]
            ]),
            200,
            contentLength: 6)));
    final progress = <int>[];
    expect(
        await s.download(
            item, DownloadCancellation(), (n, t) => progress.add(n)),
        6);
    expect(progress, [3, 6]);
    expect(await s.contains('a'), true);
    expect(await File(s.sourceFor('a')!).readAsBytes(), [73, 68, 51, 1, 2, 3]);
    expect(await File('${s.sourceFor('a')}.part').exists(), false);
    await s.remove('a');
    expect(await s.contains('a'), false);
  });
  test('legacy validation reports incomplete or error data without deleting it',
      () async {
    final s = storage(MockClient(
        (r) async => http.Response.bytes([73, 68, 51, 0, 1, 2], 200)));
    await s.download(item, DownloadCancellation(), (received, total) {});
    final file = File(s.sourceFor(item.id)!);
    expect(await s.validate(item.id, 6), true);
    expect(await s.validate(item.id, 8), false);
    expect(await file.length(), 6);
    await file.writeAsString('<html>error</html>');
    expect(await s.validate(item.id, 0), false);
    expect(await file.exists(), true);
  });
  test(
      'replacement rollback restores exact original bytes; commit removes only backup',
      () async {
    final s = storage(MockClient(
        (r) async => http.Response.bytes([73, 68, 51, 0, 1, 2], 200)));
    await s.download(item, DownloadCancellation(), (received, total) {});
    final file = File(s.sourceFor(item.id)!);
    final original = await file.readAsBytes();
    await s.protect(item.id);
    await file.writeAsBytes([73, 68, 51, 8, 9, 10]);
    await s.rollback(item.id);
    expect(await file.readAsBytes(), original);
    await s.protect(item.id);
    await file.writeAsBytes([73, 68, 51, 8, 9, 10]);
    await s.commit(item.id);
    expect(await File('${file.path}.previous').exists(), false);
    expect(await file.readAsBytes(), [73, 68, 51, 8, 9, 10]);
  });
  test('HTML, empty and truncated HTTP 200 are rejected with no partial file',
      () async {
    for (final body in ['<html>error</html>', '', 'ID3']) {
      final s = storage(MockClient.streaming((r, b) async =>
          http.StreamedResponse(Stream.value(body.codeUnits), 200,
              contentLength: 20)));
      await expectLater(
          s.download(item, DownloadCancellation(), (received, total) {}),
          throwsStateError);
      expect(await s.contains('a'), false);
      expect(await File('${s.sourceFor('a')}.part').exists(), false);
    }
  });
  test('cancellation during streamed transfer cleans partial output', () async {
    final token = DownloadCancellation();
    final s =
        storage(MockClient.streaming((r, b) async => http.StreamedResponse(
            Stream.fromIterable([
              [73, 68, 51],
              [1, 2, 3]
            ]),
            200)));
    await expectLater(
        s.download(item, token, (received, total) => token.cancel()),
        throwsA(isA<DownloadCancelled>()));
    expect(await s.contains('a'), false);
  });
  test('real file system write failure fails without a ready file', () async {
    final blocked = File('${dir.path}/blocked');
    await blocked.writeAsString('not a directory');
    final s = PlatformOfflineAudioStorage(
        directory: () async => Directory(blocked.path),
        clientFactory: () =>
            MockClient((r) async => http.Response('ID3abc', 200)));
    await expectLater(
        s.download(item, DownloadCancellation(), (received, total) {}),
        throwsA(isA<FileSystemException>()));
  });
  test('network disconnection removes partial file', () async {
    final s = storage(MockClient.streaming((r, b) async =>
        http.StreamedResponse(
            Stream<List<int>>.error(const SocketException('offline')), 200)));
    await expectLater(
        s.download(item, DownloadCancellation(), (received, total) {}),
        throwsStateError);
    expect(await s.contains('a'), false);
  });
  test('native blocked origin retries through existing media proxy', () async {
    final requests = <String>[];
    final s = storage(MockClient((r) async {
      requests.add(r.url.toString());
      return requests.length == 1
          ? http.Response('blocked', 403)
          : http.Response.bytes([73, 68, 51, 0], 200);
    }));
    const cdc = AudioDownloadItem(
        id: 'cdc',
        title: 'CDC',
        url: 'https://www.christiandiscipleschurch.org/audio.mp3',
        sermonId: 'talk');
    expect(
        await s.download(cdc, DownloadCancellation(), (received, total) {}), 4);
    expect(requests, [
      'https://www.christiandiscipleschurch.org/audio.mp3',
      'https://yahwehword.com/song-media/cdc/audio.mp3'
    ]);
  });
}
