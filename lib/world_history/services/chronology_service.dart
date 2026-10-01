import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'package:yahwehs_words/world_history/models/chronology.dart';

/// Loads `assets/world_chart/chronology.json` — the Genesis 5 and 11 lifespans read
/// out of the Bible texts this app ships.
class ChronologyService {
  ChronologyService._();
  static final ChronologyService instance = ChronologyService._();

  ChronologyData? _cache;

  Future<ChronologyData> load() async {
    final cached = _cache;
    if (cached != null) return cached;
    final raw = await rootBundle.loadString('assets/world_chart/chronology.json');
    final data =
        ChronologyData.fromJson(json.decode(raw) as Map<String, dynamic>);
    _cache = data;
    return data;
  }

  /// The loaded data, or null before [load] has completed once.
  ///
  /// For the wheel, which awaits [load] inside
  /// `WheelHistoryService.load` and then reads the figures
  /// synchronously in `build` — the same shape `HebrewKingsService`
  /// already has, and for the same reason: a synchronous read that
  /// answers empty because the bundle has not landed reports an absence
  /// that was really a race.
  ChronologyData? get cached => _cache;
}
