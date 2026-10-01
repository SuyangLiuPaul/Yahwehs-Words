import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'package:yahwehs_words/world_history/models/hebrew_king.dart';
import 'package:yahwehs_words/world_history/utils/kings_contemporaries.dart'
    as kings_query;
import 'package:yahwehs_words/world_history/utils/kings_contemporaries.dart'
    show ContemporaryTally;

/// The chart's own header, as opposed to its records.
///
/// `hebrew_kings.json` has carried these fields since the asset was
/// written and nothing parsed them; #318 phase 24 found the identical
/// gap on the wheel. A provenance sentence that no widget reads is not
/// a disclosed one.
class HebrewKingsMeta {
  const HebrewKingsMeta({required this.note, required this.sources});

  /// Why a single year stands where Thiele writes a pair. Trilingual.
  final Map<String, String> note;

  final List<String> sources;

  String noteFor(String locale) => note[locale] ?? note['en'] ?? '';

  static HebrewKingsMeta fromJson(Map<String, dynamic>? m) => HebrewKingsMeta(
        note: {
          for (final e in ((m?['note'] as Map?) ?? const {}).entries)
            if (e.value is String) e.key.toString(): e.value as String,
        },
        sources: ((m?['sources'] as List?) ?? const [])
            .whereType<String>()
            .toList(),
      );
}

/// Loads `assets/world_chart/hebrew_kings.json` — the kings of Judah and Israel on
/// Thiele's chronology — and answers the one question the chart exists
/// to answer: who was on the other throne at the same time.
class HebrewKingsData {
  const HebrewKingsData({
    required this.kings,
    required this.epochs,
    required this.systemNames,
    required this.sources,
    required this.meta,
  });

  final List<HebrewKing> kings;
  final List<KingsEpoch> epochs;
  final Map<String, String> systemNames;
  final List<String> sources;
  final HebrewKingsMeta meta;

  String systemNameFor(String locale) =>
      systemNames[locale] ?? systemNames['en'] ?? 'Thiele';

  List<HebrewKing> ofKingdom(Kingdom k) =>
      kings.where((e) => e.kingdom == k).toList();

  HebrewKing? byId(String id) {
    for (final k in kings) {
      if (k.id == id) return k;
    }
    return null;
  }

  /// Kings of the *other* kingdom whose reigns shared a year with [k],
  /// in chronological order.
  ///
  /// This is the synchronism the books of Kings themselves supply, and
  /// it is computed rather than stored: a hand-written contemporaries
  /// list would be a second copy of the dates, free to drift from the
  /// first.
  ///
  /// The rule lives in `utils/kings_contemporaries.dart` and every
  /// surface that asks — the chart, the wheel's reign sheet, the year
  /// lookup — arrives at the same function rather than at a copy of it.
  List<HebrewKing> contemporariesOf(HebrewKing k) =>
      kings_query.contemporariesOf(kings, k);

  /// [contemporariesOf] counted: how many overlapped, and how many of
  /// those held the throne rather than merely claimed it.
  ContemporaryTally tallyFor(HebrewKing k) =>
      ContemporaryTally.of(contemporariesOf(k));

  /// Who was on a throne in [year] — negative for BC.
  List<HebrewKing> reigningIn(int year, {Kingdom? kingdom}) =>
      kings_query.reigningInYear(kings, year, kingdom: kingdom);

  /// Kings matching [query] in the reader's [locale].
  List<HebrewKing> search(
    String query,
    String locale, {
    String Function(String reference, String locale)? refLabel,
  }) =>
      kings_query.searchKings(kings, query, locale, refLabel: refLabel);

  /// The earliest and latest year any king in the file touches, used to
  /// scale the chart axis.
  (int, int) get extent {
    var lo = kings.first.reignStart;
    var hi = kings.first.reignEnd;
    for (final k in kings) {
      if (k.reignStart < lo) lo = k.reignStart;
      if (k.reignEnd > hi) hi = k.reignEnd;
    }
    return (lo, hi);
  }

  static HebrewKingsData fromJson(Map<String, dynamic> j) {
    final meta =
        HebrewKingsMeta.fromJson((j['_meta'] as Map?)?.cast<String, dynamic>());
    return HebrewKingsData(
      kings: ((j['kings'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(HebrewKing.fromJson)
          .toList(),
      epochs: ((j['epochs'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(KingsEpoch.fromJson)
          .toList(),
      systemNames: {
        for (final e in ((j['systemName'] as Map?) ?? const {}).entries)
          if (e.value is String) e.key.toString(): e.value as String,
      },
      sources: meta.sources,
      meta: meta,
    );
  }
}

class HebrewKingsService {
  HebrewKingsService._();
  static final HebrewKingsService instance = HebrewKingsService._();

  HebrewKingsData? _cache;

  /// What has been loaded, or null.
  ///
  /// For a caller that is already past the await — the world-history
  /// wheel lists a kingdom's kings when its sheet opens, and
  /// `WheelHistoryService.load` awaits [load] before it returns any
  /// record, so a page drawing the wheel is a page past it. Null is a
  /// real answer for anyone else and is not papered over with an empty
  /// list: an empty chart of the kings and an unloaded one are
  /// different facts.
  HebrewKingsData? get cached => _cache;

  Future<HebrewKingsData> load() async {
    final cached = _cache;
    if (cached != null) return cached;
    final raw = await rootBundle.loadString('assets/world_chart/hebrew_kings.json');
    final data =
        HebrewKingsData.fromJson(json.decode(raw) as Map<String, dynamic>);
    _cache = data;
    return data;
  }
}
