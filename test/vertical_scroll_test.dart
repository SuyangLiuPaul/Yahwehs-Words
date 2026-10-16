// 2026-10-16: continuous vertical scrolling — chapters flow into each
// other in one list, the current chapter follows the scroll, and the
// reader's own navigation still lands on the right chapter.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yahwehs_words/models/app_settings.dart';
import 'package:yahwehs_words/models/book.dart';
import 'package:yahwehs_words/models/chapter.dart';
import 'package:yahwehs_words/models/verse.dart';
import 'package:yahwehs_words/pages/home_page.dart';
import 'package:yahwehs_words/providers/main_provider.dart';

List<Verse> _chapter(String book, int c, {int verses = 12}) => [
      for (var v = 1; v <= verses; v++)
        Verse(
            book: book,
            chapter: c,
            verse: v,
            text: '$book $c:$v ${'and God spoke these words for a while ' * 4}'),
    ];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(MainProvider, AppSettings)> pumpReader(WidgetTester tester,
      {required bool vertical, int startChapter = 1}) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final verses = [
      for (var c = 1; c <= 8; c++) ..._chapter('Genesis', c),
    ];
    final settings = AppSettings();
    await settings.setLocale('en');
    await settings.setVerticalScroll(vertical);
    late MainProvider mp;
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) {
          mp = MainProvider()
            ..currentVersion = 'kjv'
            ..currentBook = 'Genesis'
            ..currentChapter = startChapter
            ..setBooks([
              Book(title: 'Genesis', chapters: [
                for (var c = 1; c <= 8; c++)
                  Chapter(title: c, verses: _chapter('Genesis', c)),
              ]),
            ])
            ..setVerses(verses);
          return mp;
        }),
        ChangeNotifierProvider<AppSettings>.value(value: settings),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (c) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(c).push(
                  MaterialPageRoute<void>(builder: (_) => const HomePage())),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 500));
    return (mp, settings);
  }

  testWidgets('off by default: the reader pages, no chapter headings between',
      (tester) async {
    final (mp, settings) = await pumpReader(tester, vertical: false);
    expect(settings.verticalScroll, isFalse);
    expect(find.byKey(const ValueKey('flow.heading.Genesis 2')), findsNothing);
    expect(mp.currentChapter, 1);
  });

  testWidgets('on: the next chapter is in the same list, below the first',
      (tester) async {
    final (mp, _) = await pumpReader(tester, vertical: true);
    expect(mp.currentChapter, 1);
    expect(find.byKey(const ValueKey('flow.heading.Genesis 1')), findsOneWidget);
    // Scroll until chapter 2's heading is on screen: no page turn needed.
    for (var i = 0; i < 40; i++) {
      if (find.byKey(const ValueKey('flow.heading.Genesis 2')).evaluate().isNotEmpty) {
        break;
      }
      await tester.drag(find.byType(HomePage), const Offset(0, -300));
      await tester.pump(const Duration(milliseconds: 400));
    }
    expect(find.byKey(const ValueKey('flow.heading.Genesis 2')), findsOneWidget);
  });

  testWidgets('scrolling into chapter 3 makes it the current chapter',
      (tester) async {
    final (mp, _) = await pumpReader(tester, vertical: true);
    for (var i = 0; i < 80 && mp.currentChapter != 3; i++) {
      await tester.drag(find.byType(HomePage), const Offset(0, -400));
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(mp.currentChapter, 3);
    // And back up again: the current chapter follows in both directions.
    for (var i = 0; i < 80 && mp.currentChapter != 2; i++) {
      await tester.drag(find.byType(HomePage), const Offset(0, 400));
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(mp.currentChapter, 2);
  });

  testWidgets('the bottom bar steps to the next chapter heading',
      (tester) async {
    final (mp, _) = await pumpReader(tester, vertical: true);
    await tester.tap(find.byIcon(Icons.chevron_right_rounded));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
    expect(mp.currentChapter, 2);
    final y = tester
        .getTopLeft(find.byKey(const ValueKey('flow.heading.Genesis 2')))
        .dy;
    expect(y, lessThan(200), reason: 'chapter 2 starts near the top');
  });

  testWidgets('opening on chapter 5 starts at chapter 5, earlier ones above',
      (tester) async {
    final (mp, _) = await pumpReader(tester, vertical: true, startChapter: 5);
    expect(mp.currentChapter, 5);
    expect(find.byKey(const ValueKey('flow.heading.Genesis 5')), findsOneWidget);
    // Scrolling UP reaches chapter 4 — it is not a dead end.
    for (var i = 0; i < 80 && mp.currentChapter != 4; i++) {
      await tester.drag(find.byType(HomePage), const Offset(0, 400));
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(mp.currentChapter, 4);
  });
}
