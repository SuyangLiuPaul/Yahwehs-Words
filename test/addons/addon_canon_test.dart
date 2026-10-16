// The importer's canon is GENERATED (tools/gen_addon_canon.py). These tests
// re-derive it from the app's own sources, so it cannot drift from them.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yahwehs_words/constants/book_name_mapping.dart';
import 'package:yahwehs_words/services/fetch_books.dart' show standardBookOrder;
import 'package:yahwehs_words/utils/addons/addon_canon.dart';

void main() {
  test('the books are the app\'s own 66, in the app\'s own order', () {
    expect(kCanonBooks.length, 66);
    expect(kCanonBooks, standardBookOrder.take(66).toList());
  });

  test('verse counts equal what the bundled KJV actually has', () {
    final rows = json.decode(File('assets/kjv.json').readAsStringSync()) as List;
    final seen = <String, Map<int, int>>{};
    for (final r in rows) {
      final ch = seen.putIfAbsent(r['book'] as String, () => {});
      final c = int.parse('${r['chapter']}');
      final v = int.parse('${r['verse']}');
      if (v > (ch[c] ?? 0)) ch[c] = v;
    }
    for (var b = 0; b < 66; b++) {
      final got = seen[kCanonBooks[b]]!;
      expect([for (var c = 1; c <= got.length; c++) got[c]!], kCanonVerseCounts[b],
          reason: kCanonBooks[b]);
    }
  });

  test('31,102 verses in all — a theWord .ont is exactly that many lines', () {
    final total = kCanonVerseCounts.fold<int>(0, (a, b) => a + b.fold<int>(0, (x, y) => x + y));
    expect(total, 31102);
    final ot = kCanonVerseCounts.take(39).fold<int>(0, (a, b) => a + b.fold<int>(0, (x, y) => x + y));
    expect(ot, 23145);
    expect(total - ot, 7957);
  });

  test('the Chinese names are the app\'s own book names', () {
    for (var i = 0; i < 66; i++) {
      expect(kCanonBooksHans[i], englishToChinese[kCanonBooks[i]], reason: kCanonBooks[i]);
      expect(kCanonBooksHant[i], englishToChineseTraditional[kCanonBooks[i]],
          reason: kCanonBooks[i]);
    }
  });
}
