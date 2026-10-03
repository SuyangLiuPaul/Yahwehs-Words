import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yahwehs_words/utils/app_nav.dart';

/// 2026-10-04 crash (1.7.10, iOS): tapping an illustration map whose id has
/// non-ASCII characters (`illus_dore_gustavedorécrucifixi`) went through
/// Get.toNamed('/maps/<id>'), whose regex never matches such a path, so GetX's
/// `_parseParams` threw "Null check operator used on a null value".
void main() {
  test('ids that GetX cannot route are sent down the anonymous-route branch',
      () {
    expect(isGetRoutable('/maps/illus_dore_gustavedorécrucifixi'), isFalse);
    expect(isGetRoutable('/maps/a b'), isFalse);
    // Percent-encoded ids are routable: songSubPagePath relies on it ('cdc%3Ad0180').
    expect(isGetRoutable('/songs/cdc%3Ad0180/score'), isTrue);
    expect(isGetRoutable('/maps/a#b'), isFalse);
    expect(isGetRoutable('/maps/exodus-route'), isTrue);
    expect(isGetRoutable('/evidence?book=John&chapter=3'), isTrue);
  });

  test('the bundled maps include ids that need the fallback', () {
    final raw = jsonDecode(File('assets/maps_index.json').readAsStringSync());
    final list = raw is List
        ? raw
        : (raw as Map).values.firstWhere((v) => v is List) as List;
    final unroutable = [
      for (final m in list)
        if (!isGetRoutable('/maps/${m['id']}')) m['id']
    ];
    expect(unroutable, isNotEmpty);
  });
}
