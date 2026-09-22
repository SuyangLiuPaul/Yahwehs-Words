import 'package:flutter_test/flutter_test.dart';
import 'package:yahwehs_words/utils/relative_time.dart';

/// `relativeTime()` had zero test coverage despite its own docstring
/// claiming "locale-aware, with zh-Hans / zh-Hant / en". The code actually
/// branched on `locale.startsWith('zh')`, so a zh-Hant reader (e.g. the
/// "Edited 5 分钟前" tag in library_page.dart, or the recent-search rows in
/// search_page.dart) got Simplified glyphs — the same class of bug fixed
/// for shortBookName() in c6a1d393 (UI copy following the UI locale's
/// *language* instead of its *script*).
void main() {
  DateTime ago(Duration d) => DateTime.now().toUtc().subtract(d);

  group('just now (< 30s) and clock-skew futures', () {
    test('en', () => expect(relativeTime(ago(const Duration(seconds: 5)), 'en'), 'just now'));
    test('zh-Hans', () => expect(relativeTime(ago(const Duration(seconds: 5)), 'zh-Hans'), '刚刚'));
    test('zh-Hant', () => expect(relativeTime(ago(const Duration(seconds: 5)), 'zh-Hant'), '剛剛'));

    test('negative diff (future timestamp) clamps to just now', () {
      final future = DateTime.now().toUtc().add(const Duration(seconds: 3));
      expect(relativeTime(future, 'en'), 'just now');
      expect(relativeTime(future, 'zh-Hans'), '刚刚');
      expect(relativeTime(future, 'zh-Hant'), '剛剛');
    });
  });

  group('less than a minute (30s-60s)', () {
    test('en', () => expect(relativeTime(ago(const Duration(seconds: 45)), 'en'), 'less than a minute ago'));
    test('zh-Hans', () => expect(relativeTime(ago(const Duration(seconds: 45)), 'zh-Hans'), '不到一分钟前'));
    test('zh-Hant', () => expect(relativeTime(ago(const Duration(seconds: 45)), 'zh-Hant'), '不到一分鐘前'));
  });

  group('minutes (1-59)', () {
    test('en singular', () => expect(relativeTime(ago(const Duration(minutes: 1)), 'en'), '1 minute ago'));
    test('en plural', () => expect(relativeTime(ago(const Duration(minutes: 5)), 'en'), '5 minutes ago'));
    test('zh-Hans', () => expect(relativeTime(ago(const Duration(minutes: 5)), 'zh-Hans'), '5 分钟前'));
    test('zh-Hant', () => expect(relativeTime(ago(const Duration(minutes: 5)), 'zh-Hant'), '5 分鐘前'));
  });

  group('hours (1-23)', () {
    test('en singular', () => expect(relativeTime(ago(const Duration(hours: 1)), 'en'), '1 hour ago'));
    test('en plural', () => expect(relativeTime(ago(const Duration(hours: 3)), 'en'), '3 hours ago'));
    test('zh-Hans', () => expect(relativeTime(ago(const Duration(hours: 3)), 'zh-Hans'), '3 小时前'));
    test('zh-Hant', () => expect(relativeTime(ago(const Duration(hours: 3)), 'zh-Hant'), '3 小時前'));
  });

  group('days (>= 24h)', () {
    test('en singular', () => expect(relativeTime(ago(const Duration(days: 1)), 'en'), '1 day ago'));
    test('en plural', () => expect(relativeTime(ago(const Duration(days: 2)), 'en'), '2 days ago'));
    // 天/前 are the same glyphs in both scripts, so zh-Hans and zh-Hant
    // share the same expected string in this bucket.
    test('zh-Hans', () => expect(relativeTime(ago(const Duration(days: 2)), 'zh-Hans'), '2 天前'));
    test('zh-Hant', () => expect(relativeTime(ago(const Duration(days: 2)), 'zh-Hant'), '2 天前'));
  });

  test('an unrecognised zh-* tag (e.g. from an unvalidated imported '
      'settings blob) degrades to Simplified rather than English', () {
    expect(relativeTime(ago(const Duration(minutes: 5)), 'zh-XX'), '5 分钟前');
  });

  group('relativeDay() — reading_stats_page.dart\'s day-granularity '
      'formatter, moved here 2026-09-22 so it stops re-duplicating the '
      'locale.startsWith("zh") branching above', () {
    final now = DateTime(2026, 9, 22, 8, 0); // a fixed local "now"

    test('same calendar day, earlier that day', () {
      final at = DateTime(2026, 9, 22, 6, 0);
      expect(relativeDay(at, 'en', now: now), 'Today');
      expect(relativeDay(at, 'zh-Hans', now: now), '今天');
      expect(relativeDay(at, 'zh-Hant', now: now), '今天');
    });

    test('calendar-day fix: opened late the previous night, elapsed '
        '< 24h, still calendar "yesterday" — DateTime.difference().inDays '
        'would have rounded this down to 0 ("Today"), which is the bug '
        'this move fixes, not just relocates', () {
      final at = DateTime(2026, 9, 21, 23, 30); // 8.5h before `now`
      expect(relativeDay(at, 'en', now: now), 'Yesterday');
      expect(relativeDay(at, 'zh-Hans', now: now), '昨天');
    });

    test('previous calendar day, but more than 24h elapsed', () {
      final at = DateTime(2026, 9, 21, 6, 0);
      expect(relativeDay(at, 'en', now: now), 'Yesterday');
      expect(relativeDay(at, 'zh-Hans', now: now), '昨天');
    });

    test('2 calendar days back', () {
      final at = DateTime(2026, 9, 20, 6, 0);
      expect(relativeDay(at, 'en', now: now), '2 days ago');
      expect(relativeDay(at, 'zh-Hans', now: now), '2 天前');
      expect(relativeDay(at, 'zh-Hant', now: now), '2 天前');
    });

    test('DST fix: 2 calendar days apart stays "2 days ago" even '
        'spanning a spring-forward (23h) day — a refuter for this queue '
        'item caught that comparing two LOCAL midnights via '
        '`DateTime(y,m,d).difference(...).inDays` breaks here: on a '
        '23-hour local day, two midnights 2 calendar days apart are only '
        '47 elapsed hours, which Duration.inDays truncates to 1, '
        'misreporting "Yesterday". relativeDay() avoids this by comparing '
        'DateTime.utc(y,m,d) built from the same y/m/d fields, which has '
        'no DST and is always an exact 24h multiple apart — so this test '
        'passes on any host regardless of that host\'s own timezone/DST '
        'rules, which is the point of the fix.', () {
      final sydneySpringForward = DateTime(2026, 10, 5, 0, 0);
      final beforeTransition = DateTime(2026, 10, 3, 0, 0);
      expect(relativeDay(beforeTransition, 'en', now: sydneySpringForward),
          '2 days ago');
      expect(relativeDay(beforeTransition, 'zh-Hans', now: sydneySpringForward),
          '2 天前');
    });

    test('29 calendar days back is still the "N days ago" bucket', () {
      final at = now.subtract(const Duration(days: 29));
      expect(relativeDay(at, 'en', now: now), '29 days ago');
      expect(relativeDay(at, 'zh-Hans', now: now), '29 天前');
    });

    test('30 calendar days back falls to an ISO date', () {
      final at = now.subtract(const Duration(days: 30));
      expect(relativeDay(at, 'en', now: now), isoDate(at));
      expect(relativeDay(at, 'zh-Hans', now: now), isoDate(at));
    });

    test('clock-skew future timestamp still reads as "today", via the '
        'days <= 0 branch', () {
      final at = DateTime(2026, 9, 22, 9, 0); // 1h after `now`
      expect(relativeDay(at, 'en', now: now), 'Today');
      expect(relativeDay(at, 'zh-Hans', now: now), '今天');
    });

    test('an unrecognised zh-* tag degrades to Simplified, same as '
        'relativeTime()', () {
      final at = DateTime(2026, 9, 20, 6, 0);
      expect(relativeDay(at, 'zh-XX', now: now), '2 天前');
    });

    test('with no explicit `now`, defaults to the real clock', () {
      final at = DateTime.now();
      expect(relativeDay(at, 'en'), 'Today');
    });
  });

  group('isoDate()', () {
    test('zero-pads single-digit month and day', () {
      expect(isoDate(DateTime(2026, 1, 5)), '2026-01-05');
    });

    test('no padding needed', () {
      expect(isoDate(DateTime(2026, 12, 25)), '2026-12-25');
    });
  });
}
