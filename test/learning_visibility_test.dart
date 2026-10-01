import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahwehs_words/constants/learning_visibility.dart';

void main() {
  test('all three new Words learning entries are hidden by owner choice', () {
    expect(kShowNewLearningPages, isFalse);
    final dashboard = File('lib/pages/dashboard_page.dart').readAsStringSync();
    final start = dashboard.indexOf('if (kShowNewLearningPages) ...[');
    final end = dashboard.indexOf('\n            ],', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final gated = dashboard.substring(start, end);
    for (final page in [
      'PassionWheelPage',
      'BiblePrinciplesPage',
      'WorldHistoryWheelPage'
    ]) {
      expect(gated, contains(page));
      expect(dashboard.indexOf('$page()', end), -1);
    }
  });
}
