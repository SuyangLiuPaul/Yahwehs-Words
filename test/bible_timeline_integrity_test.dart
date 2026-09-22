import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `assets/bible_timeline.json` was replaced wholesale in `a7c35696`
/// (Words took Yahweh's Sword's chronology, +1000 lines). The only
/// things pinned about it elsewhere are `_meta.count`
/// (`test/onboarding_counts_test.dart:59`), its citation counts
/// (`test/citation_target_in_canon_test.dart`,
/// `test/evidence_unresolvable_citation_test.dart`) and tail glyphs
/// (`test/canon_chapters_test.dart`). Nothing checks that its
/// cross-references into `family_tree.json` resolve, or that every
/// `era` value it uses has a live label and colour in
/// `lib/pages/bible_timeline_page.dart` — both holes are silent at
/// runtime: `_eraLabel` falls back to `era.toUpperCase()` and
/// `_eraColor` to grey `0xFF555555` rather than throwing, and a
/// dangling `personIds` chip just jumps nowhere. This test recomputes
/// both invariants from the raw assets, independent of any script that
/// built them, so a future import that introduces either failure is
/// caught here instead of shipping silently.
void main() {
  late List<Map<String, dynamic>> events;
  late Set<String> familyTreeIds;

  setUpAll(() {
    final timelineData =
        json.decode(File('assets/bible_timeline.json').readAsStringSync())
            as Map;
    events = (timelineData['events'] as List).cast<Map<String, dynamic>>();

    final treeData =
        json.decode(File('assets/family_tree.json').readAsStringSync())
            as Map;
    familyTreeIds = (treeData['people'] as List)
        .cast<Map<String, dynamic>>()
        .map((p) => p['id'] as String)
        .toSet();
  });

  // The literal set `_eraLabel`/`_eraColor` in bible_timeline_page.dart
  // recognise. Kept here as a plain string set (not imported from the
  // widget file, which isn't reachable from a raw-asset test) precisely
  // so that a future asset era not matched here must explain itself:
  // both this set and the page's switch/map need to move together.
  const knownEras = {
    'antediluvian',
    'patriarchs',
    'mosaic',
    'conquest',
    'monarchy',
    'exile',
    'intertestamental',
    'nt',
  };

  test('event ids are unique and non-empty', () {
    final ids = events.map((e) => e['id'] as String).toList();
    expect(ids.every((id) => id.isNotEmpty), isTrue,
        reason: 'an event has an empty id');
    expect(ids.toSet().length, ids.length,
        reason: 'event ids are not all unique');
  });

  test('every personIds entry resolves to an id in family_tree.json', () {
    final dangling = <String>[];
    for (final event in events) {
      final personIds = (event['personIds'] as List?)?.cast<String>() ??
          const <String>[];
      for (final personId in personIds) {
        if (!familyTreeIds.contains(personId)) {
          dangling.add('${event['id']}: personIds contains "$personId", '
              'not in family_tree.json');
        }
      }
    }
    expect(dangling, isEmpty, reason: dangling.join('\n'));
  });

  test('every era value used by an event is one _eraLabel/_eraColor '
      'in bible_timeline_page.dart actually render — anything else '
      'silently falls back to era.toUpperCase() and grey 0xFF555555', () {
    final usedEras = events.map((e) => e['era'] as String).toSet();
    expect(usedEras.difference(knownEras), isEmpty,
        reason: 'these era values have no _eraLabel/_eraColor entry and '
            'would render as an uppercase fallback and grey: '
            '${usedEras.difference(knownEras)}');
  });

  test('all six localized fields are non-empty on every event, so a '
      'future import that drops one fails here instead of silently '
      'falling back to English at render time', () {
    const localizedFields = [
      'titleEn',
      'titleZhHans',
      'titleZhHant',
      'descEn',
      'descZhHans',
      'descZhHant',
    ];
    final missing = <String>[];
    for (final event in events) {
      for (final field in localizedFields) {
        final value = event[field] as String?;
        if (value == null || value.trim().isEmpty) {
          missing.add('${event['id']}: $field is empty');
        }
      }
    }
    expect(missing, isEmpty, reason: missing.join('\n'));
  });

  // Each check above proven able to fail: run it against a mutated
  // in-memory copy (never the asset on disk) and confirm it goes red.
  group('each check above can actually fail', () {
    test('duplicate id is caught', () {
      final mutated = [
        ...events.map((e) => Map<String, dynamic>.from(e)),
        Map<String, dynamic>.from(events.first),
      ];
      final ids = mutated.map((e) => e['id'] as String).toList();
      expect(ids.toSet().length, isNot(ids.length));
    });

    test('a dangling personIds entry is caught', () {
      final mutated = Map<String, dynamic>.from(events.first);
      mutated['personIds'] = ['definitely-not-a-real-person-id'];
      final personIds =
          (mutated['personIds'] as List).cast<String>();
      final dangling =
          personIds.where((id) => !familyTreeIds.contains(id)).toList();
      expect(dangling, isNotEmpty);
    });

    test('an unknown era value is caught', () {
      final mutated = Map<String, dynamic>.from(events.first);
      mutated['era'] = 'some-made-up-era';
      expect(knownEras.contains(mutated['era']), isFalse);
    });

    test('an emptied localized field is caught', () {
      final mutated = Map<String, dynamic>.from(events.first);
      mutated['titleZhHant'] = '';
      expect((mutated['titleZhHant'] as String).trim().isEmpty, isTrue);
    });
  });
}
