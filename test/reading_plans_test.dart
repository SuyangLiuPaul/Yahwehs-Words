import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahwehs_words/constants/ui_strings.dart';
import 'package:yahwehs_words/models/app_settings.dart';
import 'package:yahwehs_words/models/dashboard_section.dart';
import 'package:yahwehs_words/models/notification_category.dart';
import 'package:yahwehs_words/services/notification_content.dart' show notificationCategoryLabel;
import 'package:yahwehs_words/pages/reading_plan_page.dart';
import 'package:yahwehs_words/services/profile_service.dart';
import 'package:yahwehs_words/services/reading_plan_service.dart';
import 'package:yahwehs_words/utils/route_paths.dart';

/// Reading plans, back since 2026-10-15 (removed v1.2.69).
///
/// What this guards, from what went wrong the first time:
///  * the schedules are what they claim (every chapter once, in order;
///    M'Cheyne's table matches its recorded sources);
///  * progress is one undotted key — dotted `plan.*` keys broke every
///    sync write once (v1.3.45);
///  * the sync merge never loses a day read on another device, and a
///    stop on one device is not undone by a stale plan on another;
///  * the date arithmetic survives daylight-saving changes.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final raw = File('assets/reading_plans.json').readAsStringSync();
  final plans = ReadingPlanService.parse(raw);
  final kjv = (jsonDecode(File('assets/kjv.json').readAsStringSync()) as List)
      .cast<Map<String, dynamic>>();
  final verseCount = <String, int>{};
  final bookOrder = <String>[];
  for (final r in kjv) {
    final key = '${r['book']}|${r['chapter']}';
    verseCount[key] = (verseCount[key] ?? 0) + 1;
    if (!bookOrder.contains(r['book'])) bookOrder.add(r['book'] as String);
  }
  int chapters(String book) => verseCount.keys
      .where((k) => k.startsWith('$book|'))
      .map((k) => int.parse(k.split('|')[1]))
      .reduce((a, b) => a > b ? a : b);

  /// Every (book, chapter, verse) a plan reads, with how many times.
  Map<String, int> coverage(ReadingPlan p) {
    final out = <String, int>{};
    for (final day in p.schedule) {
      for (final s in day) {
        for (var c = s.from; c <= s.to; c++) {
          final lo = (c == s.from && s.fromVerse != null) ? s.fromVerse! : 1;
          final hi = (c == s.to && s.toVerse != null)
              ? s.toVerse!
              : verseCount['${s.book}|$c']!;
          for (var v = lo; v <= hi; v++) {
            final k = '${s.book}|$c|$v';
            out[k] = (out[k] ?? 0) + 1;
          }
        }
      }
    }
    return out;
  }

  group('data', () {
    ReadingPlan byId(String id) => plans.firstWhere((p) => p.id == id);

    test('the six plans, each with the days it says', () {
      expect(plans.map((p) => p.id), [
        'bible-1y',
        'bible-1y-ot-nt',
        'mcheyne',
        'nt-90',
        'gospels-30',
        'psalms-proverbs-31',
      ]);
      for (final p in plans) {
        expect(p.schedule.length, p.days, reason: p.id);
        for (var d = 0; d < p.days; d++) {
          expect(p.schedule[d], isNotEmpty, reason: '${p.id} day ${d + 1}');
        }
      }
    });

    test('every segment names a real book and chapter', () {
      for (final p in plans) {
        for (final day in p.schedule) {
          for (final s in day) {
            expect(bookOrder, contains(s.book), reason: p.id);
            expect(s.from >= 1 && s.to >= s.from && s.to <= chapters(s.book),
                isTrue,
                reason: '${p.id} ${s.book} ${s.from}-${s.to}');
            if (s.fromVerse != null) {
              expect(s.fromVerse! <= verseCount['${s.book}|${s.from}']!, isTrue);
            }
            if (s.toVerse != null) {
              expect(s.toVerse! <= verseCount['${s.book}|${s.to}']!, isTrue);
            }
          }
        }
      }
    });

    test('bible-1y reads every chapter once, in order', () {
      final p = byId('bible-1y');
      final seen = <String>[];
      for (final day in p.schedule) {
        for (final s in day) {
          for (var c = s.from; c <= s.to; c++) {
            seen.add('${s.book}|$c');
          }
        }
      }
      final expected = [
        for (final b in bookOrder)
          for (var c = 1; c <= chapters(b); c++) '$b|$c'
      ];
      expect(seen, expected);
      expect(seen.length, 1189);
    });

    test('nt-90, gospels-30 and psalms-proverbs-31 cover exactly their books once', () {
      void exact(String id, List<String> books,
          {int times = 1, Set<String> twice = const {}}) {
        final cov = coverage(byId(id));
        final want = <String>{
          for (final b in books)
            for (var c = 1; c <= chapters(b); c++)
              for (var v = 1; v <= verseCount['$b|$c']!; v++) '$b|$c|$v'
        };
        expect(cov.keys.toSet(), want, reason: id);
        expect(cov.values.every((n) => n == times), isTrue, reason: id);
      }

      exact('nt-90', bookOrder.sublist(39));
      exact('gospels-30', ['Matthew', 'Mark', 'Luke', 'John']);
      exact('psalms-proverbs-31', ['Psalms', 'Proverbs']);
      expect(byId('psalms-proverbs-31').schedule.length, 31);
      // day n carries Proverbs n
      for (var d = 1; d <= 31; d++) {
        expect(
            byId('psalms-proverbs-31')
                .day(d)
                .any((s) => s.book == 'Proverbs' && s.from == d && s.to == d),
            isTrue,
            reason: 'day $d');
      }
    });

    test('bible-1y-ot-nt: OT 365 days, NT done by day 260, each once', () {
      final p = byId('bible-1y-ot-nt');
      final cov = coverage(p);
      expect(cov.length, kjv.length);
      expect(cov.values.every((n) => n == 1), isTrue);
      var lastNt = 0;
      for (var d = 1; d <= 365; d++) {
        if (p.day(d).any((s) => bookOrder.indexOf(s.book) >= 39)) lastNt = d;
        // every day has some OT
        expect(p.day(d).any((s) => bookOrder.indexOf(s.book) < 39), isTrue,
            reason: 'day $d');
      }
      expect(lastNt, 260);
    });

    test('days are balanced by verses, not by chapters', () {
      final p = byId('bible-1y');
      final per = [
        for (final day in p.schedule)
          day.fold<int>(0, (a, s) {
            var n = 0;
            for (var c = s.from; c <= s.to; c++) {
              n += verseCount['${s.book}|$c']!;
            }
            return a + n;
          })
      ];
      final mean = per.reduce((a, b) => a + b) / per.length;
      // No day more than about twice the average (Psalm 119 alone is 176).
      expect(per.reduce((a, b) => a > b ? a : b) <= mean * 2.2, isTrue);
    });

    test("M'Cheyne: OT once, NT and Psalms twice, from the recorded table", () {
      final p = byId('mcheyne');
      final cov = coverage(p);
      for (final r in kjv) {
        final k = '${r['book']}|${int.parse(r['chapter'] as String)}|'
            '${int.parse(r['verse'] as String)}';
        final want = (bookOrder.indexOf(r['book'] as String) >= 39 ||
                r['book'] == 'Psalms')
            ? 2
            : 1;
        expect(cov[k], want, reason: k);
      }
      // Anchors: Jan 1, Feb 28 (verse windows), Dec 31.
      expect(p.day(1).map((s) => '${s.book} ${s.from}').toList(),
          ['Genesis 1', 'Matthew 1', 'Ezra 1', 'Acts 1']);
      final feb28 = p.day(59);
      expect(feb28.first,
          const ReadingSegment('Exodus', 11, 12, 1, 21));
      expect(p.day(365).map((s) => s.book).toList().last, isNotEmpty);
    });

    test("M'Cheyne's source table records its provenance and agrees with the asset", () {
      final src = jsonDecode(
              File('tools/data/mcheyne_1842.json').readAsStringSync())
          as Map<String, dynamic>;
      final meta = src['_meta'] as Map<String, dynamic>;
      expect(meta['extracted_from'], contains('edginet.org'));
      expect((meta['verified_against'] as List).length, greaterThanOrEqualTo(2));
      final days = (src['days'] as List).cast<Map<String, dynamic>>();
      expect(days.length, 365);
      final p = byId('mcheyne');
      for (var i = 0; i < 365; i++) {
        final refs = (days[i]['refs'] as List).cast<List>();
        final got = p.day(i + 1);
        expect(got.length, refs.length, reason: 'day ${i + 1}');
        for (var j = 0; j < refs.length; j++) {
          expect(got[j].book, refs[j][0]);
          expect(got[j].from, refs[j][1]);
          expect(got[j].to, refs[j][2]);
        }
      }
    });

    test('the asset is exactly what the generator writes', () {
      final r = Process.runSync('python3', ['tools/build_reading_plans.py', '--check']);
      expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
    });
  });

  group('progress and the calendar', () {
    ReadingPlanProgress prog(String start, Set<int> done) => ReadingPlanProgress(
        planId: 'bible-1y',
        start: DateTime.parse(start),
        done: done,
        updatedMs: 1);

    test('round-trips through JSON; garbage parses to null', () {
      final p = prog('2026-03-05', {3, 1, 2});
      final back = ReadingPlanProgress.tryParse(p.toJson())!;
      expect(back.planId, 'bible-1y');
      expect(back.start, DateTime(2026, 3, 5));
      expect(back.done, {1, 2, 3});
      for (final bad in [null, '', 'x', '[]', '{"planId":"","start":"2026-01-01"}', '{"planId":"a","start":"nope"}']) {
        expect(ReadingPlanProgress.tryParse(bad), isNull, reason: '$bad');
      }
    });

    test('day numbers count from the start date, across a daylight-saving change', () {
      final p = prog('2026-03-01', {});
      expect(p.calendarDay(DateTime(2026, 3, 1, 23, 59)), 1);
      expect(p.calendarDay(DateTime(2026, 3, 2, 0, 1)), 2);
      // Spring-forward and fall-back dates (US/EU/AU) must not skip or repeat a day.
      for (final start in ['2026-03-01', '2026-10-01']) {
        final q = prog(start, {});
        final s = DateTime.parse(start);
        for (var i = 0; i < 70; i++) {
          final d = DateTime(s.year, s.month, s.day + i, 12);
          expect(q.calendarDay(d), i + 1, reason: '$start +$i');
        }
      }
      expect(prog('2026-06-01', {}).calendarDay(DateTime(2026, 5, 30)), -1);
    });

    test('status: on time, behind, not started, finished, calendar over', () {
      final start = '2026-01-01';
      var st = readingPlanStatus(prog(start, {1, 2}), 10, DateTime(2026, 1, 3));
      expect((st.today, st.unreadBefore, st.resumeDay, st.finished), (3, 0, 3, false));
      st = readingPlanStatus(prog(start, {1}), 10, DateTime(2026, 1, 5));
      expect((st.today, st.unreadBefore, st.resumeDay), (5, 3, 2));
      st = readingPlanStatus(prog(start, {}), 10, DateTime(2025, 12, 30));
      expect((st.notStarted, st.today), (true, 1));
      st = readingPlanStatus(
          prog(start, {for (var d = 1; d <= 10; d++) d}), 10, DateTime(2026, 1, 4));
      expect((st.finished, st.resumeDay), (true, null));
      st = readingPlanStatus(prog(start, {1, 2, 3}), 10, DateTime(2026, 2, 20));
      expect((st.calendarEnded, st.today, st.resumeDay), (true, 10, 4));
      // days outside the plan in a stored blob never count
      st = readingPlanStatus(prog(start, {1, 99, -3}), 10, DateTime(2026, 1, 2));
      expect(st.doneCount, 1);
    });
  });

  group('daily reminder', () {
    final plan = ReadingPlan('bible-1y', 5, [
      for (var d = 1; d <= 5; d++) [ReadingSegment('Genesis', d, d)],
    ]);
    ReadingPlanProgress prog(Set<int> done, {String start = '2026-01-01'}) =>
        ReadingPlanProgress(
            planId: 'bible-1y', start: DateTime.parse(start), done: done, updatedMs: 1);
    ({String title, String body})? at(ReadingPlanProgress? p, DateTime fire,
            {String locale = 'en', ReadingPlan? pl}) =>
        readingPlanReminder(
            progress: p, plan: pl ?? plan, fire: fire, locale: locale);

    test('says the day and its passages, in the reader\'s language', () {
      final r = at(prog({}), DateTime(2026, 1, 3, 8))!;
      expect(r.title, '${rpText('readingPlan_bible-1y_name', 'en')} · Day 3 of 5');
      expect(r.body, 'Genesis 3');
      expect(at(prog({}), DateTime(2026, 1, 3, 8), locale: 'zh-Hans')!.title,
          '${rpText('readingPlan_bible-1y_name', 'zh-Hans')} · 第 3 天，共 5 天');
      expect(at(prog({}), DateTime(2026, 1, 3, 8), locale: 'zh-Hans')!.body,
          '创世记 3');
      expect(at(prog({}), DateTime(2026, 1, 3, 8), locale: 'zh-Hant')!.title,
          '${rpText('readingPlan_bible-1y_name', 'zh-Hant')} · 第 3 天，共 5 天');
    });

    test('each future day carries its own day, not day 1 for ever', () {
      final bodies = [
        for (var i = 0; i < 5; i++)
          at(prog({}), DateTime(2026, 1, 1 + i, 8))!.body
      ];
      expect(bodies, ['Genesis 1', 'Genesis 2', 'Genesis 3', 'Genesis 4', 'Genesis 5']);
    });

    test('silent when there is nothing to say', () {
      expect(at(null, DateTime(2026, 1, 3)), isNull); // no plan chosen
      expect(at(prog({}), DateTime(2025, 12, 30)), isNull); // not started
      expect(at(prog({1, 2, 3, 4, 5}), DateTime(2026, 1, 3)), isNull); // finished
      expect(at(prog({3}), DateTime(2026, 1, 3)), isNull); // that day is read
      expect(at(prog({}), DateTime(2026, 1, 3), pl: null), isNotNull);
      expect(
          readingPlanReminder(
              progress: prog({}), plan: null, fire: DateTime(2026, 1, 3), locale: 'en'),
          isNull); // plan id no longer exists
    });

    test('after the calendar ends, the first unread day is offered', () {
      final r = at(prog({1, 2, 4}), DateTime(2026, 2, 1, 8))!;
      expect(r.title, '${rpText('readingPlan_bible-1y_name', 'en')} · Day 3 of 5');
      expect(r.body, 'Genesis 3');
    });

    test("the reader's own words replace the title; a paused plan is silent", () {
      final p = ReadingPlanProgress(
          planId: 'bible-1y',
          start: DateTime(2026, 1, 1),
          done: const {},
          message: 'Time to read!',
          updatedMs: 1);
      expect(at(p, DateTime(2026, 1, 3, 8))!.title, 'Time to read!');
      expect(at(p, DateTime(2026, 1, 3, 8))!.body, 'Genesis 3');
      expect(at(p.copyWith(pausedOn: DateTime(2026, 1, 2)), DateTime(2026, 1, 3, 8)),
          isNull);
    });

    test('verse windows and several passages read naturally', () {
      final mc = ReadingPlan('m', 2, [
        [
          const ReadingSegment('Exodus', 11, 12, 1, 21),
          const ReadingSegment('Psalms', 119, 119, 1, 24),
        ],
        [const ReadingSegment('Jude', 1, 1)],
      ]);
      final r = readingPlanReminder(
          progress: ReadingPlanProgress(
              planId: 'm', start: DateTime(2026, 1, 1), done: const {}, updatedMs: 1),
          plan: mc,
          fire: DateTime(2026, 1, 1, 8),
          locale: 'en')!;
      expect(r.body, 'Exodus 11:1-12:21 · Psalms 119:1-24');
    });

    test('wired into the category list, scheduler, catch-up and settings', () {
      expect(NotificationCategoryIds.phase1,
          contains(NotificationCategoryIds.readingPlan));
      expect(NotificationCategoryIds.all,
          contains(NotificationCategoryIds.readingPlan));
      final d = NotificationCategoryPrefs.defaultFor(NotificationCategoryIds.readingPlan);
      expect((d.enabled, d.hour, d.minute), (false, 8, 0));
      expect(File('lib/services/notification_scheduler.dart').readAsStringSync(),
          contains('_scheduleReadingPlan'));
      expect(File('lib/services/notification_catchup.dart').readAsStringSync(),
          contains('resolveReadingPlanReminder'));
      expect(File('lib/pages/settings_page.dart').readAsStringSync(),
          contains('NotificationCategoryIds.readingPlan'));
      expect(notificationCategoryLabel(NotificationCategoryIds.readingPlan, 'zh-Hant'),
          '讀經計劃');
    });
  });

  group('sync merge', () {
    String blob(String id, String start, Set<int> done, int ts,
            {String? entryId, bool deleted = false}) =>
        ReadingPlanProgress(
                id: entryId,
                planId: id,
                start: DateTime.parse(start),
                done: done,
                updatedMs: ts,
                deleted: deleted)
            .toJson();

    /// The doc a list of entries makes (what the service stores).
    String doc(List<String> entries, {int cleared = 0, int ts = 1}) =>
        jsonEncode({
          'v': 2,
          'updatedMs': ts,
          if (cleared > 0) 'clearedMs': cleared,
          'plans': entries.map(jsonDecode).toList(),
        });

    List<ReadingPlanProgress> merged(Object? a, Object? b) =>
        ReadingPlansDoc.parse(mergeReadingPlanBlobs(a, b))!.active;

    test('the same plan on two devices: union of days, either order', () {
      final a = blob('bible-1y', '2026-01-01', {1, 2, 3}, 100);
      final b = blob('bible-1y', '2026-01-01', {3, 4}, 200);
      expect(merged(a, b).single.done, {1, 2, 3, 4});
      expect(merged(b, a).single.done, {1, 2, 3, 4});
      expect(merged(a, b).single.updatedMs, 200);
    });

    test('two different plans are both kept; neither replaces the other', () {
      final old = blob('bible-1y', '2026-01-01', {1, 2}, 100);
      final fresh = blob('mcheyne', '2026-02-01', {1}, 200);
      final out = merged(doc([old]), doc([fresh]));
      expect(out.map((e) => e.planId).toSet(), {'bible-1y', 'mcheyne'});
      expect(merged(doc([fresh]), doc([old])).length, 2);
    });

    test('a changed start date or reminder follows the newer edit; reads still union', () {
      final a = ReadingPlanProgress(
          id: 'x', planId: 'bible-1y', start: DateTime(2026, 1, 1),
          done: const {1, 2}, updatedMs: 100, remind: false);
      final b = ReadingPlanProgress(
          id: 'x', planId: 'bible-1y', start: DateTime(2026, 5, 1),
          done: const {2, 3}, updatedMs: 300, remind: true, hour: 7, minute: 30,
          message: 'Go');
      for (final out in [
        merged(doc([a.toJson()]), doc([b.toJson()])).single,
        merged(doc([b.toJson()]), doc([a.toJson()])).single,
      ]) {
        expect(out.start, DateTime(2026, 5, 1));
        expect((out.remind, out.hour, out.minute, out.message), (true, 7, 30, 'Go'));
        expect(out.done, {1, 2, 3});
      }
    });

    test('a removed plan is not brought back by a stale copy', () {
      final live = blob('bible-1y', '2026-01-01', {1}, 100, entryId: 'p1');
      final gone = blob('bible-1y', '2026-01-01', {1}, 200, entryId: 'p1', deleted: true);
      expect(merged(doc([live]), doc([gone])), isEmpty);
      expect(merged(doc([gone]), doc([live])), isEmpty);
      // ...but a copy edited AFTER the removal wins (a deliberate re-add on the same id).
      final back = blob('bible-1y', '2026-01-01', {1, 2}, 300, entryId: 'p1');
      expect(merged(doc([gone]), doc([back])).single.done, {1, 2});
    });

    test('a 1.7.26/27 stop beats an older plan; a newer plan beats an older stop', () {
      final plan = blob('bible-1y', '2026-01-01', {1}, 100);
      final stop = jsonEncode({'planId': '', 'updatedMs': 200});
      expect(merged(plan, stop), isEmpty);
      expect(merged(stop, plan), isEmpty);
      final newer = blob('bible-1y', '2026-01-01', {1}, 300);
      expect(merged(stop, newer).single.done, {1});
    });

    test('a 1.7.26/27 single-plan blob upgrades to one reminding entry', () {
      final legacy = jsonEncode({
        'planId': 'mcheyne',
        'start': '2026-01-01',
        'done': [1, 2],
        'updatedMs': 5,
      });
      final e = ReadingPlansDoc.parse(legacy)!.active.single;
      expect(e.planId, 'mcheyne');
      expect(e.done, {1, 2});
      expect(e.remind, isTrue);
      // two devices that both upgrade it agree on the id, so they merge
      final other = ReadingPlansDoc.parse(jsonEncode({
        'planId': 'mcheyne',
        'start': '2026-01-01',
        'done': [2, 3],
        'updatedMs': 6,
      }))!.active.single;
      expect(other.id, e.id);
      expect(merged(legacy, doc([other.toJson()])).single.done, {1, 2, 3});
    });

    test('one side missing keeps the other; both missing is null', () {
      final a = blob('bible-1y', '2026-01-01', {1}, 100);
      expect(mergeReadingPlanBlobs(a, null), a);
      expect(mergeReadingPlanBlobs(null, a), a);
      expect(mergeReadingPlanBlobs(null, null), isNull);
      expect(ReadingPlansDoc.parse(jsonEncode({'planId': '', 'updatedMs': 1}))!.active,
          isEmpty);
    });

    test('merging is the same from either side', () {
      final x = doc([
        blob('bible-1y', '2026-01-01', {1, 2}, 100, entryId: 'a'),
        blob('mcheyne', '2026-01-05', {4}, 150, entryId: 'b'),
      ]);
      final y = doc([
        blob('bible-1y', '2026-01-01', {2, 9}, 120, entryId: 'a'),
        blob('nt-90', '2026-02-01', {}, 90, entryId: 'c', deleted: true),
      ], cleared: 0, ts: 2);
      expect(mergeReadingPlanBlobs(x, y), mergeReadingPlanBlobs(y, x));
      expect(mergeReadingPlanBlobs(mergeReadingPlanBlobs(x, y), y),
          mergeReadingPlanBlobs(x, y));
    });
  });

  group('wiring', () {
    test('stored under ONE key with no dot (dotted keys broke RTDB sync once)', () {
      expect(kReadingPlanKey, 'readingPlan');
      expect(kReadingPlanKey.contains(RegExp(r'[.#$/\[\]]')), isFalse);
      final sync = File('lib/services/realtime_db_sync_service.dart').readAsStringSync();
      expect(sync, contains("'readingPlan'"));
      for (final path in const [
        'lib/services/cloud_sync_service.dart',
        'lib/services/realtime_db_sync_service.dart',
        'lib/services/reading_plan_service.dart',
      ]) {
        final src = File(path)
            .readAsLinesSync()
            .where((l) => !l.trimLeft().startsWith('//'))
            .join('\n');
        expect(RegExp(r"'plan\.").hasMatch(src), isFalse,
            reason: '$path names a plan.* key');
      }
    });

    test('the deleted v1.2.69 translation keys stay deleted', () {
      const deleted = <String>[
        'tabPlan', 'readingPlans', 'todayReading', 'planDayLabel',
        'planChooseActive', 'planNoActive', 'planActive', 'planStartDate',
        'planUseCalendarDate', 'planUseCalendarDateSub', 'planResetProgress',
        'planResetProgressConfirm', 'planMarkDone', 'planMarkUndone',
        'planJumpToToday', 'planProgress', 'planNone', 'planLibraryEmpty',
        'planHomeHint', 'planHomeHintSub', 'settingsSectionPlan',
        'settingsShowPlanHint', 'onboardPlansTitle', 'onboardPlansBody',
        'dashboardSection_todayReading_label',
        'dashboardSection_todayReading_description',
      ];
      expect(deleted.where(uiStrings.containsKey), isEmpty);
    });

    test('route is registered and the home section is on by default', () {
      expect(kRegisteredRoutePaths, contains(kReadingPlanPath));
      expect(kReadingPlanPath, '/reading-plan');
      expect(defaultVisibility[DashboardSection.readingPlan], isTrue);
      expect(defaultDashboardOrder, contains(DashboardSection.readingPlan));
      expect(normalizeDashboardOrder(['readBible', 'counts']),
          contains(DashboardSection.readingPlan));
    });

    test('the home card shows today as read once it is ticked', () {
      final src = File('lib/pages/dashboard_page.dart').readAsStringSync();
      expect(src, contains("e.done.contains(today)"));
      expect(src, contains("readingPlan_marked"));
    });

    test('every string a plan or the page uses exists in all three languages', () {
      final keys = <String>{
        for (final k in uiStrings.keys)
          if (k.startsWith('readingPlan_') ||
              k.startsWith('dashboardSection_readingPlan_'))
            k,
      };
      for (final p in plans) {
        keys
          ..add('readingPlan_${p.id}_name')
          ..add('readingPlan_${p.id}_desc');
      }
      for (final k in keys) {
        for (final l in const ['en', 'zh-Hans', 'zh-Hant']) {
          expect((uiStrings[k]?[l] ?? '').trim(), isNotEmpty, reason: '$k $l');
        }
        expect(RegExp(r'[㐀-鿿]').hasMatch(uiStrings[k]!['en']!), isFalse,
            reason: '$k en');
        // placeholders must match across languages
        List<String> ph(String s) =>
            (RegExp(r'\{(\w+)\}').allMatches(s).map((m) => m.group(1)!).toList()..sort());
        expect(ph(uiStrings[k]!['zh-Hans']!), ph(uiStrings[k]!['en']!), reason: k);
        expect(ph(uiStrings[k]!['zh-Hant']!), ph(uiStrings[k]!['en']!), reason: k);
      }
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

    Future<ReadingPlanService> mount(WidgetTester tester,
        {String locale = 'en',
        double width = 402,
        double height = 874,
        double scale = 1,
        Object? stored}) async {
      SharedPreferences.setMockInitialValues({
        if (stored != null)
          ProfileService.instance.scopedKey(kReadingPlanKey): stored,
      });
      tester.view.physicalSize = Size(width, height);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final settings = AppSettings();
      await settings.setLocale(locale);
      // AppSettings saves through a 600 ms debounce; let it fire so no
      // timer outlives the test.
      await tester.pump(const Duration(seconds: 1));
      final svc = ReadingPlanService.instance
        ..clock = (() => DateTime(2026, 1, 3, 9))
        ..loader = ((p) async => File(p).readAsString());
      // Real file IO never completes inside the widget-test clock, so
      // plans and progress are loaded BEFORE the page is built; the page
      // then finds them cached and has no spinner left to wait on.
      await tester.runAsync(() async {
        await svc.plans();
        await svc.reload();
      });
      await tester.pumpWidget(ChangeNotifierProvider<AppSettings>.value(
          value: settings,
          child: MaterialApp(
              builder: (c, child) => MediaQuery(
                  data: MediaQuery.of(c).copyWith(
                      textScaler: TextScaler.linear(scale)),
                  child: child!),
              home: ReadingPlanPage(service: svc))));
      await tester.pumpAndSettle();
      return svc;
    }

    for (final width in [320.0, 402.0, 1024.0]) {
      testWidgets('plan picker lays out at $width with 1.6x text', (tester) async {
        await mount(tester, width: width, height: 6000, scale: 1.6);
        expect(find.byKey(const ValueKey('plan.card.mcheyne')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('picker shows English only in English, Chinese in Chinese', (tester) async {
      await mount(tester, locale: 'en', height: 6000);
      final cjk = RegExp(r'[㐀-鿿]');
      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .toList();
      expect(texts.where(cjk.hasMatch), isEmpty);
      await mount(tester, locale: 'zh-Hant', height: 6000);
      expect(find.text('選一個讀經計劃'), findsOneWidget);
      expect(find.textContaining('麥琴'), findsWidgets);
    });

    testWidgets('start a plan from its sheet, see today, tick it, remove it',
        (tester) async {
      final svc = await mount(tester, height: 3000);
      await tester.tap(find.byKey(const ValueKey('plan.start.bible-1y')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('start.confirm')));
      await tester.pumpAndSettle();
      final e = svc.entries.single;
      expect(e.planId, 'bible-1y');
      expect(e.start, DateTime(2026, 1, 3));
      expect(find.byKey(ValueKey('plan.today.${e.id}')), findsOneWidget);
      expect(find.textContaining('Genesis 1-3'), findsWidgets);
      await tester.tap(find.text('Mark as read'));
      await tester.pumpAndSettle();
      expect(svc.entries.single.done, {1});
      expect(find.text('Read'), findsOneWidget);
      // a running plan is not offered again
      expect(find.byKey(const ValueKey('plan.card.bible-1y')), findsNothing);
      await tester.tap(find.byKey(ValueKey('plan.manage.${e.id}')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('manage.remove')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('manage.removeConfirm')));
      await tester.pumpAndSettle();
      expect(svc.entries, isEmpty);
      expect(find.byKey(const ValueKey('plan.card.bible-1y')), findsOneWidget);
    });

    testWidgets('a stored plan opens straight to its day, in Chinese too', (tester) async {
      final stored = ReadingPlanProgress(
              planId: 'mcheyne',
              start: DateTime(2026, 1, 1),
              done: const {1},
              updatedMs: 5)
          .toJson();
      await mount(tester, locale: 'zh-Hans', stored: stored);
      final id = ReadingPlanProgress.legacyId('mcheyne', DateTime(2026, 1, 1));
      expect(find.byKey(ValueKey('plan.today.$id')), findsOneWidget);
      expect(find.textContaining('第 3 天，共 365 天'), findsWidgets);
      expect(find.textContaining('创世记 3'), findsWidgets);
      // behind: day 2 unread
      expect(find.text('落后 1 天'), findsOneWidget);
    });
  });
}
