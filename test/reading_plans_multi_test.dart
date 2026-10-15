import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahwehs_words/models/app_settings.dart';
import 'package:yahwehs_words/models/notification_category.dart';
import 'package:yahwehs_words/pages/dashboard_page.dart';
import 'package:yahwehs_words/pages/reading_plan_page.dart';
import 'package:yahwehs_words/providers/main_provider.dart';
import 'package:yahwehs_words/services/profile_service.dart';
import 'package:yahwehs_words/services/reading_plan_service.dart';

/// Several plans at once, a movable start date, pause, catching up and
/// per-plan reminders (2026-10-16). The service rules are plain tests;
/// the sheets and the home card are exercised through the screen.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  group('running several plans', () {
    test('two different plans, and the same plan twice, run side by side', () async {
      await fresh();
      final a = (await svc.start('bible-1y'))!;
      final b = (await svc.start('mcheyne',
          startDate: DateTime(2026, 1, 20)))!;
      final c = (await svc.start('bible-1y',
          startDate: DateTime(2026, 2, 1)))!;
      expect({a.id, b.id, c.id}, hasLength(3));
      expect(svc.entries.map((e) => e.planId), ['bible-1y', 'mcheyne', 'bible-1y']);
      // survives a restart
      await svc.reload();
      expect(svc.entries.map((e) => e.id), [a.id, b.id, c.id]);
      expect(svc.entry(b.id)!.start, DateTime(2026, 1, 20));
    });

    test('at most $kMaxReadingPlans are kept', () async {
      await fresh();
      for (var i = 0; i < kMaxReadingPlans; i++) {
        expect(await svc.start('nt-90'), isNotNull);
      }
      expect(await svc.start('nt-90'), isNull);
      await svc.remove(svc.entries.first.id);
      expect(await svc.start('nt-90'), isNotNull);
    });

    test('marking a day read in one plan leaves the other alone', () async {
      await fresh();
      final a = (await svc.start('bible-1y'))!;
      final b = (await svc.start('mcheyne'))!;
      await svc.setDone(a.id, 1, true);
      expect(svc.entry(a.id)!.done, {1});
      expect(svc.entry(b.id)!.done, isEmpty);
      await svc.setDone(a.id, 1, false);
      expect(svc.entry(a.id)!.done, isEmpty);
    });

    test('every change is stamped later than the one before, even within a millisecond', () async {
      await fresh();
      final a = (await svc.start('bible-1y'))!;
      var last = a.updatedMs;
      for (var i = 1; i <= 4; i++) {
        await svc.setDone(a.id, i, true);
        final now = svc.entry(a.id)!.updatedMs;
        expect(now, greaterThan(last));
        last = now;
      }
    });

    test('a removed plan is kept as a tombstone, then forgotten after 90 days', () async {
      await fresh();
      final a = (await svc.start('bible-1y'))!;
      await svc.remove(a.id);
      expect(svc.entries, isEmpty);
      final prefs = await SharedPreferences.getInstance();
      final key = ProfileService.instance.scopedKey(kReadingPlanKey);
      var doc = ReadingPlansDoc.parse(prefs.getString(key))!;
      expect(doc.entries.single.deleted, isTrue);
      clockNow = clockNow.add(const Duration(days: kReadingPlanTombstoneDays + 1));
      await svc.start('nt-90'); // any save sweeps old tombstones
      doc = ReadingPlansDoc.parse(prefs.getString(key))!;
      expect(doc.entries.where((e) => e.deleted), isEmpty);
    });

    test('a change tells the notification scheduler, once, after a pause', () async {
      await fresh();
      var calls = 0;
      final done = Completer<void>();
      svc.onPersisted = () {
        calls++;
        done.complete();
      };
      final a = (await svc.start('bible-1y'))!;
      await svc.setDone(a.id, 1, true);
      await done.future.timeout(const Duration(seconds: 5));
      expect(calls, 1);
    });
  });

  group('start date, pause, catching up', () {
    test('moving the start date moves today and keeps what was read', () async {
      await fresh(at: DateTime(2026, 1, 10, 9));
      final a = (await svc.start('bible-1y', startDate: DateTime(2026, 1, 1)))!;
      await svc.setDone(a.id, 1, true);
      final plan = (await svc.plan('bible-1y'))!;
      expect(readingPlanStatus(svc.entry(a.id)!, plan.days, svc.now).today, 10);
      await svc.setStart(a.id, DateTime(2026, 1, 8));
      final e = svc.entry(a.id)!;
      expect(readingPlanStatus(e, plan.days, svc.now).today, 3);
      expect(e.done, {1});
    });

    test('a start date in the future is "not started" until it comes', () async {
      await fresh(at: DateTime(2026, 1, 10, 9));
      final a = (await svc.start('bible-1y', startDate: DateTime(2026, 2, 1)))!;
      final plan = (await svc.plan('bible-1y'))!;
      expect(readingPlanStatus(a, plan.days, svc.now).notStarted, isTrue);
      clockNow = DateTime(2026, 2, 1, 7);
      final st = readingPlanStatus(svc.entry(a.id)!, plan.days, svc.now);
      expect((st.notStarted, st.today), (false, 1));
    });

    test('pausing freezes the day; resuming picks up where it stopped, nothing behind', () async {
      await fresh(at: DateTime(2026, 1, 5, 9));
      final a = (await svc.start('bible-1y', startDate: DateTime(2026, 1, 1)))!;
      final plan = (await svc.plan('bible-1y'))!;
      await svc.setDone(a.id, 1, true);
      await svc.setDone(a.id, 2, true);
      await svc.setDone(a.id, 3, true);
      await svc.setDone(a.id, 4, true);
      await svc.setDone(a.id, 5, true);
      await svc.pause(a.id);
      clockNow = DateTime(2026, 1, 12, 9); // a week away
      var st = readingPlanStatus(svc.entry(a.id)!, plan.days, svc.now);
      expect((st.paused, st.today, st.unreadBefore), (true, 5, 0));
      await svc.resume(a.id);
      final e = svc.entry(a.id)!;
      expect(e.paused, isFalse);
      st = readingPlanStatus(e, plan.days, svc.now);
      // day 5 was today when it paused; today is day 5 again, not day 12
      expect((st.today, st.unreadBefore), (5, 0));
    });

    test('"pick up where I left off" slides the schedule: first unread day becomes today', () async {
      await fresh(at: DateTime(2026, 1, 6, 9));
      final a = (await svc.start('bible-1y', startDate: DateTime(2026, 1, 1)))!;
      final plan = (await svc.plan('bible-1y'))!;
      await svc.setDone(a.id, 1, true);
      var st = readingPlanStatus(svc.entry(a.id)!, plan.days, svc.now);
      expect((st.today, st.unreadBefore, st.resumeDay), (6, 4, 2));
      await svc.catchUp(a.id);
      final e = svc.entry(a.id)!;
      st = readingPlanStatus(e, plan.days, svc.now);
      expect((st.today, st.unreadBefore), (2, 0));
      expect(e.done, {1}, reason: 'nothing is marked read by catching up');
    });

    test('"skip the missed days" stops them counting as behind; today stays', () async {
      await fresh(at: DateTime(2026, 1, 6, 9));
      final a = (await svc.start('bible-1y', startDate: DateTime(2026, 1, 1)))!;
      final plan = (await svc.plan('bible-1y'))!;
      await svc.setDone(a.id, 1, true);
      await svc.skipMissed(a.id);
      final e = svc.entry(a.id)!;
      expect(e.skipped, {2, 3, 4, 5});
      final st = readingPlanStatus(e, plan.days, svc.now);
      expect((st.today, st.unreadBefore, st.doneCount, st.skippedCount),
          (6, 0, 1, 4));
      expect(e.done.contains(6), isFalse);
      // reading a skipped day later makes it read, not skipped
      await svc.setDone(a.id, 3, true);
      expect(svc.entry(a.id)!.skipped, {2, 4, 5});
    });

    test('a plan whose every day is read or skipped is finished', () {
      final e = ReadingPlanProgress(
          planId: 'p',
          start: DateTime(2026, 1, 1),
          done: const {1, 2},
          skipped: const {3},
          updatedMs: 1);
      final st = readingPlanStatus(e, 3, DateTime(2026, 1, 2));
      expect((st.finished, st.resumeDay), (true, null));
    });
  });

  group('reminders', () {
    test('only plans that remind, are not paused and not finished are booked, with their own time', () async {
      await fresh(at: DateTime(2026, 1, 3, 9));
      final a = (await svc.start('bible-1y',
          startDate: DateTime(2026, 1, 1), remind: true, hour: 6, minute: 45))!;
      final b = (await svc.start('mcheyne',
          startDate: DateTime(2026, 1, 1), remind: true))!;
      final c = (await svc.start('nt-90', startDate: DateTime(2026, 1, 1)))!; // no reminder
      final d = (await svc.start('gospels-30',
          startDate: DateTime(2026, 1, 1), remind: true))!;
      await svc.pause(d.id);
      var slots = await svc.reminderSlots();
      expect(slots.map((s) => s.entry.id), [a.id, b.id]);
      expect((slots[0].hour, slots[0].minute), (6, 45));
      expect((slots[1].hour, slots[1].minute), (null, null));
      expect(slots.map((s) => s.entry.id), isNot(contains(c.id)));
      await svc.setReminder(b.id, remind: false);
      slots = await svc.reminderSlots();
      expect(slots.map((s) => s.entry.id), [a.id]);
    });

    test('a reminder can be given its own words and its own time, and cleared', () async {
      await fresh(at: DateTime(2026, 1, 3, 9));
      final a = (await svc.start('bible-1y', startDate: DateTime(2026, 1, 1)))!;
      await svc.setReminder(a.id,
          remind: true, hour: 21, minute: 5, message: 'Time to read!');
      var e = svc.entry(a.id)!;
      expect((e.remind, e.hour, e.minute, e.message), (true, 21, 5, 'Time to read!'));
      var r = await svc.reminderForEntry(e, DateTime(2026, 1, 3, 21), 'en');
      expect(r!.title, 'Time to read!');
      expect(r.body, isNotEmpty); // the day's passages
      await svc.setReminder(a.id, clearTime: true, clearMessage: true);
      e = svc.entry(a.id)!;
      expect((e.hour, e.minute, e.message), (null, null, null));
      r = await svc.reminderForEntry(e, DateTime(2026, 1, 3, 21), 'en');
      expect(r!.title, contains('Day 3 of 365'));
    });

    test('the web gets ONE notification: the plan itself, or a list when several are due', () async {
      await fresh(at: DateTime(2026, 1, 3, 9));
      await svc.start('bible-1y', startDate: DateTime(2026, 1, 1), remind: true);
      var r = await svc.reminderFor(DateTime(2026, 1, 3, 9), 'en');
      expect(r!.title, contains('Day 3 of 365'));
      await svc.start('mcheyne', startDate: DateTime(2026, 1, 1), remind: true);
      r = await svc.reminderFor(DateTime(2026, 1, 3, 9), 'en');
      expect(r!.title, contains('2'));
      expect(r.body.split('\n'), hasLength(2));
    });

    test('nothing to say when nothing reminds', () async {
      await fresh(at: DateTime(2026, 1, 3, 9));
      await svc.start('bible-1y', startDate: DateTime(2026, 1, 1));
      expect(await svc.reminderFor(DateTime(2026, 1, 3, 9), 'en'), isNull);
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

    Future<AppSettings> mountPage(WidgetTester tester, {Widget? home}) async {
      tester.view.physicalSize = const Size(402, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final settings = AppSettings();
      await settings.setLocale('en');
      await tester.pump(const Duration(seconds: 1));
      await tester.runAsync(() async {
        await svc.plans();
        await svc.reload();
      });
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<AppSettings>.value(value: settings),
          ChangeNotifierProvider(create: (_) => MainProvider()),
        ],
        child: GetMaterialApp(home: home ?? ReadingPlanPage(service: svc)),
      ));
      await tester.pumpAndSettle();
      return settings;
    }

    Future<void> seed(WidgetTester tester, Future<void> Function() go) async {
      await tester.runAsync(() async {
        await fresh(at: DateTime(2026, 1, 3, 9));
        await go();
      });
    }

    testWidgets('start sheet: tomorrow, a reminder at its own time with its own words',
        (tester) async {
      await seed(tester, () async {});
      final settings = await mountPage(tester);
      await tester.tap(find.byKey(const ValueKey('plan.start.mcheyne')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('start.tomorrow')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('reminder.switch')));
      await tester.pumpAndSettle();
      // notifications are off in settings: the sheet says so and offers Settings
      expect(find.byKey(const ValueKey('reminder.needsNotifications')),
          findsOneWidget);
      await tester.enterText(
          find.byKey(const ValueKey('reminder.message')), 'Go read');
      await tester.tap(find.byKey(const ValueKey('start.confirm')));
      await tester.pumpAndSettle();
      final e = svc.entries.single;
      expect(e.planId, 'mcheyne');
      expect(e.start, DateTime(2026, 1, 4));
      expect(e.remind, isTrue);
      expect(e.message, 'Go read');
      // switching a plan's reminder on switches the Reading plan category on
      expect(
          settings
              .notificationCategory(NotificationCategoryIds.readingPlan)
              .enabled,
          isTrue);
    });

    testWidgets('two plans show as two cards; the second is added from the same page',
        (tester) async {
      await seed(tester, () async {
        await svc.start('bible-1y');
      });
      await mountPage(tester);
      expect(find.byKey(const ValueKey('plan.card.bible-1y')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('plan.start.mcheyne')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('start.confirm')));
      await tester.pumpAndSettle();
      expect(svc.entries.map((e) => e.planId), ['bible-1y', 'mcheyne']);
      for (final e in svc.entries) {
        expect(find.byKey(ValueKey('plan.today.${e.id}')), findsOneWidget);
      }
    });

    testWidgets('manage sheet: pause, then resume; catch up and skip when behind',
        (tester) async {
      late String id;
      await seed(tester, () async {
        id = (await svc.start('bible-1y', startDate: DateTime(2025, 12, 30)))!.id;
      });
      await mountPage(tester);
      await tester.tap(find.byKey(ValueKey('plan.manage.$id')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('manage.catchUp')), findsOneWidget);
      expect(find.byKey(const ValueKey('manage.skipMissed')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('manage.pause')));
      await tester.pumpAndSettle();
      expect(svc.entry(id)!.paused, isTrue);
      await tester.tap(find.byKey(const ValueKey('manage.pause')));
      await tester.pumpAndSettle();
      expect(svc.entry(id)!.paused, isFalse);
      await tester.tap(find.byKey(const ValueKey('manage.skipMissed')));
      await tester.pumpAndSettle();
      expect(svc.entry(id)!.skipped, {1, 2, 3, 4});
      // nothing behind any more: the catch-up rows go
      expect(find.byKey(const ValueKey('manage.catchUp')), findsNothing);
    });

    for (final width in [320.0, 402.0]) {
      testWidgets('the page and both sheets lay out at $width with 1.6x text',
          (tester) async {
        late String id;
        await seed(tester, () async {
          id = (await svc.start('mcheyne',
                  startDate: DateTime(2025, 12, 30),
                  remind: true,
                  message: 'A rather long reminder sentence for the reader'))!
              .id;
          await svc.start('bible-1y');
        });
        tester.view.physicalSize = Size(width, 3000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final settings = AppSettings();
        await settings.setLocale('zh-Hant');
        await tester.pump(const Duration(seconds: 1));
        await tester.runAsync(() async {
          await svc.plans();
          await svc.reload();
        });
        await tester.pumpWidget(ChangeNotifierProvider<AppSettings>.value(
            value: settings,
            child: MaterialApp(
                builder: (c, child) => MediaQuery(
                    data: MediaQuery.of(c)
                        .copyWith(textScaler: const TextScaler.linear(1.6)),
                    child: child!),
                home: ReadingPlanPage(service: svc))));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(ValueKey('plan.manage.$id')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tapAt(const Offset(5, 5)); // dismiss
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('plan.start.nt-90')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('reminder.switch')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('home: no Reading plans card until a plan is started; then one row per plan',
        (tester) async {
      await seed(tester, () async {});
      await mountPage(tester, home: const DashboardPage());
      if (find.text('Skip').evaluate().isNotEmpty) {
        await tester.tap(find.text('Skip'));
        await tester.pumpAndSettle();
      }
      expect(find.byKey(const ValueKey('home.readingPlan')), findsNothing);
      await tester.runAsync(() async {
        await svc.start('bible-1y');
        await svc.start('mcheyne');
      });
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('home.readingPlan')), findsOneWidget);
      for (final e in svc.entries) {
        expect(find.byKey(ValueKey('home.readingPlan.${e.id}')), findsOneWidget);
      }
    });
  });
}
