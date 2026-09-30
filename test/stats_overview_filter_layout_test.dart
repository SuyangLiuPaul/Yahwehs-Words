import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yahwehs_words/models/app_settings.dart';
import 'package:yahwehs_words/pages/stats_page.dart';
import 'package:yahwehs_words/providers/main_provider.dart';
import 'package:yahwehs_words/services/originals_stats_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final width in [320.0, 375.0, 402.0, 1024.0]) {
    for (final scale in [1.0, 1.8]) {
      testWidgets('overview filters stay readable at $width px, scale $scale',
          (tester) async {
        SharedPreferences.setMockInitialValues(
            <String, Object>{'locale': 'en'});
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 900);
        addTearDown(tester.view.reset);
        // Load the real local corpus before pumping the asynchronous Overview.
        await tester.runAsync(() => OriginalsStatsService.aggregate());
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
            home: const StatsPage(),
          ),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final scope = find.text('Whole Bible');
        expect(scope, findsOneWidget);
        final paragraph = tester.renderObject<RenderParagraph>(
            find.descendant(of: scope, matching: find.byType(RichText)));
        final boxes = paragraph.getBoxesForSelection(
            const TextSelection(baseOffset: 0, extentOffset: 11));
        expect(boxes.map((box) => box.top).toSet(), hasLength(1),
            reason: 'the scope must not be squeezed into vertical letters');
        final particles =
            find.widgetWithText(FilterChip, 'Hide common particles');
        final filter = find.widgetWithText(OutlinedButton, 'Filter by passage');
        expect(particles, findsOneWidget);
        expect(filter, findsOneWidget);
        for (final finder in [scope, particles, filter]) {
          final rect = tester.getRect(finder);
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(width));
        }
        // The original controls remain interactive after they flow onto rows.
        await tester.tap(particles);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(tester.widget<FilterChip>(particles).selected, isFalse);
        await tester.tap(filter);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(BottomSheet), findsOneWidget);
      });
    }
  }
}
