// 2026-10-03 圣经证据 audit: scripture quoted inside assets/bible_evidence.json
// must be the wording of an edition the app ships. tools/fix_evidence_quotes.py
// replaced 46 English (NIV wording) and 21 Chinese quotes with exact spans from
// bsb-yhwh / cuvs-yhwh; this keeps the corrected ones from regressing and keeps
// hazor_destruction's English paragraphs as one string like every other field.

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, Map<String, dynamic>> byId;
  setUpAll(() async {
    final raw = jsonDecode(await rootBundle.loadString('assets/bible_evidence.json'))
        as Map<String, dynamic>;
    byId = {
      for (final e in raw['evidences'] as List)
        (e as Map<String, dynamic>)['id'] as String: e,
    };
  });

  String field(String id, String f, String lang) =>
      ((byId[id]![f] as Map)[lang]) as String;

  test('Isaiah 40:8 is quoted as 和合本 has it (凋残, not 凋谢)', () {
    final z = field('dead_sea_scrolls', 'scripturalCorrelation', 'zh-Hans');
    expect(z, contains('花必凋残'));
    expect(z, isNot(contains('花必凋谢')));
  });

  test('English quotes use the app\'s Yahweh wording, not NIV', () {
    final t = field('elisha_miracles_dothan', 'scripturalCorrelation', 'en');
    expect(t, contains('O Yahweh, please open his eyes'));
    expect(t, isNot(contains('O LORD, please open his eyes')));
  });

  test('English text fields are strings, hazor included', () {
    for (final f in ['description', 'scripturalCorrelation']) {
      expect((byId['hazor_destruction']![f] as Map)['en'], isA<String>());
    }
  });
}
