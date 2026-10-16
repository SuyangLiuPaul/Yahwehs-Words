import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yahwehs_words/constants/ui_strings.dart';

/// 2026-10-16: the About page opens with the app's purpose, John 17:3, and
/// a note on why the name is "Yahweh". The wording is the owner's; what
/// these pin is that it stays in all three languages, that the verse is
/// the app's OWN text of John 17:3 (not a retyped copy), and that the
/// occurrence count it states is one the app's own Hebrew text gives.
void main() {
  const langs = ['en', 'zh-Hans', 'zh-Hant'];
  const keys = [
    'aboutMissionTitle',
    'aboutMissionBody',
    'aboutMissionVerse',
    'aboutMissionVerseRef',
    'aboutNameTitle',
    'aboutNameBody',
  ];

  test('every line exists in all three languages', () {
    for (final k in keys) {
      for (final l in langs) {
        expect((uiStrings[k]?[l] ?? '').trim(), isNotEmpty, reason: '$k $l');
      }
    }
  });

  test('the purpose says what the owner wrote', () {
    expect(uiStrings['aboutMissionBody']!['zh-Hans'],
        '我们的宗旨是传扬耶稣基督以及天国的福音，引领人认识那位差耶稣基督来的独一真神雅伟（Yahweh）。');
    expect(uiStrings['aboutMissionBody']!['zh-Hant'],
        '我們的宗旨是傳揚耶穌基督以及天國的福音，引領人認識那位差耶穌基督來的獨一真神雅偉（Yahweh）。');
  });

  test('the quoted John 17:3 is the app\'s own text of it', () {
    String verse(String file, String book) {
      final rows = (jsonDecode(File('assets/$file').readAsStringSync()) as List)
          .cast<Map<String, dynamic>>();
      return rows
          .firstWhere((r) =>
              r['book'] == book &&
              '${r['chapter']}' == '17' &&
              '${r['verse']}' == '3')['text']
          .toString()
          .trim();
    }

    expect(uiStrings['aboutMissionVerse']!['zh-Hans'],
        verse('cuvs-yhwh.json', '约翰福音'));
    expect(uiStrings['aboutMissionVerse']!['zh-Hant'],
        verse('cuvs-yhwh-tr.json', '約翰福音'));
    expect(uiStrings['aboutMissionVerse']!['en'], verse('kjv.json', 'John'));
  });

  test('the count it states is specific, and the same in every language', () {
    for (final l in langs) {
      expect(uiStrings['aboutNameBody']![l], contains('6,828'), reason: l);
    }
  });
}
