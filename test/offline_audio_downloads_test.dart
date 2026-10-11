import 'dart:async';
import 'dart:convert';
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
  Object? readFailure;
  Object? removeFailure;
  Completer<void>? gate;
  @override
  bool get supported => true;
  @override
  Future<void> init() async {}
  @override
  Future<bool> contains(String id) async {
    if (readFailure != null) throw readFailure!;
    return files.contains(id);
  }

  @override
  String? sourceFor(String id) => files.contains(id) ? '/audio/$id.mp3' : null;
  @override
  Future<void> remove(String id) async {
    if (removeFailure != null) throw removeFailure!;
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

class RecoveringStore extends Store implements RecoverableAudioStorage {
  final backup = <String>{};
  int rollbacks = 0;
  int commits = 0;
  @override
  Future<bool> validate(String id, int expectedBytes) async =>
      await super.contains(id) && expectedBytes == 6;
  @override
  Future<void> protect(String id) async {
    if (files.contains(id)) backup.add(id);
  }

  @override
  Future<void> rollback(String id) async {
    rollbacks++;
    if (backup.remove(id)) files.add(id);
  }

  @override
  Future<void> commit(String id) async {
    commits++;
    backup.remove(id);
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
  test('deleting one ready item leaves another active download alone',
      () async {
    final store = Store();
    final service = OfflineAudioDownloads(storage: store);
    await service.enqueue([item]);
    await settle(service);
    store.gate = Completer<void>();
    await service.enqueue([second]);
    await service.delete(item.id);
    expect(service.pendingCount, 1);
    expect(store.files.contains(item.id), false);
    store.gate!.complete();
    await settle(service);
    expect(service.isReady([second]), true);
  });
  test('failed physical delete retains file and persisted recovery metadata',
      () async {
    final store = Store();
    final service = OfflineAudioDownloads(storage: store);
    await service.enqueue([item]);
    await settle(service);
    final prefs = await SharedPreferences.getInstance();
    final original = prefs.getString('sermons.downloads.v1');
    store.removeFailure = StateError('read-only storage');
    await expectLater(service.delete(item.id), throwsStateError);
    expect(store.files.contains(item.id), true);
    expect(prefs.getString('sermons.downloads.v1'), original);
    final restarted = OfflineAudioDownloads(storage: store);
    await restarted.init();
    expect(restarted.isReady([item]), true);
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
  test('legacy missing and transient storage failures retain exact index',
      () async {
    final raw = jsonEncode([const AudioDownloadRecord(item, 6).toJson()]);
    for (final error in [null, StateError('Storage temporarily unavailable')]) {
      SharedPreferences.setMockInitialValues({'sermons.downloads.v1': raw});
      final store = Store()..readFailure = error;
      final service = OfflineAudioDownloads(storage: store);
      await service.init();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('sermons.downloads.v1'), raw);
      expect(prefs.getString('sermons.downloads.v1.pre-recovery'), raw);
      expect(service.status(item.id)?.state, AudioDownloadState.failed);
      expect(service.sourceFor(item.id), null);
      store.readFailure = null;
      store.files.add(item.id);
      await service.refresh();
      expect(service.isReady([item]), true);
      expect(store.calls, 0);
    }
  });
  test('one malformed legacy row does not hide valid downloaded rows',
      () async {
    final raw = jsonEncode([
      {'invalid': true},
      const AudioDownloadRecord(item, 6).toJson()
    ]);
    SharedPreferences.setMockInitialValues({'sermons.downloads.v1': raw});
    final store = Store()..files.add(item.id);
    final service = OfflineAudioDownloads(storage: store);
    await service.init();
    expect(service.isReady([item]), true);
    expect(
        (await SharedPreferences.getInstance())
            .getString('sermons.downloads.v1'),
        raw);
  });
  test(
      'restarted pending queue waits for explicit resume and skips ready files',
      () async {
    SharedPreferences.setMockInitialValues({
      'sermons.downloads.v1':
          jsonEncode([const AudioDownloadRecord(item, 6).toJson()]),
      'sermons.download.queue.v1':
          jsonEncode([item.toJson(), null, second.toJson(), second.toJson()]),
    });
    final store = Store()..files.add(item.id);
    final service = OfflineAudioDownloads(storage: store);
    await service.init();
    expect(service.paused, true);
    expect(service.pendingCount, 1);
    expect(store.calls, 0);
    await service.resumeAll();
    await settle(service);
    expect(service.isReady([item, second]), true);
    expect(store.calls, 1);
  });
  test(
      'pause plus enqueue deduplicates interrupted item; cancel clears restored queue',
      () async {
    final store = Store()..gate = Completer<void>();
    final service = OfflineAudioDownloads(storage: store);
    await service.enqueue([item, second]);
    final pausing = service.pauseAll();
    await Future<void>.delayed(Duration.zero);
    final enqueuing = service.enqueue([item, second]);
    store.gate!.complete();
    await Future.wait([pausing, enqueuing]);
    expect(service.pendingCount, 2);
    expect(store.calls, 1);
    await service.cancelAll();
    expect(service.pendingCount, 0);
    final prefs = await SharedPreferences.getInstance();
    expect(jsonDecode(prefs.getString('sermons.download.queue.v1')!), isEmpty);
  });
  test('cancel during pause cannot resurrect canceled items on restart',
      () async {
    final store = Store()..gate = Completer<void>();
    final service = OfflineAudioDownloads(storage: store);
    await service.enqueue([item, second]);
    final pausing = service.pauseAll();
    await Future<void>.delayed(Duration.zero);
    final canceling = service.cancelAll();
    store.gate!.complete();
    await Future.wait([pausing, canceling]);
    expect(service.pendingCount, 0);
    await service.resumeAll();
    final restored = OfflineAudioDownloads(storage: store);
    await restored.init();
    expect(restored.pendingCount, 0);
    expect(store.calls, 1);
  });
  test('pause waits for late writer; resume restarts interrupted item once',
      () async {
    final store = Store()..gate = Completer<void>();
    final service = OfflineAudioDownloads(storage: store);
    await service.enqueue([item, second]);
    final pausing = service.pauseAll();
    store.gate!.complete();
    await pausing;
    expect(service.paused, true);
    expect(service.pendingCount, 2);
    expect(service.records, isEmpty);
    store.gate = null;
    await service.resumeAll();
    await settle(service);
    expect(service.isReady([item, second]), true);
    expect(store.calls, 3);
  });
  test('replacement failure restores ready old source and index', () async {
    final store = RecoveringStore();
    final service = OfflineAudioDownloads(storage: store);
    await service.enqueue([item]);
    await settle(service);
    const replacement = AudioDownloadItem(
        id: 'talk:a',
        title: 'Talk A',
        url: 'https://example.test/new.mp3',
        sermonId: 'talk');
    store.failure = StateError('Network interrupted');
    await service.enqueue([replacement]);
    await settle(service);
    expect(service.isReady([item]), true);
    expect(service.isReady([replacement]), false);
    expect(store.rollbacks, 1);
    final cold = OfflineAudioDownloads(storage: store);
    await cold.init();
    expect(cold.isReady([item]), true);
    expect(
        (await SharedPreferences.getInstance())
            .getString('sermons.download.replace.${item.id}'),
        isNull);
  });
  test(
      'restart rolls back unfinished replacement but commits index-confirmed replacement',
      () async {
    const replacement = AudioDownloadItem(
        id: 'talk:a',
        title: 'Talk A',
        url: 'https://example.test/new.mp3',
        sermonId: 'talk');
    for (final committed in [false, true]) {
      final indexed = committed ? replacement : item;
      SharedPreferences.setMockInitialValues({
        'sermons.downloads.v1':
            jsonEncode([AudioDownloadRecord(indexed, 6).toJson()]),
        'sermons.download.replace.${item.id}':
            jsonEncode(const AudioDownloadRecord(item, 6).toJson()),
      });
      final store = RecoveringStore()
        ..files.add(item.id)
        ..backup.add(item.id);
      final cold = OfflineAudioDownloads(storage: store);
      await cold.init();
      expect(cold.isReady([indexed]), true);
      expect(store.rollbacks, committed ? 0 : 1);
      expect(store.commits, committed ? 1 : 0);
      expect(store.calls, 0);
      expect(store.backup, isEmpty);
    }
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
