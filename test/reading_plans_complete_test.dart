import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahwehs_words/models/app_settings.dart';
import 'package:yahwehs_words/pages/reading_plan_page.dart';
import 'package:yahwehs_words/providers/main_provider.dart';
import 'package:yahwehs_words/services/profile_service.dart';
import 'package:yahwehs_words/services/reading_plan_service.dart';

/// The rest of what other Bible-plan apps do (2026-10-16): a reader's own
/// plan, days off, a streak, "read" meaning scrolled to the end, bulk
/// catch-up, and the calendar moving while the app is open.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final catalog = ChapterCatalog.parse(
      File('assets/chapter_verses.json').readAsStringSync());
  final bundled = ReadingPlanService.parse(
      File('assets/reading_plans.json').readAsStringSync());
  ReadingPlan bundle(String id) => bundled.firstWhere((p) => p.id == id);

  late DateTime clockNow;
  final svc = ReadingPlanService.instance;
  Future<void> fresh({DateTime? at}) async {
    clockNow = at ?? DateTime(2026, 1, 10, 9);
    SharedPreferences.setMockInitialValues({});
    svc
      ..clock = (() => clockNow)
      ..loader = ((p) async => File(p).readAsString())
      ..onPersisted = null;
    await svc.plans();
    await svc.reload();
  }

  group("a reader's own plan", () {
    test('the whole Bible in 365 days IS the bundled plan, day for day', () {
      final mine = buildCustomPlan(
          CustomPlanSpec(books: catalog.books, days: 365), catalog);
      expect(mine.schedule, bundle('bible-1y').schedule);
    });

    test('the New Testament in 90 days and the Gospels in 30 match too', () {
      final nt = catalog.books.skip(39).toList();
      expect(buildCustomPlan(CustomPlanSpec(books: nt, days: 90), catalog).schedule,
          bundle('nt-90').schedule);
      expect(
          buildCustomPlan(
                  const CustomPlanSpec(
                      books: ['Matthew', 'Mark', 'Luke', 'John'], days: 30),
                  catalog)
              .schedule,
          bundle('gospels-30').schedule);
    });

    test('any books, any days: every chapter once, in canon order, none empty', () {
      final rng = Random(7);
      for (var t = 0; t < 40; t++) {
        final books = <String>{
          for (final b in catalog.books)
            if (rng.nextInt(6) == 0) b,
        };
        if (books.isEmpty) books.add('Jude');
        final chapters = catalog.chapterCount(books);
        final days = 1 + rng.nextInt(chapters);
        final plan = buildCustomPlan(
            CustomPlanSpec(books: books.toList()..shuffle(rng), days: days),
            catalog);
        expect(plan.days, days);
        expect(plan.schedule.every((d) => d.isNotEmpty), isTrue, reason: '$books $days');
        final seen = <String>[];
        for (final day in plan.schedule) {
          for (final s in day) {
            for (var c = s.from; c <= s.to; c++) {
              seen.add('${s.book}|$c');
            }
          }
        }
        final expected = <String>[
          for (final b in catalog.books)
            if (books.contains(b))
              for (var c = 1; c <= catalog.verses[b]!.length; c++) '$b|$c',
        ];
        expect(seen, expected, reason: '$books in $days days');
      }
    });

    test('more days than chapters is one chapter a day; no books is no plan', () {
      final p = buildCustomPlan(
          const CustomPlanSpec(books: ['Obadiah'], days: 50), catalog);
      expect((p.days, p.schedule.single.single.book), (1, 'Obadiah'));
      expect(buildCustomPlan(const CustomPlanSpec(books: [], days: 5), catalog).days, 0);
      expect(
          buildCustomPlan(const CustomPlanSpec(books: ['Nonsense'], days: 5), catalog)
              .days,
          0);
    });

    test('it is stored in the entry, survives JSON, and malformed ones are dropped', () {
      final e = ReadingPlanProgress(
          planId: 'custom',
          custom: const CustomPlanSpec(
              name: 'Paul', books: ['Romans', 'Galatians'], days: 20),
          start: DateTime(2026, 1, 1),
          done: const {1},
          updatedMs: 1);
      final back = ReadingPlanProgress.tryParse(e.toJson())!;
      expect(back.custom, e.custom);
      expect(ReadingPlanProgress.fromMap({'planId': 'custom', 'start': '2026-01-01'}),
          isNull);
      expect(
          ReadingPlanProgress.fromMap({
            'planId': 'custom',
            'start': '2026-01-01',
            'custom': {'books': [], 'days': 3}
          }),
          isNull);
    });

    test('the service runs it: plan, name, reminder, reading it', () async {
      await fresh(at: DateTime(2026, 1, 3, 9));
      final e = (await svc.start('custom',
          custom: const CustomPlanSpec(name: 'Paul', books: ['Romans'], days: 4),
          startDate: DateTime(2026, 1, 1),
          remind: true))!;
      final plan = svc.planFor(e)!;
      expect(plan.days, 4);
      expect(readingPlanName(plan, 'en'), 'Paul');
      final r = await svc.reminderForEntry(e, DateTime(2026, 1, 3, 8), 'en');
      expect(r!.title, 'Paul · Day 3 of 4');
      final auto = buildCustomPlan(
          const CustomPlanSpec(books: ['Romans'], days: 4), catalog);
      expect(readingPlanName(auto, 'en'), 'Custom: Romans in 4 days');
      expect(readingPlanName(auto, 'zh-Hans'), '自选：罗马书，4 天');
    });
  });

  group('days off', () {
    // 2026-01-05 is a Monday.
    ReadingPlanProgress weekdays(String start) => ReadingPlanProgress(
        planId: 'p',
        start: DateTime.parse(start),
        done: const {},
        restDays: const {6, 7},
        updatedMs: 1);

    test('Saturday and Sunday do not advance the plan', () {
      final p = weekdays('2026-01-05');
      final days = [
        for (var i = 0; i < 9; i++) p.calendarDay(DateTime(2026, 1, 5 + i, 12)),
      ];
      expect(days, [1, 2, 3, 4, 5, 5, 5, 6, 7]);
      expect(p.dateOfDay(6), DateTime(2026, 1, 12));
      expect(p.isRestDate(DateTime(2026, 1, 10)), isTrue);
      expect(p.isRestDate(DateTime(2026, 1, 12)), isFalse);
    });

    test('starting on a day off: day 1 is the next day that is not', () {
      final p = weekdays('2026-01-10'); // a Saturday
      expect(p.calendarDay(DateTime(2026, 1, 10)), 0);
      expect(p.calendarDay(DateTime(2026, 1, 11)), 0);
      expect(p.calendarDay(DateTime(2026, 1, 12)), 1);
      expect(p.dateOfDay(1), DateTime(2026, 1, 12));
    });

    test('day numbers and dates agree for any start, any days off, any day', () {
      final rng = Random(11);
      for (var t = 0; t < 300; t++) {
        final rest = <int>{for (var d = 1; d <= 7; d++) if (rng.nextInt(3) == 0) d};
        final p = ReadingPlanProgress(
            planId: 'p',
            start: DateTime(2026, 1, 1 + rng.nextInt(60)),
            done: const {},
            restDays: rest,
            updatedMs: 1);
        for (var d = 1; d <= 40; d += 1 + rng.nextInt(5)) {
          expect(p.calendarDay(p.dateOfDay(d)), d, reason: '$rest ${p.start} day $d');
          expect(p.isRestDate(p.dateOfDay(d)), isFalse);
        }
        // never goes backwards
        var last = -999;
        for (var i = 0; i < 40; i++) {
          final c = p.calendarDay(DateTime(2026, 1, 1 + i));
          expect(c >= last, isTrue);
          last = c;
        }
        // the start date that puts day d on a given date
        final on = DateTime(2026, 3, 1 + rng.nextInt(30));
        final d = 1 + rng.nextInt(30);
        final s = p.startForDayOn(on, d);
        expect(p.copyWith(start: s).calendarDay(on), d, reason: '$rest on $on d$d');
      }
    });

    test('seven days off is read as none; the plan never stops', () {
      final p = ReadingPlanProgress(
          planId: 'p',
          start: DateTime(2026, 1, 1),
          done: const {},
          restDays: const {1, 2, 3, 4, 5, 6, 7},
          updatedMs: 1);
      expect(p.calendarDay(DateTime(2026, 1, 4)), 4);
    });

    test('no reminder on a day off', () {
      final plan = ReadingPlan('bible-1y', 9, [
        for (var d = 1; d <= 9; d++) [ReadingSegment('Genesis', d, d)],
      ]);
      final p = weekdays('2026-01-05');
      expect(readingPlanReminder(progress: p, plan: plan, fire: DateTime(2026, 1, 9, 8), locale: 'en'),
          isNotNull);
      expect(readingPlanReminder(progress: p, plan: plan, fire: DateTime(2026, 1, 10, 8), locale: 'en'),
          isNull);
    });

    test('changing the days off does not move today to another plan day', () async {
      await fresh(at: DateTime(2026, 2, 4, 9)); // a Wednesday
      final e = (await svc.start('bible-1y', startDate: DateTime(2026, 1, 5)))!;
      final plan = svc.planFor(e)!;
      final before = readingPlanStatus(svc.entry(e.id)!, plan.days, svc.now).today;
      await svc.setRestDays(e.id, {6, 7});
      final after = svc.entry(e.id)!;
      expect(readingPlanStatus(after, plan.days, svc.now).today, before);
      expect(after.restDays, {6, 7});
      await svc.setRestDays(e.id, {1, 2, 3, 4, 5, 6, 7});
      expect(svc.entry(e.id)!.restDays, isEmpty);
    });

    test('pause and resume across days off still picks up the same day', () async {
      await fresh(at: DateTime(2026, 1, 8, 9)); // Thursday, day 4
      final e = (await svc.start('bible-1y',
          startDate: DateTime(2026, 1, 5), restDays: {6, 7}))!;
      final plan = svc.planFor(e)!;
      expect(readingPlanStatus(svc.entry(e.id)!, plan.days, svc.now).today, 4);
      await svc.pause(e.id);
      clockNow = DateTime(2026, 1, 21, 9); // two weeks later, a Wednesday
      await svc.resume(e.id);
      final st = readingPlanStatus(svc.entry(e.id)!, plan.days, svc.now);
      expect((st.today, st.paused), (4, false));
    });
  });

  group('reading means reaching the end', () {
    test('every chapter of the day, once each, completes it; nothing sooner', () async {
      await fresh(at: DateTime(2026, 1, 1, 9));
      final e = (await svc.start('bible-1y', startDate: DateTime(2026, 1, 1)))!; // day 1 = Genesis 1-3
      expect(await svc.markChapterRead(e.id, 1, 'Genesis|1'), ChapterReadResult.partial);
      expect(await svc.markChapterRead(e.id, 1, 'Genesis|1'), ChapterReadResult.already);
      expect(svc.chaptersRead(e.id, 1), {'Genesis|1'});
      expect(svc.entry(e.id)!.done, isEmpty);
      expect(await svc.markChapterRead(e.id, 1, 'Genesis|2'), ChapterReadResult.partial);
      expect(await svc.markChapterRead(e.id, 1, 'Genesis|3'), ChapterReadResult.dayDone);
      final r = svc.entry(e.id)!;
      expect(r.done, {1});
      expect(r.readChapters, isEmpty);
      expect(r.doneOn[1], epochDayOf(DateTime(2026, 1, 1)));
      expect(await svc.markChapterRead(e.id, 1, 'Genesis|3'), ChapterReadResult.already);
    });

    test('a chapter that is not in that day is not credited', () async {
      await fresh(at: DateTime(2026, 1, 1, 9));
      final e = (await svc.start('bible-1y', startDate: DateTime(2026, 1, 1)))!;
      expect(await svc.markChapterRead(e.id, 1, 'Genesis|9'), ChapterReadResult.notTracked);
      expect(await svc.markChapterRead(e.id, 1, 'Exodus|1'), ChapterReadResult.notTracked);
      expect(await svc.markChapterRead('nope', 1, 'Genesis|1'), ChapterReadResult.notTracked);
      expect(svc.entry(e.id)!.readChapters, isEmpty);
    });

    test('making up an earlier day counts the same way, and a hand tick still works', () async {
      await fresh(at: DateTime(2026, 1, 5, 9));
      final e = (await svc.start('bible-1y', startDate: DateTime(2026, 1, 1)))!;
      // day 2 (a make-up) read through, day 3 ticked by hand
      final plan = svc.planFor(e)!;
      for (final s in plan.day(2)) {
        for (var c = s.from; c <= s.to; c++) {
          await svc.markChapterRead(e.id, 2, '${s.book}|$c');
        }
      }
      await svc.setDone(e.id, 3, true);
      expect(svc.entry(e.id)!.done, {2, 3});
      // un-ticking forgets the date too
      await svc.setDone(e.id, 3, false);
      expect(svc.entry(e.id)!.doneOn.keys, {2});
    });

    test('"I already read these" marks the earlier days on the days they fell', () async {
      await fresh(at: DateTime(2026, 1, 6, 9));
      final e = (await svc.start('bible-1y', startDate: DateTime(2026, 1, 1)))!;
      await svc.setDone(e.id, 2, true);
      await svc.skipMissed(e.id);
      await svc.markMissedRead(e.id);
      final r = svc.entry(e.id)!;
      expect(r.done, {1, 2, 3, 4, 5});
      expect(r.skipped, isEmpty, reason: 'read beats skipped');
      expect(r.doneOn[1], epochDayOf(DateTime(2026, 1, 1)));
      expect(r.doneOn[4], epochDayOf(DateTime(2026, 1, 4)));
      expect(r.done.contains(6), isFalse, reason: "today's reading stays");
    });
  });

  group('streak', () {
    ReadingPlanProgress withDays(List<DateTime> dates) => ReadingPlanProgress(
        planId: 'p',
        start: DateTime(2026, 1, 1),
        done: {for (var i = 0; i < dates.length; i++) i + 1},
        doneOn: {for (var i = 0; i < dates.length; i++) i + 1: epochDayOf(dates[i])},
        updatedMs: 1);

    test('consecutive days up to today; yesterday still counts; a gap breaks it', () {
      final e = withDays([for (var d = 6; d <= 9; d++) DateTime(2026, 1, d)]);
      var s = readingStreak([e], DateTime(2026, 1, 9, 20));
      expect((s.current, s.longest, s.totalDays), (4, 4, 4));
      s = readingStreak([e], DateTime(2026, 1, 10, 7)); // not read yet today
      expect(s.current, 4);
      s = readingStreak([e], DateTime(2026, 1, 11, 7)); // a whole day missed
      expect((s.current, s.longest), (0, 4));
    });

    test('across plans, one day counts once; the longest run is remembered', () {
      final a = withDays([DateTime(2026, 1, 1), DateTime(2026, 1, 2), DateTime(2026, 1, 3), DateTime(2026, 1, 9)]);
      final b = withDays([DateTime(2026, 1, 3), DateTime(2026, 1, 4), DateTime(2026, 1, 10)]);
      final s = readingStreak([a, b], DateTime(2026, 1, 10, 9));
      expect((s.current, s.longest, s.totalDays), (2, 4, 6));
      expect(readingStreak(const [], DateTime(2026, 1, 1)).totalDays, 0);
    });

    test('merging keeps the earliest date a day was read, and the chapters read so far', () {
      final a = ReadingPlanProgress(
          id: 'x', planId: 'bible-1y', start: DateTime(2026, 1, 1),
          done: const {1}, doneOn: {1: 20100, 2: 20150},
          readChapters: {3: {'Genesis|7'}}, updatedMs: 5);
      final b = ReadingPlanProgress(
          id: 'x', planId: 'bible-1y', start: DateTime(2026, 1, 1),
          done: const {2}, doneOn: {1: 20090},
          readChapters: {3: {'Genesis|8'}, 2: {'Genesis|4'}}, updatedMs: 9);
      final doc = ReadingPlansDoc.parse(mergeReadingPlanBlobs(
          jsonEncode({'v': 2, 'updatedMs': 5, 'plans': [a.toMap()]}),
          jsonEncode({'v': 2, 'updatedMs': 9, 'plans': [b.toMap()]})))!;
      final m = doc.active.single;
      expect(m.doneOn, {1: 20090, 2: 20150});
      expect(m.readChapters[3], {'Genesis|7', 'Genesis|8'});
      expect(m.readChapters.containsKey(2), isFalse, reason: 'day 2 is done');
    });
  });

  group('the calendar moves while the app is open', () {
    test('a new day tells listeners, once, and asks for reminders to be re-booked', () async {
      await fresh(at: DateTime(2026, 1, 10, 23, 58));
      var rebooked = 0;
      svc.onPersisted = () => rebooked++;
      var notified = 0;
      void l() => notified++;
      svc.addListener(l);
      addTearDown(() => svc.removeListener(l));
      svc.dayChangedForTest(); // first look: remembers the day
      final first = notified;
      svc.dayChangedForTest(); // same day: nothing
      expect(notified, first);
      clockNow = DateTime(2026, 1, 11, 0, 3);
      svc.dayChangedForTest();
      expect(notified, first + 1);
      await Future<void>.delayed(const Duration(milliseconds: 1300));
      expect(rebooked, greaterThanOrEqualTo(1));
    });
  });

  group('screen', () {
    setUpAll(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', (message) async {
        final name = utf8.decode(message!.buffer
            .asUint8List(message.offsetInBytes, message.lengthInBytes));
        if (name == 'AssetManifest.bin') {
          return const StandardMessageCodec().encodeMessage(<String, Object?>{});
        }
        final f = File(name);
        if (!f.existsSync()) return null;
        return ByteData.sublistView(f.readAsBytesSync());
      });
    });

    Future<void> mountPage(WidgetTester tester, {String locale = 'en'}) async {
      tester.view.physicalSize = const Size(402, 3400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final settings = AppSettings();
      await settings.setLocale(locale);
      await tester.pump(const Duration(seconds: 1));
      await tester.runAsync(() async {
        await fresh(at: DateTime(2026, 1, 6, 9));
        await svc.plans();
      });
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<AppSettings>.value(value: settings),
          ChangeNotifierProvider(create: (_) => MainProvider()),
        ],
        child: GetMaterialApp(home: ReadingPlanPage(service: svc)),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('make your own plan: the New Testament in 60 days, Mon-Fri', (tester) async {
      await mountPage(tester);
      await tester.tap(find.byKey(const ValueKey('plan.start.custom')));
      await tester.pumpAndSettle();
      // nothing chosen yet: it cannot be started
      expect(find.byKey(const ValueKey('custom.problem')), findsOneWidget);
      expect(
          tester.widget<FilledButton>(find.byKey(const ValueKey('start.confirm'))).onPressed,
          isNull);
      await tester.enterText(find.byKey(const ValueKey('custom.name')), 'NT slowly');
      await tester.tap(find.byKey(const ValueKey('custom.nt')));
      await tester.pump();
      await tester.enterText(find.byKey(const ValueKey('custom.days')), '260');
      await tester.pump();
      expect(find.byKey(const ValueKey('custom.problem')), findsNothing,
          reason: 'the NT has exactly 260 chapters');
      await tester.enterText(find.byKey(const ValueKey('custom.days')), '261');
      await tester.pump();
      expect(find.byKey(const ValueKey('custom.problem')), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('custom.days')), '60');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('daysOff.6')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('daysOff.7')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('start.confirm')));
      await tester.pumpAndSettle();
      final e = svc.entries.single;
      expect(e.planId, 'custom');
      expect(e.custom!.name, 'NT slowly');
      expect(e.custom!.days, 60);
      expect(e.custom!.books, hasLength(27));
      expect(e.restDays, {6, 7});
      expect(find.text('NT slowly'), findsWidgets);
      expect(find.byKey(ValueKey('plan.today.${e.id}')), findsOneWidget);
    });

    testWidgets('choose books one by one; finish-by date turns into reading days', (tester) async {
      await mountPage(tester);
      await tester.tap(find.byKey(const ValueKey('plan.start.custom')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('custom.choose')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('book.Romans')));
      await tester.tap(find.byKey(const ValueKey('book.Galatians')));
      await tester.tap(find.byKey(const ValueKey('books.done')));
      await tester.pumpAndSettle();
      expect(find.text('2 books, 22 chapters'), findsOneWidget);
      // the default 90 days is more than 22 chapters
      expect(find.byKey(const ValueKey('custom.problem')), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('custom.days')), '11');
      await tester.pump();
      expect(find.byKey(const ValueKey('custom.problem')), findsNothing);
      expect(find.text('About 2 chapters a day'), findsOneWidget);
    });

    testWidgets('the page shows the streak, when it ends, and chapters read so far', (tester) async {
      late String id;
      await mountPage(tester);
      await tester.runAsync(() async {
        id = (await svc.start('bible-1y', startDate: DateTime(2026, 1, 4)))!.id;
        await svc.markChapterRead(id, 3, 'Genesis|1'); // not yet: day 3 is Jan 6
        await svc.setDone(id, 1, true);
        await svc.setDone(id, 2, true);
      });
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('plan.streak')), findsOneWidget);
      expect(find.text('Days read: 1'), findsOneWidget,
          reason: 'both days were ticked today: one day with reading');
      expect(find.textContaining('Finishes 2027-01-03'), findsOneWidget);
    });

    testWidgets('manage: days off, "I already read these", and share falls back to a copy', (tester) async {
      late String id;
      await mountPage(tester);
      await tester.runAsync(() async {
        id = (await svc.start('bible-1y', startDate: DateTime(2026, 1, 1)))!.id;
      });
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('plan.manage.$id')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('daysOff.7')));
      await tester.pumpAndSettle();
      expect(svc.entry(id)!.restDays, {7});
      await tester.tap(find.byKey(const ValueKey('manage.markMissedRead')));
      await tester.pumpAndSettle();
      expect(svc.entry(id)!.done, {1, 2, 3, 4, 5});
      expect(find.byKey(const ValueKey('manage.markMissedRead')), findsNothing);
    });

    testWidgets('a finished plan can be read again with the same settings', (tester) async {
      late String id;
      await mountPage(tester);
      await tester.runAsync(() async {
        id = (await svc.start('psalms-proverbs-31',
                startDate: DateTime(2025, 12, 1), remind: true, hour: 7, minute: 15))!
            .id;
        for (var d = 1; d <= 31; d++) {
          await svc.setDone(id, d, true);
        }
      });
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('plan.manage.$id')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('manage.readAgain')));
      await tester.pumpAndSettle();
      expect(svc.entries, hasLength(2));
      final again = svc.entries.last;
      expect((again.planId, again.remind, again.hour, again.minute),
          ('psalms-proverbs-31', true, 7, 15));
      expect(again.start, DateTime(2026, 1, 6));
      expect(again.done, isEmpty);
    });
  });

  test('the profile-scoped key and the blob stay one undotted string', () {
    expect(ProfileService.instance.scopedKey(kReadingPlanKey), contains(kReadingPlanKey));
    expect(kReadingPlanKey.contains('.'), isFalse);
  });
}
