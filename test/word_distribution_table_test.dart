import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahwehs_words/services/concordance_service.dart';
import 'package:yahwehs_words/services/lxx_service.dart';
import 'package:yahwehs_words/services/strongs_service.dart';
import 'package:yahwehs_words/widgets/word_distribution_table.dart';

/// The distribution table (2026-10-16 redesign): the word stays pinned
/// while the counts scroll, every header is in the reader's language, and
/// a count over a thousand has its separator.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Real file IO never completes inside the widget-test clock, so every
  // lookup the table makes is done once, here, and found cached after.
  setUpAll(() async {
    final main = await StrongsService.lookup('H3068');
    await StrongsService.wordFamily('H3068');
    final cmp = await StrongsService.compareWords('H3068');
    await LxxService.greekEntriesFor('H3068');
    await ConcordanceService.lookup('H3068');
    for (final e in cmp) {
      await ConcordanceService.lookup(e.number);
    }
    expect(main, isNotNull);
  });

  Future<void> pump(WidgetTester tester, String locale, Size size) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: WordDistributionTable(strongsNumber: 'H3068', locale: locale),
      ),
    ));
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 40)));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('headers are in Chinese and the big count has its comma',
      (tester) async {
    await pump(tester, 'zh-Hans', const Size(390, 800));
    expect(tester.takeException(), isNull);
    expect(find.text('原文'), findsOneWidget);
    expect(find.text('释义'), findsOneWidget);
    expect(find.text('Word'), findsNothing);
    expect(find.text('Gloss'), findsNothing);
    expect(find.text('H3068'), findsOneWidget);
    expect(find.text('6,521'), findsWidgets);
  });

  testWidgets('and in English; narrow and wide both lay out', (tester) async {
    await pump(tester, 'en', const Size(320, 700));
    expect(tester.takeException(), isNull);
    expect(find.text('Word'), findsOneWidget);
    await pump(tester, 'en', const Size(1024, 700));
    expect(tester.takeException(), isNull);
  });
}
