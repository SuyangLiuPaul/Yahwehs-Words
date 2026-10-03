import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `assets/bible_evidence.json` held 830 `zh-Hant` fields that were never
/// converted and still carried wholly Simplified prose — 32,638 Simplified
/// character occurrences across 785 distinct code points, printed to
/// Traditional readers because nothing in `lib/` converts at render time.
///
/// Converted 2026-09-03 by `tools/repair_untranslated_hant.py` with
/// `opencc -c s2tw` (the glyph layer only) plus an enumerated table of 50
/// corrections to opencc's own one-to-many mistakes, and 12 repairs to damage
/// that was already live in the *converted* portion of the file.
///
/// The counts below are the work order. If one moves, the asset was
/// re-imported or swept — re-read the tool's `--review` output rather than
/// adjusting a number here.
void main() {
  late List<Map<String, dynamic>> locales;
  late String hant;
  late List<dynamic> evidences;

  /// Every dict carrying a zh-Hant/zh-Hans pair, at any depth.
  void walk(dynamic node, void Function(Map<String, dynamic>) visit) {
    if (node is Map<String, dynamic>) {
      if (node['zh-Hant'] is String && node['zh-Hans'] is String) visit(node);
      for (final v in node.values) {
        walk(v, visit);
      }
    } else if (node is List) {
      for (final v in node) {
        walk(v, visit);
      }
    }
  }

  setUpAll(() {
    final doc = json.decode(
        File('assets/bible_evidence.json').readAsStringSync())
        as Map<String, dynamic>;
    evidences = doc['evidences'] as List;
    locales = [];
    walk(doc, (m) {
      if ((m['zh-Hant'] as String).isNotEmpty) locales.add(m);
    });
    hant = locales.map((m) => m['zh-Hant'] as String).join('\n');
  });

  int count(String needle) => needle.allMatches(hant).length;

  test('the asset still has the shape the repair was measured against', () {
    expect(evidences.length, 225);
    expect(locales.length, 1575);
  });

  test('no zh-Hant field holds Simplified-only characters', () {
    // The 40 most frequent of the 785 that were present before the repair,
    // covering 20,000+ of the 32,638 occurrences. Every one of these is
    // Simplified with no Traditional use, so a single hit means a field went
    // back to Simplified — or a new entry was imported unconverted.
    const simplifiedOnly = '记为亚圣约证这与经纪现学实书时马确罗载来对犹个传历尔们统认将'
        '发师县节该权语义题继';
    final found = <String, int>{};
    for (final ch in simplifiedOnly.split('')) {
      final n = count(ch);
      if (n > 0) found[ch] = n;
    }
    expect(found, isEmpty,
        reason: 'Simplified characters are printing to Traditional readers '
            'again: $found. Re-run tools/repair_untranslated_hant.py.');
  });

  test('opencc s2tw one-to-many mistakes stay corrected', () {
    // Transliterated names where 里 is a syllable, not a container.
    for (final wrong in const [
      '馬裡', '泰勒裡', '瑪裡', '胡裡', '古裡', '弗裡', '努外裡',
      '加布裡', '哈塔裡', '艾茲裡',
    ]) {
      expect(count(wrong), 0, reason: '$wrong — 里 in a name became 裡');
    }
    expect(count('馬里'), 14);
    expect(count('瑪里卜'), 4);

    // 发 is 發 (issue/discover/publish) here, not 髮 (hair).
    expect(count('被髮'), 0);
    expect(count('騷亂髮'), 0);
    expect(count('包括髮'), 0);
    // 6 -> 7 on 2026-10-04: one more correct 被發掘 in the new Pool of Siloam / Jericho text.
    expect(count('被發掘'), 6);  // 7 -> 6 on 2026-10-04 (Transfiguration paragraph rewritten)
    // …but the two real ones are hair and must NOT have been swept.
    expect(count('頭髮'), 1, reason: 'the hair in Daniel 4:33 was swept away');
    expect(count('髮型'), 1, reason: 'the mushroom hairstyle was swept away');

    expect(count('覆活'), 0);
    // 43 -> 42 on 2026-10-04: the Hezekiah bulla text no longer calls a (not present) scarab a
    // 'symbol of resurrection' (tools/apply_evidence_corrections.py).
    expect(count('復活'), 42);
    // 覆 is correct in these and a widened 覆→復 rule would break them.
    expect(count('反覆'), greaterThan(0));
    expect(count('覆蓋'), greaterThan(0));
    expect(count('覆滅'), 1, reason: 'Jehu overthrowing the house of Omri');
    expect(count('覆文'), 1, reason: 'the imperial rescript');

    // A wadi is a 乾河谷; 幹 is correct in 樹幹 and 主幹道.
    expect(count('幹河谷'), 0);
    expect(count('乾河谷'), 2);
    expect(count('樹幹'), 2);
    expect(count('主幹道'), 3);

    expect(count('石制'), 0);
    expect(count('石製'), 4);
    expect(count('羊皮捲'), 0);
    expect(count('羊皮卷'), 1);
    expect(count('爐灶'), 0);
    expect(count('爐竈'), 1);
  });

  test('the s2twp damage already live in the converted fields is repaired',
      () {
    // Istanbul, wrecked by s2twp's 布爾→布林 rule, which exists for "Boolean".
    expect(count('伊斯坦布林'), 0,
        reason: 'Istanbul is spelled "Boolean" again');
    expect(count('伊斯坦布爾'), 7);

    // 保存 (preserved) had been turned into 儲存 (stored) in five manuscript
    // descriptions. The nine remaining 儲存 are the real word — each one's
    // zh-Hans twin reads 储存 (grain jars, seed reserves, a storeroom) — so
    // this is a partition, not a sweep, and both sides are pinned.
    expect(count('抄本儲存'), 0);
    // 2 were already spelled 保存 before the repair; 3 were restored to it.
    expect(count('抄本保存'), 5);
    expect(count('儲存'), 9);
    // 83 -> 82 on 2026-10-04: the rewritten Thallus/Rylands/Nazareth paragraphs (tools/apply_evidence_corrections.py).
    expect(count('保存'), 81);  // 82 -> 81 on 2026-10-04 (Golgotha / house of Peter rewrite)
  });

  test('wording was not localised — only glyphs were converted', () {
    // s2twp would also have rewritten these. Converting a glyph is not
    // rewriting; changing a word is, and this file is the Simplified source's
    // wording throughout.
    // 525 -> 533 on 2026-10-04: net effect of the content corrections in
    // tools/apply_evidence_corrections.py (Tall el-Hammam, Isaiah bulla, James ossuary,
    // Ketef Hinnom, Khirbet Qeiyafa, Pool of Siloam, Jericho, Caiaphas, P52, Thallus,
    // Nazareth Inscription, Sodom and Gomorrah: 533 -> 531), which rewrote paragraphs containing 公元.
    expect(count('公元'), 538,  // 531 -> 538 on 2026-10-04 (Golgotha, house of Peter, Capernaum, Transfiguration)
         reason: '公元 was localised to 西元');
    expect(count('西元'), 288, reason: 'the file\'s own 西元 were disturbed');
    expect(count('意大利'), 8);
    expect(count('聯絡'), 0, reason: '聯繫 was localised to 聯絡');
    expect(count('法律檔案'), 0, reason: '法律文件 was localised');
  });
}
