import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahwehs_words/services/offline_audio_downloads.dart';

const item = AudioDownloadItem(
    id: 'talk:a',
    title: 'Talk A',
    url: 'https://example.test/a.mp3',
    sermonId: 'talk');
const second = AudioDownloadItem(
    id: 'talk:b',
    title: 'Talk B',
    url: 'https://example.test/b.mp3',
    sermonId: 'talk');

class Store implements OfflineAudioStorage {
  final files = <String>{};
  int calls = 0;
  Object? failure;
  Completer<void>? gate;
  @override
  bool get supported => true;
  @override
  Future<void> init() async {}
  @override
  Future<bool> contains(String id) async => files.contains(id);
  @override
  String? sourceFor(String id) => files.contains(id) ? '/audio/$id.mp3' : null;
  @override
  Future<void> remove(String id) async {
    files.remove(id);
  }

  @override
  Future<int> download(AudioDownloadItem i, DownloadCancellation c,
      void Function(int, int) p) async {
    calls++;
    p(3, 6);
    if (gate != null) await gate!.future;
    if (failure != null) throw failure!;
    // Deliberately ignores cancellation to simulate a late network response.
    files.add(i.id);
    return 6;
  }
}

Future<void> settle(OfflineAudioDownloads s) async {
  for (var n = 0; n < 100; n++) {
    await Future<void>.delayed(const Duration(milliseconds: 2));
    if (!s.items.any((i) => [
          AudioDownloadState.queued,
          AudioDownloadState.downloading
        ].contains(s.status(i.id)?.state))) {
      return;
    }
  }
  fail('Download did not settle');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('deduplicates queued, active and completed parts; all parts required',
      () async {
    final store = Store()..gate = Completer<void>();
    final s = OfflineAudioDownloads(storage: store);
    await s.enqueue([item, item, second]);
    await s.enqueue([item]);
    expect(store.calls, 1);
    expect(s.isReady([item, second]), false);
    store.gate!.complete();
    await settle(s);
    await s.enqueue([item, second]);
    expect(store.calls, 2);
    expect(s.records.length, 2);
    expect(s.isReady([item, second]), true);
  });
  test('network failure and no space never become downloaded; retry succeeds',
      () async {
    for (final e in [
      StateError('network unavailable'),
      StateError('No space left on device')
    ]) {
      SharedPreferences.setMockInitialValues({});
      final store = Store()..failure = e;
      final s = OfflineAudioDownloads(storage: store);
      await s.enqueue([item]);
      await settle(s);
      expect(s.status(item.id)?.state, AudioDownloadState.failed);
      expect(s.sourceFor(item.id), null);
      store.failure = null;
      await s.enqueue([item]);
      await settle(s);
      expect(s.isReady([item]), true);
    }
  });
  test(
      'cancel waits for writer, drops queued part and rejects late success; retry',
      () async {
    final store = Store()..gate = Completer<void>();
    final s = OfflineAudioDownloads(storage: store);
    await s.enqueue([item, second]);
    final cancelling = s.cancelAll();
    store.gate!.complete();
    await cancelling;
    expect(s.records, isEmpty);
    expect(store.files, isEmpty);
    expect(store.calls, 1);
    store.gate = null;
    await s.enqueue([item]);
    await settle(s);
    expect(s.isReady([item]), true);
  });
  test('cold initialization restores local source; eviction clears ready state',
      () async {
    final store = Store();
    final s = OfflineAudioDownloads(storage: store);
    await s.enqueue([item]);
    await settle(s);
    final cold = OfflineAudioDownloads(storage: store);
    await Future.wait([cold.init(), cold.init()]);
    expect(cold.sourceFor(item.id), '/audio/talk:a.mp3');
    store.files.clear();
    final evicted = OfflineAudioDownloads(storage: store);
    await evicted.init();
    expect(evicted.isReady([item]), false);
  });
  test('delete waits for active writer; cannot resurrect deleted file',
      () async {
    final store = Store()..gate = Completer<void>();
    final s = OfflineAudioDownloads(storage: store);
    await s.enqueue([item]);
    final deleting = s.delete(item.id);
    store.gate!.complete();
    await deleting;
    expect(store.files, isEmpty);
    expect(s.records, isEmpty);
  });
  test('changed URL does not reuse stale recording', () async {
    final store = Store();
    final s = OfflineAudioDownloads(storage: store);
    await s.enqueue([item]);
    await settle(s);
    const changed = AudioDownloadItem(
        id: 'talk:a',
        title: 'Talk A',
        url: 'https://example.test/new.mp3',
        sermonId: 'talk');
    expect(s.isReady([changed]), false);
    await s.enqueue([changed]);
    await settle(s);
    expect(store.calls, 2);
    expect(s.isReady([changed]), true);
  });
  test('progress and proxy mappings reject HTML and JSON responses', () {
    expect(
        const AudioDownloadStatus(AudioDownloadState.downloading,
                received: 2, total: 4)
            .progress,
        .5);
    expect(validAudioPrefix([73, 68, 51, 0]), true);
    expect(validAudioPrefix('<html>'.codeUnits), false);
    expect(validAudioPrefix('{"error":1}'.codeUnits), false);
    expect(mediaProxyPath('https://www.christiandiscipleschurch.org/a.mp3'),
        '/song-media/cdc/a.mp3');
  });
}
