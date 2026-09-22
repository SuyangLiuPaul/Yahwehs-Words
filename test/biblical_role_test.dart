import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yahwehs_words/utils/biblical_role.dart';

/// `localizedRole()` had zero test coverage (`grep -rn "localizedRole" test/`
/// was empty) despite being reader-visible on two surfaces: the `_RolePill`
/// label in `family_tree_page.dart` and the copy-to-clipboard "Role: …" line
/// in `person_detail_sheet.dart`. Both are fed `settings.locale`, which is
/// assigned with no validation on three paths (`AppSettings.setLocale`,
/// `fromMap`, and the SharedPreferences load — see
/// `lib/models/app_settings.dart:1034,1537,1877`), so an unrecognised `zh-*`
/// tag is reachable. Before the fix, the map's exact-match `'zh-Hans'` /
/// `'zh-Hant'` keys with a `?? role` fallback put raw English
/// ("PRIESTLY TRIBE", "MOTHER OF JESUS") into an otherwise-Chinese UI for a
/// bare `'zh'` or any other `zh-XX` tag — the same failure mode
/// `relative_time.dart`'s `relativeTime()` was fixed for (an unrecognised
/// zh-* tag falling through to English). `lib/utils/font_catalog.dart:61`,
/// `lib/pages/help_page.dart:95` and `lib/widgets/bible_reading_pane.dart`
/// have the same `map[locale] ?? map['en']` shape, still unfixed — see
/// docs/autonomous-queue.md.
///
/// Running this suite against the unfixed helper (`map[role.toUpperCase()]
/// ?[locale] ?? role`), 2 cases went red: `'zh'` and `'zh-XX'` both rendered
/// the raw English role instead of Simplified.
void main() {
  const roles = <String, Map<String, String>>{
    'PATRIARCH': {'zh-Hans': '族长', 'zh-Hant': '族長'},
    'MATRIARCH': {'zh-Hans': '女族长', 'zh-Hant': '女族長'},
    'FIRST MAN': {'zh-Hans': '人类始祖', 'zh-Hant': '人類始祖'},
    'FIRST WOMAN': {'zh-Hans': '人类始母', 'zh-Hant': '人類始母'},
    'PROPHET': {'zh-Hans': '先知', 'zh-Hant': '先知'},
    'PROPHETESS': {'zh-Hans': '女先知', 'zh-Hant': '女先知'},
    'CONCUBINE': {'zh-Hans': '妾', 'zh-Hant': '妾'},
    'WIFE': {'zh-Hans': '妻', 'zh-Hant': '妻'},
    'TRIBE': {'zh-Hans': '支派', 'zh-Hant': '支派'},
    'PRIESTLY TRIBE': {'zh-Hans': '祭司支派', 'zh-Hant': '祭司支派'},
    'ROYAL TRIBE': {'zh-Hans': '王室支派', 'zh-Hant': '王室支派'},
    'HALF-TRIBE': {'zh-Hans': '半支派', 'zh-Hant': '半支派'},
    'DAUGHTER': {'zh-Hans': '女儿', 'zh-Hant': '女兒'},
    'GENTILE': {'zh-Hans': '外邦人', 'zh-Hant': '外邦人'},
    'KING': {'zh-Hans': '王', 'zh-Hant': '王'},
    'QUEEN': {'zh-Hans': '王后', 'zh-Hant': '王后'},
    'GOVERNOR': {'zh-Hans': '省长', 'zh-Hant': '省長'},
    'HIGH PRIEST': {'zh-Hans': '大祭司', 'zh-Hant': '大祭司'},
    'EDOMITES': {'zh-Hans': '以东人', 'zh-Hant': '以東人'},
    'ARABS': {'zh-Hans': '阿拉伯人', 'zh-Hant': '阿拉伯人'},
    'MOABITES': {'zh-Hans': '摩押人', 'zh-Hant': '摩押人'},
    'AMMONITES': {'zh-Hans': '亚扪人', 'zh-Hant': '亞捫人'},
    'MOTHER OF JESUS': {'zh-Hans': '耶稣的母亲', 'zh-Hant': '耶穌的母親'},
    'MESSIAH': {'zh-Hans': '弥赛亚', 'zh-Hant': '彌賽亞'},
    'CARPENTER': {'zh-Hans': '木匠', 'zh-Hant': '木匠'},
  };

  group('all 25 map keys x zh-Hans / zh-Hant / en', () {
    for (final entry in roles.entries) {
      test(entry.key, () {
        expect(localizedRole(entry.key, 'zh-Hans'), entry.value['zh-Hans']);
        expect(localizedRole(entry.key, 'zh-Hant'), entry.value['zh-Hant']);
        expect(localizedRole(entry.key, 'en'), entry.key);
      });
    }
  });

  test('dataset-coverage guard: every distinct role in family_tree.json '
      'has a map entry, so a future dataset addition fails CI instead of '
      'silently shipping raw English to Chinese readers', () {
    final raw = File('assets/family_tree.json').readAsStringSync();
    final data = jsonDecode(raw);
    final datasetRoles = <String>{};
    void walk(dynamic node) {
      if (node is Map) {
        final role = node['role'];
        if (role is String) datasetRoles.add(role);
        for (final v in node.values) {
          walk(v);
        }
      } else if (node is List) {
        for (final v in node) {
          walk(v);
        }
      }
    }

    walk(data);
    expect(datasetRoles, isNotEmpty);
    final unmapped = datasetRoles.difference(roles.keys.toSet());
    expect(unmapped, isEmpty,
        reason: 'dataset role(s) with no localizedRole() map entry: '
            '$unmapped');
  });

  test('unknown role passes through unchanged, for every locale', () {
    for (final locale in ['en', 'zh-Hans', 'zh-Hant', 'zh', 'zh-XX']) {
      expect(localizedRole('SCRIBE', locale), 'SCRIBE');
    }
  });

  test('lowercase / mixed-case input resolves via the existing '
      'toUpperCase()', () {
    expect(localizedRole('king', 'zh-Hans'), '王');
    expect(localizedRole('King', 'zh-Hant'), '王');
  });

  test('empty string in, empty string out', () {
    expect(localizedRole('', 'zh-Hans'), '');
    expect(localizedRole('', 'en'), '');
  });

  group('an unrecognised zh-* locale degrades to Simplified, not English '
      '(the fix)', () {
    test('bare "zh"', () {
      expect(localizedRole('PRIESTLY TRIBE', 'zh'), '祭司支派');
      expect(localizedRole('MOTHER OF JESUS', 'zh'), '耶稣的母亲');
    });

    test('arbitrary "zh-XX"', () {
      expect(localizedRole('PRIESTLY TRIBE', 'zh-XX'), '祭司支派');
      expect(localizedRole('MOTHER OF JESUS', 'zh-XX'), '耶稣的母亲');
    });
  });
}
