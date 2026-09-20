import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `assets/family_tree.json` stores each king's own `birthYear` directly,
/// hand-maintained with no builder script. Twelve Judahite kings held their
/// *accession* year in that field instead of a birth year, which produced
/// three fathers "born" after their own sons — `ahaz`/`hezekiah`,
/// `amon`/`josiah`, `jehoiakim`/`jeconiah`. This test recomputes, from the
/// raw asset only, whether any parent-child pair is chronologically
/// impossible, so a future accession-year-as-birth-year slip anywhere in
/// the 277-person tree is caught the same way this one was.
///
/// Second question, same root cause: `bible_chronology.json`'s
/// `_meta.statedLifespansNotDrawn` list names an age Scripture states
/// outright for people this tree also carries a birth/death pair for.
/// Levi disagreed (137 stated vs. 207 in the tree) before this slice;
/// this test checks all nine entries in that list against whichever of
/// them the tree also has both years for.
void main() {
  late List<Map<String, dynamic>> people;
  late Map<String, Map<String, dynamic>> byId;
  late List<Map<String, dynamic>> statedLifespans;

  setUpAll(() {
    final treeData =
        json.decode(File('assets/family_tree.json').readAsStringSync())
            as Map;
    people = (treeData['people'] as List).cast<Map<String, dynamic>>();
    byId = {for (final p in people) p['id'] as String: p};

    final chronologyData =
        json.decode(File('assets/bible_chronology.json').readAsStringSync())
            as Map;
    final meta = chronologyData['_meta'] as Map;
    statedLifespans =
        (meta['statedLifespansNotDrawn'] as List).cast<Map<String, dynamic>>();
  });

  /// AM (Anno Mundi) and BC/AD share one signed timeline here, per
  /// `test/family_tree_era_subtitle_test.dart`: `am - 4004` lands on the
  /// same line as this asset's `bc`-system years.
  int signed(int year, String system) => system == 'am' ? year - 4004 : year;

  test('no person is born before their own father, repo-wide', () {
    final violations = <String>[];
    for (final child in people) {
      final fatherId = child['fatherId'] as String?;
      if (fatherId == null) continue;
      final father = byId[fatherId];
      if (father == null) continue;

      final childSystem = child['yearSystem'] as String?;
      final fatherSystem = father['yearSystem'] as String?;
      if (childSystem == null || fatherSystem == null) continue;
      if (childSystem != fatherSystem) continue;

      final childBirth = child['birthYear'] as int?;
      final fatherBirth = father['birthYear'] as int?;
      if (childBirth == null || fatherBirth == null) continue;

      final childSigned = signed(childBirth, childSystem);
      final fatherSigned = signed(fatherBirth, fatherSystem);
      // Strict "before", not "before or in the same year": eliphaz/amalek
      // share a birth year in this asset (a filed, unresolved 0-year gap,
      // not this test's concern) and must not trip this check.
      if (childSigned < fatherSigned) {
        violations.add(
            '${child['id']} (birth $childSigned) is born before their '
            'father ${father['id']} (birth $fatherSigned)');
      }
    }
    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test(
      'birth/death pairs the tree carries agree with '
      'bible_chronology.json\'s statedLifespansNotDrawn ages', () {
    final mismatches = <String>[];
    for (final entry in statedLifespans) {
      final id = entry['id'] as String;
      final statedAge = entry['age'] as int;
      final person = byId[id];
      if (person == null) continue; // not every id is in this tree
      final birth = person['birthYear'] as int?;
      final death = person['deathYear'] as int?;
      if (birth == null || death == null) {
        continue; // no birth/death pair in the tree to check
      }
      final lifespan = death - birth;
      if (lifespan != statedAge) {
        mismatches.add('$id: tree gives $lifespan years '
            '(birth $birth, death $death), but ${entry['ref']} states '
            '$statedAge');
      }
    }
    expect(mismatches, isEmpty, reason: mismatches.join('\n'));
  });
}
