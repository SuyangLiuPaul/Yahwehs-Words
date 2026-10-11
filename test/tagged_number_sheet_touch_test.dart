import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahwehs_words/models/app_settings.dart';
import 'package:yahwehs_words/models/verse.dart';
import 'package:yahwehs_words/providers/main_provider.dart';
import 'package:yahwehs_words/services/originals_service.dart';
import 'package:yahwehs_words/services/tagged_text_service.dart';
import 'package:yahwehs_words/services/strongs_service.dart';
import 'package:yahwehs_words/services/concordance_service.dart';
import 'package:yahwehs_words/widgets/originals_sheet.dart';

void main() {
  testWidgets(
      'Hebrews 7:27 daily implied and primary numbers respond to actual touches',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1100, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const verse = Verse(book: 'Hebrews', chapter: 7, verse: 27, text: '每日');
    await tester.runAsync(() async {
      await OriginalsService.forVerse('Hebrews', 7, 27, version: 'cuvs-yhwh');
      final runs = await TaggedTextService.forVerse(
          version: 'cuvs-yhwh', englishBook: 'Hebrews', chapter: 7, verse: 27);
      expect(runs!.firstWhere((r) => r.text.contains('每日')).lexicalNumbers,
          ['G2596', 'G2250']);
      for (final n in ['G2596', 'G2250']) {
        await StrongsService.lookup(n);
        await ConcordanceService.lookup(n, version: 'cuvs-yhwh');
      }
    });
    for (final number in ['G2250', 'G2596']) {
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AppSettings()),
            ChangeNotifierProvider(create: (_) => MainProvider()),
          ],
          child: const MaterialApp(
              home: Scaffold(
                  body: OriginalsSheet(
                      verses: [verse],
                      allVerses: [verse],
                      locale: 'en',
                      currentVersion: 'cuvs-yhwh')))));
      for (var i = 0; i < 15; i++) {
        await tester.pump();
      }
      final f = find.byWidgetPredicate((w) =>
          w is RichText &&
          w.text.toPlainText().contains('每日') &&
          w.text.toPlainText().contains('(G2250)'));
      expect(f, findsOneWidget);
      final p = tester.renderObject<RenderParagraph>(f);
      final text = p.text.toPlainText();
      // Each numeric span is atomic: a line-wrapped leading space otherwise
      // makes Flutter web's semantic rectangle cover intervening numbers.
      void checkNumbers(InlineSpan span) {
        if (span is TextSpan) {
          if (span.recognizer != null &&
              RegExp(r'[GH]\d').hasMatch(span.text ?? '')) {
            expect(span.text, startsWith('\u00a0'));
          }
          for (final child in span.children ?? <InlineSpan>[]) {
            checkNumbers(child);
          }
        }
      }

      checkNumbers(p.text);
      final daily = text.indexOf('每日');
      final start = text.indexOf(number, daily);
      final box = p
          .getBoxesForSelection(TextSelection(
              baseOffset: start, extentOffset: start + number.length))
          .first;
      final point = p.localToGlobal(box.toRect().center);
      expect(point.dy, inInclusiveRange(0, 1600));
      await tester.tapAt(point);
      await tester.pump();
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)));
      for (var i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byKey(ValueKey('lexicon-entry-$number')), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
