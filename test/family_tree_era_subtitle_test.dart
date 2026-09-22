import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yahwehs_words/constants/ui_strings.dart';
import 'package:yahwehs_words/pages/family_tree_page.dart' show eraLabel;

/// `_eraSubtitle()` (`lib/pages/family_tree_page.dart:2193`) prints a hand-
/// typed date range under each era header, pulled from `uiStrings`. Nothing
/// checked those ranges against the people `assets/family_tree.json` actually
/// files under that era — five of the nine had drifted (wrong century, wrong
/// unit, or a range built from the wrong person) before this test existed.
/// This test recomputes each era's min/max independently from the raw asset
/// (never from the subtitle strings themselves) and asserts the two agree,
/// in all three locales.
///
/// Same asset, second question: `eraLabel()`'s antediluvian entry names an
/// endpoint pair — "(Adam → Lamech)" — that a reader could reasonably expect
/// to be the two people bounding that era. This test checks that whichever
/// people an `eraLabel` names in that `(X → Y)` form really are tagged with
/// that era, rather than assuming the parenthetical is decorative.
/// AM 0 as a BC year. 4114 since 2026-09-21, when Words took Yahweh's
/// Sword's chronology, where it is derived: Abram's birth is 2166 BC by
/// 1 Kings 6:1 and Exodus 12:40 counted back from Solomon's temple, and
/// AM 1948 by Genesis 5 and 11. It was Ussher's 4004 before — and the
/// era subtitles only matched while this test carried the same wrong
/// constant as they did. `tools/build_bible_chronology.py` CREATION_BC.
const _anchor = 4114;

void main() {
  late List<Map<String, dynamic>> people;
  late Map<String, List<Map<String, dynamic>>> byEra;

  setUpAll(() {
    final data =
        json.decode(File('assets/family_tree.json').readAsStringSync())
            as Map;
    people = (data['people'] as List).cast<Map<String, dynamic>>();
    byEra = {};
    for (final p in people) {
      final era = p['era'] as String;
      byEra.putIfAbsent(era, () => []).add(p);
    }
  });

  /// AM (Anno Mundi) and BC/AD share one signed timeline here: AM counts up
  /// from Creation, so `am - _anchor` lands on the same line as the `bc`
  /// system's own numbers, where negative = BC and positive = AD (no
  /// year-zero gap; matches how `bible_chronology.json`'s AM→BC anchor and
  /// this asset's own `bc`-system entries, e.g. `joseph_father_of_jesus`
  /// birth -30 / death 18, are already stored).
  int signed(int year, String system) => system == 'am' ? year - _anchor : year;

  /// Earliest (most negative/most ancient) and latest signed year among an
  /// era's people, counting both `birthYear` and any non-null `deathYear`.
  (int min, int max) signedRange(String era) {
    final events = <int>[];
    for (final p in byEra[era]!) {
      final system = p['yearSystem'] as String;
      events.add(signed(p['birthYear'] as int, system));
      final death = p['deathYear'] as int?;
      if (death != null) events.add(signed(death, system));
    }
    events.sort();
    return (events.first, events.last);
  }

  /// The digit runs a subtitle string contains, in reading order — e.g.
  /// `~BC 2948 – 1817` -> `[2948, 1817]`. Comparing digit runs (rather than
  /// the whole sentence) means the test is not tied to English wording or
  /// to how the Chinese locales phrase the same range.
  List<int> digitsIn(String key, String locale) {
    final text = uiStrings[key]?[locale] ?? '';
    return RegExp(r'\d+')
        .allMatches(text)
        .map((m) => int.parse(m.group(0)!))
        .toList();
  }

  group('era subtitle date ranges match the asset they describe', () {
    test('antediluvian: AM range matches Adam..Methuselah\'s death', () {
      final (min, max) = signedRange('antediluvian');
      // Antediluvian people are all yearSystem 'am'; converting the signed
      // range back to raw AM numbers is what the subtitle displays.
      final expected = [min + _anchor, max + _anchor];
      for (final locale in ['en', 'zh-Hans', 'zh-Hant']) {
        expect(digitsIn('familyTreeEraSubAntediluvian', locale), expected,
            reason: 'locale $locale');
      }
    });

    test('post_flood: BC range matches Noah\'s birth..Eber\'s death', () {
      final (min, max) = signedRange('post_flood');
      expect(min, lessThan(0), reason: 'expected a BC-side minimum');
      expect(max, lessThan(0), reason: 'expected a BC-side maximum');
      final expected = [-min, -max];
      for (final locale in ['en', 'zh-Hans', 'zh-Hant']) {
        expect(digitsIn('familyTreeEraSubPostFlood', locale), expected,
            reason: 'locale $locale');
      }
    });

    test('mosaic: BC range matches Kohath\'s birth..Moses\' death', () {
      final (min, max) = signedRange('mosaic');
      expect(min, lessThan(0));
      expect(max, lessThan(0));
      final expected = [-min, -max];
      for (final locale in ['en', 'zh-Hans', 'zh-Hant']) {
        expect(digitsIn('familyTreeEraSubMosaic', locale), expected,
            reason: 'locale $locale');
      }
    });

    test(
        'davidic_line: BC range matches Perez\'s birth..Ish-bosheth\'s '
        'death', () {
      final (min, max) = signedRange('davidic_line');
      expect(min, lessThan(0));
      expect(max, lessThan(0));
      final expected = [-min, -max];
      for (final locale in ['en', 'zh-Hans', 'zh-Hant']) {
        expect(digitsIn('familyTreeEraSubDavidic', locale), expected,
            reason: 'locale $locale');
      }
    });

    test('kings: BC range matches Bathsheba\'s birth..Jeconiah\'s death', () {
      final (min, max) = signedRange('kings');
      expect(min, lessThan(0));
      expect(max, lessThan(0));
      final expected = [-min, -max];
      for (final locale in ['en', 'zh-Hans', 'zh-Hant']) {
        expect(digitsIn('familyTreeEraSubKings', locale), expected,
            reason: 'locale $locale');
      }
    });

    test(
        'nt: range matches Joseph\'s BC birth..Mary\'s AD death, not a '
        'BC-only span', () {
      final (min, max) = signedRange('nt');
      expect(min, lessThan(0), reason: 'expected a BC-side minimum');
      expect(max, greaterThan(0), reason: 'expected an AD-side maximum');
      final expected = [-min, max];
      for (final locale in ['en', 'zh-Hans', 'zh-Hant']) {
        expect(digitsIn('familyTreeEraSubNt', locale), expected,
            reason: 'locale $locale');
      }
    });

    // exile and lukan_lineage print no numeric range (their subtitles cite
    // a verse instead), and patriarchs already carried a correct, rounded
    // range before this slice — none of the three changed here.
  });

  group('eraLabel-named endpoints actually belong to that era', () {
    test('every "(X → Y)" pair in an eraLabel names people tagged there',
        () {
      final arrowPattern = RegExp(r'\(([^→()]+)→([^→()]+)\)');
      var checkedAtLeastOne = false;
      for (final era in byEra.keys) {
        final label = eraLabel(era, 'en');
        final match = arrowPattern.firstMatch(label);
        if (match == null) continue;
        checkedAtLeastOne = true;
        final left = match.group(1)!.trim();
        final right = match.group(2)!.trim();
        for (final name in [left, right]) {
          final person = people.firstWhere(
            (p) => p['name'] == name,
            orElse: () => const <String, dynamic>{},
          );
          expect(person, isNotEmpty,
              reason: '"$name" named in the $era eraLabel ("$label") is not '
                  'any person\'s "name" field');
          expect(person['era'], era,
              reason: '"$name" named in the $era eraLabel ("$label") is '
                  'actually tagged era="${person['era']}"');
        }
      }
      expect(checkedAtLeastOne, isTrue,
          reason: 'no eraLabel had an "(X → Y)" pair to check — update this '
              'test if antediluvian\'s label stopped using that form');
    });
  });
}
