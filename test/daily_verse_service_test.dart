import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';

import 'package:yahwehs_words/services/daily_verse_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late int poolSize;

  setUpAll(() async {
    final raw = await rootBundle.loadString('assets/daily_verses.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    poolSize = (json['verses'] as List).length;
  });

  group('todayRef', () {
    test('pool size is 3650 as documented', () {
      expect(poolSize, 3650);
    });

    // v1.3.2 regression guard: the previous formula was
    // `dayOfYear % list.length`, which only ever reached indices
    // 0..365 of the 3650-entry pool because dayOfYear never exceeds
    // 365. Walking a full 3650-day cycle from the epoch must reach
    // every entry exactly once, or that bug is back.
    //
    // Dates are enumerated via a UTC cursor (no DST) purely to derive
    // clean y/m/d components, then fed to todayRef as a freshly
    // constructed *local* DateTime(y, m, d) — the same shape a real
    // `DateTime.now()` call produces. Stepping the *local* epoch by
    // `Duration(days: i)` instead (tried first) is NOT equivalent: on
    // this machine's Australia/Melbourne zone it silently collapses
    // one day per year onto the previous day's local midnight across
    // the April DST transition (24 real hours from a DST-still-in-
    // effect midnight lands at 23:00, not 00:00, the next local day),
    // losing 10 of 3650 entries to a false collision that todayRef
    // itself never produces for real calendar dates.
    test('every entry in the pool is reachable exactly once across '
        '3650 consecutive days from the epoch', () async {
      final seen = <String>{};
      final refs = <String>[];
      var utcCursor = DateTime.utc(2026, 1, 1);
      for (int i = 0; i < poolSize; i++) {
        final local = DateTime(utcCursor.year, utcCursor.month, utcCursor.day);
        final ref = await DailyVerseService.todayRef(now: local);
        expect(ref, isNotNull);
        refs.add(ref!);
        seen.add(ref);
        utcCursor = utcCursor.add(const Duration(days: 1));
      }
      expect(seen.length, poolSize,
          reason: 'every day in a full cycle must land on a distinct '
              'verse; a repeat means the rotation is not covering the '
              'whole pool');
      expect(refs.length, poolSize);
    });

    test('a given date always maps to the same ref (determinism)', () async {
      final date = DateTime(2026, 6, 15);
      final first = await DailyVerseService.todayRef(now: date);
      final second = await DailyVerseService.todayRef(now: date);
      expect(first, isNotNull);
      expect(second, first);
      // Pinned by running the fixed-seed (20260506) Fisher-Yates shuffle
      // over the current assets/daily_verses.json and reading index 165
      // (2026-06-15 is 165 days after the 2026-01-01 epoch). If this
      // legitimately changes, it means either the epoch, the seed, or
      // the source verse list moved — re-measure, don't just update the
      // literal to make the test pass.
      expect(first, 'Isaiah 10:24');
    });

    test('calendar-day boundary: 00:00 and 23:59 on the same local day '
        'give the same ref', () async {
      final morning = DateTime(2026, 3, 10, 0, 0);
      final night = DateTime(2026, 3, 10, 23, 59);
      final refMorning = await DailyVerseService.todayRef(now: morning);
      final refNight = await DailyVerseService.todayRef(now: night);
      expect(refMorning, isNotNull);
      expect(refNight, refMorning);
    });

    test('a date before the epoch still resolves to a non-null ref '
        '(mathematical-modulo wraparound)', () async {
      final ref = await DailyVerseService.todayRef(now: DateTime(2025, 12, 31));
      expect(ref, isNotNull);
    });

    test('two adjacent dates before the epoch give different refs '
        '(wraparound is not collapsing everything to one index)', () async {
      final refA = await DailyVerseService.todayRef(now: DateTime(2025, 12, 30));
      final refB = await DailyVerseService.todayRef(now: DateTime(2025, 12, 31));
      expect(refA, isNotNull);
      expect(refB, isNotNull);
      expect(refA, isNot(refB));
    });
  });

  group('recentRefs', () {
    test('single-entry request matches todayRef for the same date', () async {
      final date = DateTime(2026, 7, 4);
      final today = await DailyVerseService.todayRef(now: date);
      final recent = await DailyVerseService.recentRefs(1, now: date);
      expect(recent, hasLength(1));
      expect(recent.single.ref, today);
      expect(recent.single.date, DateTime(2026, 7, 4));
    });

    test('is newest-first with dates strictly descending by one day',
        () async {
      final date = DateTime(2026, 8, 20);
      final recent = await DailyVerseService.recentRefs(5, now: date);
      expect(recent, hasLength(5));
      for (int i = 0; i < recent.length; i++) {
        expect(recent[i].date, date.subtract(Duration(days: i)));
      }
      for (int i = 1; i < recent.length; i++) {
        expect(
            recent[i - 1].date.difference(recent[i].date), const Duration(days: 1));
      }
    });

    test('n above the pool size clamps to the pool size', () async {
      final recent =
          await DailyVerseService.recentRefs(poolSize + 100, now: DateTime(2026, 1, 1));
      expect(recent, hasLength(poolSize));
    });

    // Documented as "Always at most [n] entries", but `n.clamp(1, …)`
    // means recentRefs(0) actually returns one entry, not zero. Pinning
    // the measured behaviour here, not the docstring's claim.
    test('recentRefs(0) returns one entry, not zero (clamp floor is 1)',
        () async {
      final recent = await DailyVerseService.recentRefs(0, now: DateTime(2026, 1, 1));
      expect(recent, hasLength(1));
    });

    test('a negative n also clamps to one entry', () async {
      final recent = await DailyVerseService.recentRefs(-5, now: DateTime(2026, 1, 1));
      expect(recent, hasLength(1));
    });
  });
}
