/// One row in the Bible timeline. Loaded from
/// `assets/world_chart/bible_timeline.json`.
library;

import 'package:yahwehs_words/world_history/utils/date_hedge.dart';

class TimelineEvent {
  /// Stable id (kebab/snake-case).
  final String id;

  /// Signed integer year. Negative = BC, positive = AD.
  final int year;

  /// Era key — matches the family-tree era palette
  /// (`antediluvian`, `patriarchs`, `mosaic`, `conquest`,
  /// `monarchy`, `exile`, `intertestamental`, `nt`).
  final String era;

  /// Localized titles + 1-sentence descriptions.
  final String titleEn;
  final String titleZhHans;
  final String titleZhHant;
  final String descEn;
  final String descZhHans;
  final String descZhHant;

  /// Bible verse references (canonical English form). Tap → jump
  /// to verse via the existing `prepareJumpToVerse` plumbing.
  final List<String> refs;

  /// Optional cross-links to family-tree person ids — tappable
  /// chips on the event card that jump to the family tree page
  /// with that person highlighted.
  final List<String> personIds;

  /// What the year rests on. Written by `tools/audit_dates.py`, one of
  /// `scripture+thiele` (intervals the text states, counted from the
  /// Thiele anchor in `_meta.anchor`), `thiele` (from
  /// `hebrew_kings.json`), or `conventional` (a reconstruction no such
  /// chain reaches).
  ///
  /// It was plain `scripture` until v1.6.146, which was over-claiming:
  /// scripture states intervals, never a BC year, so every year here
  /// rests on Thiele as well. `family_tree.json` already said so.
  ///
  /// WHY THIS IS ON THE MODEL AND NOT ONLY IN THE ASSET. Check 32
  /// (v1.6.120) put a basis on all 277 people *and* all 105 events, and
  /// the people's half reached the reader — [BiblicalPerson
  /// .displayYears] prefixes "c." for a reconstruction and refuses to
  /// print a birth year for a record that holds an accession year. The
  /// events' half stopped at the JSON: `fromJson` did not read this
  /// field, so 85 of 98 dates printed as flat as the 13 then thought to
  /// be derived — a count v1.6.146 found was itself wrong, since the 13
  /// were an id list nobody had checked against a year. The asset's own `_meta.note` — "nothing here is presented
  /// as a date the text gives unless the text gives it" — was a promise
  /// only the file kept.
  final String basis;

  /// True exactly when [basis] is `conventional`; the asset writes both
  /// and `test/person_dating_test.dart` holds them in step.
  final bool approximate;

  /// The verses that state the intervals this year was counted along —
  /// the whole chain back to the anchor, not just the last link.
  ///
  /// These are NOT [refs]. [refs] are where the event is narrated, and on
  /// nine of the derived events the two sets do not overlap at all: the
  /// Jordan crossing is narrated in Joshua 3-4, which gives no number,
  /// while its year comes from Deuteronomy 1:3 and Joshua 5:6. Showing
  /// only [refs] beside the sentence "counted along intervals the text
  /// states" invites the reader to tap a chapter that states none.
  final List<String> datingRefs;

  /// Where the same event falls if Exodus 12:40 is read as the Septuagint
  /// reads it — 430 years in Egypt *and* Canaan rather than in Egypt
  /// alone. Null on every event the chain does not reach through that
  /// verse, and on every event that is not derived at all.
  final int? septuagintYear;

  const TimelineEvent({
    required this.id,
    required this.year,
    required this.era,
    required this.titleEn,
    required this.titleZhHans,
    required this.titleZhHant,
    required this.descEn,
    required this.descZhHans,
    required this.descZhHant,
    required this.refs,
    required this.personIds,
    this.basis = 'conventional',
    this.approximate = true,
    this.datingRefs = const [],
    this.septuagintYear,
  });

  String localizedTitle(String locale) {
    if (locale == 'zh-Hant' && titleZhHant.isNotEmpty) return titleZhHant;
    if (locale.startsWith('zh') && titleZhHans.isNotEmpty) return titleZhHans;
    return titleEn;
  }

  String localizedDesc(String locale) {
    if (locale == 'zh-Hant' && descZhHant.isNotEmpty) return descZhHant;
    if (locale.startsWith('zh') && descZhHans.isNotEmpty) return descZhHans;
    return descEn;
  }

  /// Render the year as locale-aware "公元前 1010 年" / "1010 BC"
  /// / "公元 30 年" / "AD 30", hedged when [approximate].
  ///
  /// The hedge is the same one [BiblicalPerson.displayYears] applies, in
  /// the same words and with the same spacing, because the two surfaces
  /// draw on the same generator and a reader moving between the family
  /// tree and the timeline must not have to learn a second vocabulary.
  String displayYear(String locale) {
    final plain = _plainYear(year, locale.startsWith('zh'));
    if (!approximate) return plain;
    return '${approximatePrefix(locale)}$plain';
  }

  /// The Septuagint's year in the same words, or null where there is
  /// none. Never hedged: the intervals behind it are the same stated
  /// ones, and the caveat that belongs to it — where the Greek's 430
  /// years begin — is carried by the sentence beside it, not by a "c."
  /// that would read as "nobody knows".
  String? displaySeptuagintYear(String locale) {
    final y = septuagintYear;
    return y == null ? null : _plainYear(y, locale.startsWith('zh'));
  }

  String _plainYear(int year, bool isZh) {
    if (year < 0) {
      if (isZh) return '公元前 ${-year} 年';
      return '${-year} BC';
    }
    if (year == 0) {
      if (isZh) return '公元元年';
      return 'AD 1';
    }
    if (isZh) return '公元 $year 年';
    return 'AD $year';
  }

  factory TimelineEvent.fromJson(Map<String, dynamic> j) {
    return TimelineEvent(
      id: j['id'] as String,
      year: (j['year'] as num).toInt(),
      era: j['era'] as String? ?? 'unknown',
      titleEn: j['titleEn'] as String? ?? '',
      titleZhHans: j['titleZhHans'] as String? ?? '',
      titleZhHant: j['titleZhHant'] as String? ?? '',
      descEn: j['descEn'] as String? ?? '',
      descZhHans: j['descZhHans'] as String? ?? '',
      descZhHant: j['descZhHant'] as String? ?? '',
      refs: (j['refs'] as List?)?.cast<String>() ?? const [],
      personIds: (j['personIds'] as List?)?.cast<String>() ?? const [],
      basis: j['basis'] as String? ?? 'conventional',
      approximate: j['approximate'] as bool? ?? true,
      datingRefs: (j['datingRefs'] as List?)?.cast<String>() ?? const [],
      septuagintYear: (j['septuagintYear'] as num?)?.toInt(),
    );
  }
}
