// Corrections to bible_evidence.json brought over from Yahweh's Sword,
// 2026-09-21, after a side-by-side of the two apps. Pinned so a
// regeneration of the asset cannot quietly bring the old text back.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String all;
  late Map<String, dynamic> byId;

  setUpAll(() {
    final doc = json.decode(File('assets/bible_evidence.json')
        .readAsStringSync()) as Map<String, dynamic>;
    final entries =
        (doc['evidences'] as List).cast<Map<String, dynamic>>();
    byId = {for (final e in entries) e['id'] as String: e};
    // The entries only. `_meta` records this correction and quotes the
    // old forms by name, which is what a note about it should do.
    all = json.encode(entries);
  });

  test('the Tel Dan Stele is named for Tel Dan, not for Daniel', () {
    final title = byId['tel_dan_stele']!['title'] as Map<String, dynamic>;
    expect(title['zh-Hans'], '但丘石碑');
    expect(title['zh-Hant'], '但丘石碑');
    expect(all, isNot(contains('但以理石碑')));
  });

  test('an ossuary holds bones, not ashes', () {
    // First-century Jews did not cremate. 藏骨罐 / 骸骨箱 are the terms
    // this file already used everywhere else.
    for (final ash in ['骨灰罐', '骨灰盒']) {
      expect(all, isNot(contains(ash)), reason: ash);
    }
    final caiaphas =
        byId['caiaphas_ossuary']!['title'] as Map<String, dynamic>;
    expect(caiaphas['zh-Hans'], contains('藏骨罐'));
  });

  test('no academic source is mojibake', () {
    // UTF-8 read as Latin-1: é became Ã©, ö became Ã¶.
    expect(all, isNot(contains('Ã')), reason: 'e.g. "AmÃ©lie" for "Amélie"');
    final cyrus = byId['cyrus_cylinder']!['academicSources'] as List;
    expect(cyrus.join(), contains('Amélie'));
  });
}
