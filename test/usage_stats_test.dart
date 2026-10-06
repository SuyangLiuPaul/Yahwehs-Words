import 'package:flutter_test/flutter_test.dart';
import 'package:yahwehs_words/services/usage_stats.dart';

void main() {
  test('page keys are first-segment, db-safe and bounded', () {
    expect(UsageStats.pageKey('/sermons/004'), 'sermons');
    expect(UsageStats.pageKey('/study/principles'), 'study');
    expect(UsageStats.pageKey('/SongsPage'), 'songspage');
    expect(UsageStats.pageKey('/'), 'home');
    expect(UsageStats.pageKey('/a.b#c[d]\$e'), 'abcde');
    expect(UsageStats.pageKey('/${'x' * 80}').length, 32);
  });

  test('day key is UTC', () {
    expect(UsageStats.dayKey(DateTime.utc(2026, 10, 6, 23, 59)), '2026-10-06');
    expect(UsageStats.dayKey(DateTime.parse('2026-10-06T23:00:00-05:00')), '2026-10-07');
  });

  test('the body carries only counters and the day — nothing identifying', () {
    final b = UsageStats.body(session: true, page: '/songs');
    expect(b.keys.toSet(), {'day', 'pv', 'sessions', 'pages/songs', 'apps/words'});
    expect((b['pv']! as Map)['.sv'], {'increment': 1});
  });

  test('disabled means nothing is sent; a seam receives the body', () async {
    final sent = <String>[];
    UsageStats.enabled = false;
    UsageStats.page('/x'); // no sender, disabled: silent
    UsageStats.sender = (day, body) async => sent.add(day);
    UsageStats.page('/songs');
    await Future<void>.delayed(Duration.zero);
    UsageStats.sender = null;
    expect(sent.length, 1);
  });
}
