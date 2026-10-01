import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahwehs_words/constants/learning_visibility.dart';

void main() {
  test('Words shows Passion and keeps principles and history hidden', () {
    expect(kShowNewLearningPages, isFalse);
    expect(kShowPassionTimeline, isTrue);
    final dashboard = File('lib/pages/dashboard_page.dart').readAsStringSync();
    final start = dashboard.indexOf('if (kShowNewLearningPages) ...[');
    final end = dashboard.indexOf('\n            ],', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(
        dashboard.substring(0, start), contains('if (kShowPassionTimeline)'));
    expect(dashboard.substring(0, start), contains('PassionWheelPage'));
    expect(
        dashboard.substring(start, end), isNot(contains('PassionWheelPage')));
    expect(end, greaterThan(start));
    final gated = dashboard.substring(start, end);
    for (final page in ['BiblePrinciplesPage', 'WorldHistoryWheelPage']) {
      expect(gated, contains(page));
      expect(dashboard.indexOf('$page()', end), -1);
    }
  });
}
