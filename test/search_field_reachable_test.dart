// The search field is big enough to hit — 2026-09-20.
//
// Reported from an iPhone 12/14 with photos: the query in the app bar
// had wrapped into a two-character-per-line column and the field was a
// sliver. 「根本按不到」.
//
// The arithmetic behind it: `AppBar` gives its title whatever is left
// after the leading slot, the actions and twice `titleSpacing`. This
// bar spent 56 + 4x48 + 32 = 280 px of a 390 px phone, so the title got
// 110, and the pill then spent 44 of that on its own padding and icon —
// leaving the text about 58 px, or 32 with the clear button showing.
//
// These are floors, not exact numbers: they fail on the old layout and
// pass on anything at least as roomy as the new one.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahwehs_words/models/app_settings.dart';
import 'package:yahwehs_words/models/verse.dart';
import 'package:yahwehs_words/pages/search_page.dart';
import 'package:yahwehs_words/providers/main_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpSearch(WidgetTester tester, Size size) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) {
            final mp = MainProvider();
            mp.setVerses(const [
              Verse(book: 'Genesis', chapter: 1, verse: 1, text: 'seed'),
            ]);
            return mp;
          }),
          ChangeNotifierProvider(create: (_) => AppSettings()),
        ],
        child: const MaterialApp(home: SearchPage()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> teardown(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 250));
  }

  testWidgets('on an iPhone 14 the query field is a real target',
      (tester) async {
    await pumpSearch(tester, const Size(390, 844));

    final field = tester.getSize(find.byType(TextField).first);
    // The old layout measured ~58 px wide before a query is typed.
    expect(field.width, greaterThan(120),
        reason: 'the search field was a sliver: ${field.width} px');
    // And the pill around it takes the tap, at Apple's 44 pt minimum.
    final pill = tester.getSize(find.byType(GestureDetector).first);
    expect(pill.height, greaterThanOrEqualTo(40),
        reason: 'the pill is the tap target now: ${pill.height} px tall');

    await teardown(tester);
  });

  testWidgets('a typed query stays on one line, not a 2-char column',
      (tester) async {
    await pumpSearch(tester, const Size(390, 844));

    final field = tester.widget<TextField>(find.byType(TextField).first);
    expect(field.maxLines, 1,
        reason: 'two lines in a 110 px slot is what made the column');

    await tester.enterText(find.byType(TextField).first, '孤兒');
    await tester.pump();
    // Still one line, and still wide enough to tap, with the clear
    // button now showing.
    final size = tester.getSize(find.byType(TextField).first);
    expect(size.width, greaterThan(100),
        reason: 'with the clear button the old field fell to ~32 px');

    await teardown(tester);
  });

  testWidgets('and it still fits on a 320 px iPhone SE', (tester) async {
    await pumpSearch(tester, const Size(320, 568));
    expect(tester.takeException(), isNull);
    final field = tester.getSize(find.byType(TextField).first);
    expect(field.width, greaterThan(80));
    await teardown(tester);
  });
}
