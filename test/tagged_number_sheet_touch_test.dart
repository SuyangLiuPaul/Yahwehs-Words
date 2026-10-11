import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  for (final version in [
    'cuvs-yhwh',
    'cuvs-yhwh-tr',
    'bsb-yhwh',
    'asv-yhwh',
    'bib'
  ]) {
    testWidgets('$version Hebrews 7:27 numbers respond to actual touches',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1100, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      late Verse verse;
      final taggedWords = <String, String>{};
      await tester.runAsync(() async {
        final corpus =
            jsonDecode(await rootBundle.loadString('assets/$version.json'))
                as List;
        verse = Verse.fromJson(
            (corpus.cast<Map>().firstWhere((v) => v['id'] == '058007027'))
                .cast<String, dynamic>());
        await OriginalsService.forVerse('Hebrews', 7, 27, version: version);
        final runs = await TaggedTextService.forVerse(
            version: version, englishBook: 'Hebrews', chapter: 7, verse: 27);
        final daily =
            runs!.firstWhere((r) => r.lexicalNumbers.contains('G2250'));
        for (final number in ['G2250', 'G2596']) {
          taggedWords[number] =
              runs.firstWhere((r) => r.lexicalNumbers.contains(number)).text;
        }
        expect(daily.lexicalNumbers, contains('G2250'));
        for (final n in ['G2596', 'G2250']) {
          await StrongsService.lookup(n);
          await ConcordanceService.lookup(n, version: version);
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
            child: MaterialApp(
                home: Scaffold(
                    body: OriginalsSheet(
                        verses: [verse],
                        allVerses: [verse],
                        locale: 'en',
                        currentVersion: version)))));
        for (var i = 0; i < 15; i++) {
          await tester.pump();
        }
        final taggedWord = taggedWords[number]!;
        final f = find.byWidgetPredicate((w) =>
            w is RichText &&
            w.text.toPlainText().contains(taggedWord) &&
            w.text.toPlainText().contains(number));
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
        final daily = text.indexOf(taggedWord);
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
}
