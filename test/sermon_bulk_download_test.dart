import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahwehs_words/models/sermon.dart';
import 'package:yahwehs_words/services/offline_audio_downloads.dart';
import 'package:yahwehs_words/widgets/sermon_bulk_download_button.dart';
import 'offline_audio_downloads_test.dart' show Store;

const sermon = Sermon(
    id: 'one',
    topic: 'topic',
    topicSlug: 'topic',
    date: '',
    parts: '',
    passage: '',
    title: 'One sermon',
    titles: {},
    hasEn: true,
    hasZhCn: false,
    hasZhTw: false);
const ready = AudioDownloadItem(
    id: 'one:1',
    title: 'Saved part',
    url: 'https://example.test/one.mp3',
    sermonId: 'one',
    expectedBytes: 6);
const missing = AudioDownloadItem(
    id: 'one:2',
    title: 'Missing part',
    url: 'https://example.test/two.mp3',
    sermonId: 'one');

void main() {
  testWidgets(
      'bulk confirms only filtered missing parts; cancel keeps existing files',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = Store();
    final svc = OfflineAudioDownloads(storage: store);
    await svc.enqueue([ready]);
    await tester.runAsync(() async {
      while (svc.pendingCount > 0) {
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }
    });
    final requested = <String>[];
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SermonBulkDownloadButton(
                sermons: const [sermon],
                locale: 'en',
                service: svc,
                resolveParts: (id, title) async {
                  requested.add(id);
                  return [ready, missing];
                }))));
    await tester.tap(find.text('Download results'));
    await tester.pumpAndSettle();
    expect(requested, ['one']);
    expect(find.textContaining('1 audio parts'), findsOneWidget);
    expect(find.textContaining('1 unknown sizes'), findsOneWidget);
    expect(store.calls, 1);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(store.calls, 1);
    expect(svc.isReady([ready]), true);
    expect(tester.takeException(), isNull);
  });
}
