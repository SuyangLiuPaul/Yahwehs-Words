import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yahwehs_words/models/app_settings.dart';
import 'package:yahwehs_words/models/bible_evidence.dart';
import 'package:yahwehs_words/pages/evidence_detail_page.dart';
import 'package:yahwehs_words/providers/main_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final data = jsonDecode(File('assets/bible_evidence.json').readAsStringSync())
      as Map<String, dynamic>;
  final source = (data['evidences'] as List)
          .singleWhere((row) => row['id'] == 'cairo_genizah')
      as Map<String, dynamic>;
  // Exercise the actual museum location. Images are irrelevant to this
  // layout and are omitted from this fixture to keep the test offline.
  final evidence = BibleEvidence.fromJson({...source, 'images': <String>[]});
  const location = 'Cambridge University Library / Jewish Theological Seminary';

  for (final width in [320.0, 375.0, 402.0, 1024.0]) {
    for (final scale in [1.0, 1.8]) {
      testWidgets(
          'full evidence location wraps at $width px, text scale $scale',
          (tester) async {
        SharedPreferences.setMockInitialValues(
            <String, Object>{'locale': 'en'});
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, width == 402 ? 874 : 6000);
        addTearDown(tester.view.reset);
        final settings = AppSettings();
        await settings.setLocale('en');
        await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => MainProvider()),
            ChangeNotifierProvider<AppSettings>.value(value: settings),
          ],
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: EvidenceDetailPage(evidence: evidence),
          ),
        ));
        await tester.pump(const Duration(milliseconds: 700));
        expect(tester.takeException(), isNull);
        final label = find.text(location);
        expect(label, findsOneWidget);
        final text = tester.widget<Text>(label);
        expect(text.maxLines, isNull,
            reason: 'the museum name must not be truncated');
        expect(text.overflow, isNot(TextOverflow.ellipsis));
        final paragraph = tester.renderObject<RenderParagraph>(
            find.descendant(of: label, matching: find.byType(RichText)));
        final boxes = paragraph.getBoxesForSelection(
            const TextSelection(baseOffset: 0, extentOffset: location.length));
        expect(boxes, isNotEmpty);
        // Selection boxes may include trailing spaces past a wrapped line.
        // Check visible word spans rather than counting that whitespace as ink.
        for (final word in RegExp(r'\S+').allMatches(location)) {
          for (final box in paragraph.getBoxesForSelection(
              TextSelection(baseOffset: word.start, extentOffset: word.end))) {
            expect(box.left, greaterThanOrEqualTo(-0.1));
            expect(box.right, lessThanOrEqualTo(paragraph.size.width + 0.5));
          }
        }
        if (width == 320) {
          expect(boxes.map((box) => box.top).toSet().length, greaterThan(1),
              reason: 'the real long location must flow onto readable lines');
        }
        final icon = find.byIcon(Icons.place_outlined);
        expect(icon, findsOneWidget);
        expect(tester.getSize(icon).width, greaterThanOrEqualTo(14));
        expect(
            tester.getRect(icon).right, lessThan(tester.getRect(label).left));
        expect(tester.getRect(label).right, lessThanOrEqualTo(width));
      });
    }
  }
}
