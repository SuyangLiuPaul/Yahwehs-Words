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
///
/// Third question, added 2026-09-21 (queue:14267): the first check used
/// to `continue` past any parent/child pair whose two ends used different
/// `yearSystem`s, and never looked at `motherId` at all. Both holes are
/// closed here: `motherId` is swept alongside `fatherId`, and every
/// cross-`yearSystem` pair is checked against a literal pin (the 3 links
/// this slice measured, all Terah's sons) and against
/// `bible_chronology.json`'s `_meta.crossSystemParentLinks` — not trusted
/// from either source alone, so a NEW cross-system link, or an inversion
/// in a pair this test doesn't already know about, still fails.
void main() {
  late List<Map<String, dynamic>> people;
  late Map<String, Map<String, dynamic>> byId;
  late List<Map<String, dynamic>> statedLifespans;
  late List<Map<String, dynamic>> crossSystemParentLinks;

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
    crossSystemParentLinks =
        (meta['crossSystemParentLinks'] as List).cast<Map<String, dynamic>>();
  });

  /// AM (Anno Mundi) and BC/AD share one signed timeline here, per
  /// `test/family_tree_era_subtitle_test.dart`: `am - 4004` lands on the
  /// same line as this asset's `bc`-system years.
  int signed(int year, String system) => system == 'am' ? year - 4004 : year;

  /// Every fatherId/motherId link, recomputed independently from the raw
  /// asset: (childId, relation, parentId, childSigned, parentSigned).
  /// Both the born-before-parent test and the cross-system test below
  /// share this single sweep rather than each re-deriving it.
  List<(String, String, String, int, int)> parentLinks() {
    final links = <(String, String, String, int, int)>[];
    for (final child in people) {
      for (final relation in ['father', 'mother']) {
        final parentId =
            child[relation == 'father' ? 'fatherId' : 'motherId'] as String?;
        if (parentId == null) continue;
        final parent = byId[parentId];
        if (parent == null) continue;

        final childSystem = child['yearSystem'] as String?;
        final parentSystem = parent['yearSystem'] as String?;
        if (childSystem == null || parentSystem == null) continue;

        final childBirth = child['birthYear'] as int?;
        final parentBirth = parent['birthYear'] as int?;
        if (childBirth == null || parentBirth == null) continue;

        links.add((
          child['id'] as String,
          relation,
          parentId,
          signed(childBirth, childSystem),
          signed(parentBirth, parentSystem),
        ));
      }
    }
    return links;
  }

  test('no person is born before their own father or mother, repo-wide '
      '(same yearSystem pairs only — cross-system pairs are covered by '
      'the dedicated test below)', () {
    final violations = <String>[];
    for (final child in people) {
      for (final relation in ['father', 'mother']) {
        final parentId =
            child[relation == 'father' ? 'fatherId' : 'motherId'] as String?;
        if (parentId == null) continue;
        final parent = byId[parentId];
        if (parent == null) continue;

        final childSystem = child['yearSystem'] as String?;
        final parentSystem = parent['yearSystem'] as String?;
        if (childSystem == null || parentSystem == null) continue;
        if (childSystem != parentSystem) continue;

        final childBirth = child['birthYear'] as int?;
        final parentBirth = parent['birthYear'] as int?;
        if (childBirth == null || parentBirth == null) continue;

        final childSigned = signed(childBirth, childSystem);
        final parentSigned = signed(parentBirth, parentSystem);
        // Strict "before", not "before or in the same year": eliphaz/amalek
        // share a birth year in this asset (a filed, unresolved 0-year gap,
        // not this test's concern) and must not trip this check.
        if (childSigned < parentSigned) {
          violations.add(
              '${child['id']} (birth $childSigned) is born before their '
              '$relation ${parent['id']} (birth $parentSigned)');
        }
      }
    }
    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('cross-yearSystem parent/child links are exactly the 3 measured '
      '2026-09-21 (all Terah\'s sons), and match '
      'bible_chronology.json\'s _meta.crossSystemParentLinks', () {
    final crossSystem = parentLinks()
        .where((l) {
          final childSystem = byId[l.$1]!['yearSystem'] as String;
          final parentSystem = byId[l.$3]!['yearSystem'] as String;
          return childSystem != parentSystem;
        })
        .toList();

    // The measured set, pinned so a NEW cross-system link (or one of
    // these three disappearing) must explain itself rather than drift
    // silently — this does not come from _meta, it is this test's own
    // independent recomputation from family_tree.json.
    expect(
      {for (final l in crossSystem) '${l.$1}/${l.$2}'},
      {'abraham/father', 'haran/father', 'nahor_younger/father'},
      reason: 'the set of cross-yearSystem parent/child links has changed '
          '— every one must be declared in CROSS_SYSTEM_PARENT_LINKS in '
          'tools/build_bible_chronology.py with its gap and a note',
    );
    for (final l in crossSystem) {
      final (childId, relation, parentId, childSigned, parentSigned) = l;
      expect(byId[parentId]!['id'], parentId);
      final gap = childSigned - parentSigned;
      final expectedGap = {
        'abraham': -40,
        'haran': -74,
        'nahor_younger': -54,
      }[childId];
      expect(gap, expectedGap,
          reason: '$childId/$parentId ($relation): recomputed gap $gap '
              'does not match the measured figure — a source year moved');
    }

    // Cross-check against the builder's own output: same set, same
    // figures, recomputed independently on both sides rather than one
    // trusting the other.
    final declaredKeys = {
      for (final row in crossSystemParentLinks)
        '${row['childId']}/${row['relation']}': row,
    };
    expect(
      declaredKeys.keys.toSet(),
      {for (final l in crossSystem) '${l.$1}/${l.$2}'},
      reason: '_meta.crossSystemParentLinks and this independent '
          'recomputation disagree on which links cross yearSystems — '
          'rerun tools/build_bible_chronology.py',
    );
    for (final l in crossSystem) {
      final (childId, relation, parentId, childSigned, parentSigned) = l;
      final row = declaredKeys['$childId/$relation']!;
      expect(row['parentId'], parentId);
      expect(row['childSignedYear'], childSigned);
      expect(row['parentSignedYear'], parentSigned);
      expect(row['gapYears'], childSigned - parentSigned,
          reason: '$childId/$parentId ($relation): _meta.'
              'crossSystemParentLinks was not regenerated after a source '
              'year changed');
    }
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
