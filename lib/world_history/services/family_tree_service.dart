import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'package:yahwehs_words/world_history/models/biblical_person.dart';

/// The `_meta` block of `assets/world_chart/family_tree.json`, written by
/// `tools/audit_dates.py`.
///
/// The legend saying what an AM year and a BC year each rest on — and
/// what the "c." prefix means — has been in the asset since the dating
/// audit ran, and nothing parsed it: `yearLegend` appeared at zero lines
/// in all of `lib/`. Same gap `HebrewKingsMeta` closed for the kings and
/// #318 phase 24 closed for the wheel. A stamped asset is not a
/// disclosed one.
class FamilyTreeMeta {
  const FamilyTreeMeta({
    required this.yearLegendAm,
    required this.yearLegendBc,
    required this.kindBirth,
    required this.kindReign,
    required this.kindApproximate,
    required this.counts,
  });

  /// Trilingual: `en` / `zh-Hans` / `zh-Hant`.
  final Map<String, String> yearLegendAm;
  final Map<String, String> yearLegendBc;
  final Map<String, String> kindBirth;
  final Map<String, String> kindReign;
  final Map<String, String> kindApproximate;

  /// `{'birth': 27, 'reign': 14, 'approximate': 236}` — the asset's own
  /// count, already pinned against the records by
  /// `person_dating_test.dart`'s "the counts in _meta match the records".
  final Map<String, int> counts;

  static const empty = FamilyTreeMeta(
    yearLegendAm: {},
    yearLegendBc: {},
    kindBirth: {},
    kindReign: {},
    kindApproximate: {},
    counts: {},
  );

  String yearLegendAmFor(String locale) => _pick(yearLegendAm, locale);
  String yearLegendBcFor(String locale) => _pick(yearLegendBc, locale);
  String kindBirthFor(String locale) => _pick(kindBirth, locale);
  String kindReignFor(String locale) => _pick(kindReign, locale);
  String kindApproximateFor(String locale) => _pick(kindApproximate, locale);

  static String _pick(Map<String, String> m, String locale) =>
      m[locale] ?? m['en'] ?? '';

  /// Tolerates the OLD shape, where each of these fields was a bare
  /// English `String` rather than a trilingual map — a stale cached
  /// asset must not throw.
  static Map<String, String> _localized(dynamic v) {
    if (v is String) return {'en': v};
    if (v is Map) {
      return {
        for (final e in v.entries)
          if (e.value is String) e.key.toString(): e.value as String,
      };
    }
    return const {};
  }

  static FamilyTreeMeta fromJson(Map<String, dynamic>? m) {
    final legend = (m?['yearLegend'] as Map?)?.cast<String, dynamic>();
    final dating = (m?['dating'] as Map?)?.cast<String, dynamic>();
    final kinds = (dating?['kinds'] as Map?)?.cast<String, dynamic>();
    final rawCounts = (dating?['counts'] as Map?)?.cast<String, dynamic>();
    return FamilyTreeMeta(
      yearLegendAm: _localized(legend?['am']),
      yearLegendBc: _localized(legend?['bc']),
      kindBirth: _localized(kinds?['birth']),
      kindReign: _localized(kinds?['reign']),
      kindApproximate: _localized(kinds?['approximate']),
      counts: {
        for (final e in (rawCounts ?? const {}).entries)
          if (e.value is num) e.key.toString(): (e.value as num).toInt(),
      },
    );
  }
}

/// Loads the curated `assets/world_chart/family_tree.json` dataset and provides
/// id-based lookups + a few traversal helpers used by the
/// FamilyTreePage and PersonDetailSheet.
///
/// Data shape: `{ "_meta": FamilyTreeMeta, "people": [BiblicalPerson, …] }`.
/// The service caches the parsed list for the process lifetime; a single
/// asset read on first access.
class FamilyTreeService {
  FamilyTreeService._();
  static final FamilyTreeService instance = FamilyTreeService._();

  List<BiblicalPerson>? _list;
  Map<String, BiblicalPerson>? _byId;
  FamilyTreeMeta? _meta;

  Future<List<BiblicalPerson>> loadAll() async {
    if (_list != null) return _list!;
    final raw = await rootBundle.loadString('assets/world_chart/family_tree.json');
    final j = json.decode(raw) as Map<String, dynamic>;
    final entries = (j['people'] as List?) ?? const [];
    final list = entries
        .whereType<Map<String, dynamic>>()
        .map(BiblicalPerson.fromJson)
        .toList();
    _list = list;
    _byId = {for (final p in list) p.id: p};
    _meta = FamilyTreeMeta.fromJson((j['_meta'] as Map?)?.cast<String, dynamic>());
    return list;
  }

  /// Synchronous lookup — caller must have awaited [loadAll] first.
  BiblicalPerson? byId(String id) => _byId?[id];

  /// The loaded people, or null before [loadAll] has finished — the
  /// same synchronous door `ChronologyService` and `HebrewKingsService`
  /// offer, and for the same caller: the wheel's genealogy rail is
  /// built inside a paint pass and cannot await.
  List<BiblicalPerson>? get cached => _list;

  /// The asset's `_meta` legend. `FamilyTreeMeta.empty` until [loadAll]
  /// has completed at least once.
  FamilyTreeMeta get meta => _meta ?? FamilyTreeMeta.empty;

  /// Synchronous full-list accessor for callers that need every
  /// person but don't want to await. Returns `[]` when [loadAll]
  /// hasn't completed yet, so the result is always safe to iterate.
  List<BiblicalPerson> allOrEmpty() => _list ?? const [];

  Future<BiblicalPerson?> lookup(String id) async {
    await loadAll();
    return _byId?[id];
  }

  /// Persons with no `fatherId` AND no `motherId` AND no incoming
  /// reference as anyone's child — i.e. the trees' canonical roots
  /// for the browser to start from. In our MVP this collapses to
  /// just Adam + Eve (everyone else in the dataset descends from
  /// them through the named chain).
  Future<List<BiblicalPerson>> roots() async {
    final all = await loadAll();
    final referencedAsChild = <String>{};
    for (final p in all) {
      for (final c in p.childIds) {
        referencedAsChild.add(c);
      }
    }
    return all
        .where((p) =>
            p.fatherId == null &&
            p.motherId == null &&
            !referencedAsChild.contains(p.id))
        .toList();
  }

  /// Resolve child ids on a person to actual person objects, in
  /// declared order, dropping ids that aren't in the dataset.
  Future<List<BiblicalPerson>> children(BiblicalPerson p) async {
    await loadAll();
    return [
      for (final id in p.childIds)
        if (_byId?[id] != null) _byId![id]!,
    ];
  }

  /// Same shape as [children] but for spouses.
  Future<List<BiblicalPerson>> spouses(BiblicalPerson p) async {
    await loadAll();
    return [
      for (final id in p.spouseIds)
        if (_byId?[id] != null) _byId![id]!,
    ];
  }

  /// Walk up the father chain until we run out (root or missing id).
  /// Returns ancestors in *child-first* order: [parent, grandparent, …].
  /// Used by the detail sheet to render a quick "ancestry" trail.
  Future<List<BiblicalPerson>> patrilineage(BiblicalPerson p) async {
    await loadAll();
    final out = <BiblicalPerson>[];
    var cur = p;
    final seen = <String>{cur.id};
    while (cur.fatherId != null) {
      final f = _byId?[cur.fatherId];
      if (f == null || seen.contains(f.id)) break;
      out.add(f);
      seen.add(f.id);
      cur = f;
    }
    return out;
  }
}
