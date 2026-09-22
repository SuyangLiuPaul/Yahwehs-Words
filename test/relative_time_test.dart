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
}
