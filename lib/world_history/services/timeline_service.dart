import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'package:yahwehs_words/world_history/models/timeline_event.dart';

/// The `_meta` block of `assets/world_chart/bible_timeline.json`, written by
/// `tools/audit_dates.py`.
///
/// Only the two READER-FACING fields are modelled. `basis` and
/// `septuagintYear` are deliberately absent: `ui_strings.dart` already
/// owns the reader's wording of both — `timelineBasisScripture` and
/// friends via [basisText], and `timelineSeptuagintYear` — and both
/// already render on every expanded row. Modelling the asset's copies
/// would put two wordings of one fact in one app. The asset keeps them
/// as its own audit log.
/// The creation year, and what fixes it.
///
/// THE ONE DEFINITION. Anno Mundi figures live in `chronology.json`;
/// this app draws them on a BC axis, and every such conversion is
/// `creation.year + am`. Written once by `tools/audit_dates.py` and
/// read here, so the pre-Abraham events on the timeline and anything
/// else that plots an AM figure add the SAME number. Two places
/// computing it is how one man ends up with two years.
class TimelineCreation {
  const TimelineCreation({
    required this.year,
    required this.basis,
    required this.datingRefs,
  });

  /// Astronomical, negative for BC. A caller that cannot find this
  /// field must draw nothing rather than fall back to a literal: a
  /// silent -4000 default is the calendar this anchor replaced.
  final int year;

  /// `scripture+thiele` — the intervals are stated, and the year they
  /// are counted back from is Thiele's.
  final String basis;

  /// The verses the chain runs through, from 1 Kings 6:1 down to
  /// Genesis 5:3.
  final List<String> datingRefs;

  static TimelineCreation? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final year = raw['year'];
    if (year is! num) return null;
    return TimelineCreation(
      year: year.toInt(),
      basis: (raw['basis'] as String?) ?? 'conventional',
      datingRefs: ((raw['datingRefs'] as List?) ?? const [])
          .whereType<String>()
          .toList(),
    );
  }
}

class TimelineMeta {
  const TimelineMeta({
    required this.anchor,
    required this.note,
    required this.counts,
    this.creation,
  });

  /// Trilingual: `en` / `zh-Hans` / `zh-Hant`.
  final Map<String, String> anchor;
  final Map<String, String> note;

  /// `{'conventional': 75, 'scripture+thiele': 18, 'thiele': 5}` — the
  /// asset's own tally, pinned against the records by
  /// `bible_timeline_about_test.dart`.
  final Map<String, int> counts;

  /// Null only if the asset predates the field; nothing may substitute
  /// a literal for it.
  final TimelineCreation? creation;

  static const empty = TimelineMeta(anchor: {}, note: {}, counts: {});

  String anchorFor(String locale) => _pick(anchor, locale);
  String noteFor(String locale) => _pick(note, locale);

  static String _pick(Map<String, String> m, String locale) =>
      m[locale] ?? m['en'] ?? '';

  /// Tolerates the OLD shape, where these were bare English `String`s —
  /// a stale cached asset must not throw.
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

  static TimelineMeta fromJson(Map<String, dynamic>? m) => TimelineMeta(
        anchor: _localized(m?['anchor']),
        note: _localized(m?['note']),
        counts: {
          for (final e in ((m?['counts'] as Map?) ?? const {}).entries)
            if (e.value is num) e.key.toString(): (e.value as num).toInt(),
        },
        creation: TimelineCreation.fromJson(m?['creation']),
      );
}

/// Loads the curated `assets/world_chart/bible_timeline.json` dataset and
/// caches it for the process lifetime.
class TimelineService {
  TimelineService._();
  static final TimelineService instance = TimelineService._();

  List<TimelineEvent>? _cache;
  TimelineMeta? _meta;

  /// Loads & sorts events chronologically (oldest first).
  Future<List<TimelineEvent>> loadAll() async {
    if (_cache != null) return _cache!;
    final raw = await rootBundle.loadString('assets/world_chart/bible_timeline.json');
    final j = json.decode(raw) as Map<String, dynamic>;
    final entries = (j['events'] as List?) ?? const [];
    final list = entries
        .whereType<Map<String, dynamic>>()
        .map(TimelineEvent.fromJson)
        .toList();
    // STABLE, and it has to be. Four events share -1446 (the plagues,
    // the exodus, the manna, Sinai) and three share -1406; the asset
    // lists each such group in narrative order, and that order is the
    // only thing that says the plagues came before the departure —
    // their shared year cannot. `List.sort` is not stable in Dart, so a
    // comparator on the year alone let an unrelated edit elsewhere in
    // the file reshuffle those groups: adding six antediluvian records
    // flipped Exodus 12's context pane to read "The Exodus, The Ten
    // Plagues". Ties fall back to the asset's own index.
    final order = {for (var i = 0; i < list.length; i++) list[i].id: i};
    list.sort((a, b) {
      final byYear = a.year.compareTo(b.year);
      return byYear != 0 ? byYear : order[a.id]!.compareTo(order[b.id]!);
    });
    _cache = list;
    _meta = TimelineMeta.fromJson((j['_meta'] as Map?)?.cast<String, dynamic>());
    return list;
  }

  List<TimelineEvent> allOrEmpty() => _cache ?? const [];

  /// The asset's `_meta`. [TimelineMeta.empty] until [loadAll] has
  /// completed at least once.
  TimelineMeta get meta => _meta ?? TimelineMeta.empty;
}
