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

List<Verse> _chapter(String book, int c, {int verses = 2}) => [
      for (var v = 1; v <= verses; v++)
        Verse(
            book: book,
            chapter: c,
            verse: v,
            text: verses > 2
                ? '$book $c verse $v ${'and God spoke these words for a long while ' * 4}'
                : '$book $c ${v == 1 ? 'one' : 'two'}'),
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
      {ReadingSession? session, int firstChapterVerses = 2}) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final verses = [
      for (var c = 1; c <= 6; c++)
        ..._chapter('Genesis', c, verses: c == 1 ? firstChapterVerses : 2),
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
                  Chapter(
                      title: c,
                      verses: _chapter('Genesis', c,
                          verses: c == 1 ? firstChapterVerses : 2)),
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

  testWidgets('session: back arrow instead of Home, nothing read yet',
      (tester) async {
    await pumpReader(tester, session: three);
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    expect(find.byIcon(Icons.home_rounded), findsNothing);
    expect(find.byKey(const ValueKey('readingSession.strip')), findsOneWidget);
    final bar = tester.widget<LinearProgressIndicator>(
        find.byKey(const ValueKey('readingSession.progress')));
    // The bar is how much has been READ, not which page is open.
    expect(bar.value, 0.0);
    expect(find.textContaining('Chapter 1 of 3'), findsOneWidget);
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
    expect(find.textContaining('Chapter 3 of 3'), findsOneWidget);
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
    expect(find.textContaining('Chapter 3 of 3'), findsOneWidget);
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

  testWidgets('session: scrolling each chapter to its end records it, and the day completes',
      (tester) async {
    // A real running plan whose day 1 is Genesis 1-3. The seeded chapters
    // are two verses each, so each is entirely on screen: "scrolled to the
    // end" is true the moment it opens.
    final svc = ReadingPlanService.instance;
    late String id;
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.runAsync(() async {
      svc.clock = () => DateTime(2026, 1, 1, 9);
      await svc.reload();
      id = (await svc.start('bible-1y', startDate: DateTime(2026, 1, 1)))!.id;
    });
    final session = ReadingSession.forDay(
        id, 1, const [ReadingSegment('Genesis', 1, 3)]);
    final mp = await pumpReader(tester, session: session);
    final next = find.byIcon(Icons.chevron_right_rounded);
    Future<void> settle() async {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 600));
    }
    await settle();
    expect(svc.entry(id)!.readChapters[1], {'Genesis|1'});
    expect(svc.entry(id)!.done, isEmpty);
    await tester.tap(next);
    await settle();
    expect(svc.entry(id)!.readChapters[1], {'Genesis|1', 'Genesis|2'});
    await tester.tap(next);
    await settle();
    expect(mp.currentChapter, 3);
    final e = svc.entry(id)!;
    expect(e.done, {1}, reason: 'all three chapters were read to the end');
    expect(e.doneOn.keys, {1});
    expect(e.readChapters, isEmpty);
    await tester.pump(const Duration(seconds: 3)); // let the toast go
    await tester.runAsync(() async {
      for (final x in svc.entries) {
        await svc.remove(x.id);
      }
    });
  });

  testWidgets('session: a long chapter is not read until it is scrolled to the end',
      (tester) async {
    final svc = ReadingPlanService.instance;
    late String id;
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.runAsync(() async {
      svc.clock = () => DateTime(2026, 1, 1, 9);
      await svc.reload();
      id = (await svc.start('bible-1y', startDate: DateTime(2026, 1, 1)))!.id;
    });
    // Day 1 of this plan is Genesis 1-3; chapter 1 is the long one.
    final session = ReadingSession.forDay(
        id, 1, const [ReadingSegment('Genesis', 1, 3)]);
    await pumpReader(tester, session: session, firstChapterVerses: 30);
    Future<void> settle() async {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 300));
    }

    await settle();
    expect(svc.entry(id)!.readChapters, isEmpty,
        reason: 'only the top of the chapter is on screen');
    // scroll down a little: still not at the end
    await tester.drag(find.byType(PageView), const Offset(0, -400));
    await settle();
    expect(svc.entry(id)!.readChapters, isEmpty);
    // ...and to the end
    for (var i = 0;
        i < 80 && svc.entry(id)!.readChapters.isEmpty;
        i++) {
      await tester.drag(find.byType(PageView), const Offset(0, -700));
      await settle();
    }
    // The end of chapter 1 is recorded; the day is not done (2 and 3 unread).
    expect(svc.entry(id)!.readChapters[1], {'Genesis|1'});
    expect(svc.entry(id)!.done, isEmpty);
    await tester.pump(const Duration(seconds: 3));
    await tester.runAsync(() async {
      for (final x in svc.entries) {
        await svc.remove(x.id);
      }
    });
  });

  testWidgets('no session: the ordinary reader keeps Home and has no strip',
      (tester) async {
    await pumpReader(tester);
    expect(find.byIcon(Icons.home_rounded), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);
    expect(find.byKey(const ValueKey('readingSession.strip')), findsNothing);
  });
}
