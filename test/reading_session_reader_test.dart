// 2026-10-16: the reader opened from a reading plan is limited to the
// day's chapters (Genesis 1-3 is three pages, not the whole Bible), has
// a back arrow where Home normally sits, and a progress bar over the
// bottom bar.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yahwehs_words/models/app_settings.dart';
import 'package:yahwehs_words/models/book.dart';
import 'package:yahwehs_words/models/chapter.dart';
import 'package:yahwehs_words/models/verse.dart';
import 'package:get/get.dart';
import 'package:yahwehs_words/pages/dashboard_page.dart';
import 'package:yahwehs_words/pages/home_page.dart';
import 'package:yahwehs_words/pages/reading_plan_page.dart';
import 'package:yahwehs_words/providers/main_provider.dart';
import 'package:yahwehs_words/services/reading_plan_service.dart';

List<Verse> _chapter(String book, int c) => [
      Verse(book: book, chapter: c, verse: 1, text: '$book $c one'),
      Verse(book: book, chapter: c, verse: 2, text: '$book $c two'),
    ];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a day becomes its chapters, in the plan order, once each', () {
    final s = ReadingSession.forDay('e1', 7, const [
      ReadingSegment('Genesis', 1, 3),
      ReadingSegment('Matthew', 1, 1),
      ReadingSegment('Genesis', 3, 3), // overlap is not repeated
    ]);
    expect((s.entryId, s.day), ('e1', 7));
    expect(s.pages.map((p) => '${p.book} ${p.chapter}').toList(),
        ['Genesis 1', 'Genesis 2', 'Genesis 3', 'Matthew 1']);
    expect(s.indexOf('Genesis', 2), 1);
    expect(s.indexOf('Genesis', 4), -1);
  });

  Future<MainProvider> pumpReader(WidgetTester tester,
      {ReadingSession? session}) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final verses = [
      for (var c = 1; c <= 6; c++) ..._chapter('Genesis', c),
    ];
    final settings = AppSettings();
    await settings.setLocale('en');
    late MainProvider mp;
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) {
          mp = MainProvider()
            ..currentVersion = 'kjv'
            ..currentBook = 'Genesis'
            ..currentChapter = 1
            ..setBooks([
              Book(title: 'Genesis', chapters: [
                for (var c = 1; c <= 6; c++)
                  Chapter(title: c, verses: _chapter('Genesis', c)),
              ]),
            ])
            ..setVerses(verses);
          return mp;
        }),
        ChangeNotifierProvider<AppSettings>.value(value: settings),
      ],
      child: MaterialApp(
        // A route underneath, so the back arrow has somewhere to go.
        home: Builder(
          builder: (c) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(c).push(MaterialPageRoute<void>(
                  builder: (_) => HomePage(session: session))),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 500));
    return mp;
  }

  final three =
      ReadingSession.forDay('e1', 1, const [ReadingSegment('Genesis', 1, 3)]);

  testWidgets('session: back arrow instead of Home, progress 1 of 3',
      (tester) async {
    await pumpReader(tester, session: three);
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    expect(find.byIcon(Icons.home_rounded), findsNothing);
    expect(find.byKey(const ValueKey('readingSession.strip')), findsOneWidget);
    final bar = tester.widget<LinearProgressIndicator>(
        find.byKey(const ValueKey('readingSession.progress')));
    expect(bar.value, closeTo(1 / 3, 1e-9));
    expect(find.text('Chapter 1 of 3'), findsOneWidget);
  });

  testWidgets('session: next stops at the third chapter and offers to mark it',
      (tester) async {
    final mp = await pumpReader(tester, session: three);
    final next = find.byIcon(Icons.chevron_right_rounded);
    await tester.tap(next);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(next);
    await tester.pump(const Duration(milliseconds: 600));
    expect(mp.currentChapter, 3);
    expect(find.text('Chapter 3 of 3'), findsOneWidget);
    expect(find.byKey(const ValueKey('readingSession.done')), findsOneWidget);

    // A third tap goes nowhere: chapter 4 exists in the Bible, not in the day.
    await tester.tap(next, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 600));
    expect(mp.currentChapter, 3);
  });

  testWidgets('session: swiping past the last chapter stays on it',
      (tester) async {
    final mp = await pumpReader(tester, session: three);
    for (var i = 0; i < 4; i++) {
      await tester.drag(find.byType(PageView), const Offset(-300, 0));
      await tester.pump(const Duration(milliseconds: 600));
    }
    expect(mp.currentChapter, 3,
        reason: 'the pager still reaches Genesis 4: it is paging the Bible, '
            'not the day');
    expect(find.text('Chapter 3 of 3'), findsOneWidget);
  });

  testWidgets('session: the back arrow returns to the plan, not the root',
      (tester) async {
    await pumpReader(tester, session: three);
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('open'), findsOneWidget);
    expect(find.byType(HomePage), findsNothing);
  });

  testWidgets('the quick links carry a Reading plan tile that opens the plan',
      (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 2400);
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final settings = AppSettings();
    await settings.setLocale('en');
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MainProvider()),
        ChangeNotifierProvider<AppSettings>.value(value: settings),
      ],
      child: GetMaterialApp(
        home: const DashboardPage(),
        getPages: [
          GetPage(name: kReadingPlanPath, page: () => const ReadingPlanPage()),
        ],
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 400));

    // First-run welcome sits over the page; it is not what is under test.
    if (find.text('Skip').evaluate().isNotEmpty) {
      await tester.tap(find.text('Skip'));
      await tester.pump(const Duration(milliseconds: 500));
    }
    // No plan has been started, so there is no card — only the tile.
    final tile = find.text(rpText('readingPlan_title', 'en'));
    expect(tile, findsOneWidget);
    expect(find.byKey(const ValueKey('home.readingPlan')), findsNothing);
    await tester.tap(tile);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(ReadingPlanPage), findsOneWidget);
  });

  testWidgets('no session: the ordinary reader keeps Home and has no strip',
      (tester) async {
    await pumpReader(tester);
    expect(find.byIcon(Icons.home_rounded), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);
    expect(find.byKey(const ValueKey('readingSession.strip')), findsNothing);
  });
}
