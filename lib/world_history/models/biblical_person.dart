/// One named individual from the Bible's family tree, as carried in
/// `assets/world_chart/family_tree.json`. The dataset is a curated MVP covering
/// the canonical Adam → Jesus line per Matthew 1 and Luke 3 (~70
/// people). Extended over time by editing the JSON; the model and UI
/// don't need to change to absorb new entries.
library;

import 'package:yahwehs_words/world_history/utils/date_hedge.dart';

class BiblicalPerson {
  /// Stable kebab/snake-case id used by parent / spouse / child
  /// references in this same dataset. Never user-facing.
  final String id;

  /// Display name. English by default; Chinese variants below.
  final String name;
  final String? nameZhHans;
  final String? nameZhHant;

  /// The Authorised Version's spelling, when it differs from [name];
  /// empty for the 273 people where the two agree.
  ///
  /// Four of the antediluvian line have one — Enosh, Kenan, Mahalalel
  /// and Shelah, whom the KJV calls Enos, Cainan, Mahalaleel and Salah.
  /// The tree has always printed the modern form and, until this field
  /// existed, a reader of the KJV this app also ships could type the
  /// only spelling they had ever seen and be told the tree had never
  /// heard of the man. It is searched, not displayed as a second name.
  final String nameKjv;

  /// Optional parent ids. `null` means "not in dataset" rather than
  /// "no parent" (Adam genuinely has no father; Eve in the dataset
  /// also has none — both render with no parent row).
  final String? fatherId;
  final String? motherId;

  /// Spouse and child ids — same id-references into the dataset.
  /// Stored as lists so polygamous patriarchs (Abraham, Jacob, David)
  /// don't lose any wife. UI shows them in entry order.
  final List<String> spouseIds;
  final List<String> childIds;

  /// Year system used by this entry's [birthYear] and [deathYear].
  /// `am`  — Anno Mundi (years since Creation, derived from
  ///         Genesis 5 + 11). Used for Adam → Terah.
  /// `bc`  — Years before Christ (negative for BC, positive for AD).
  ///         Used for Abraham onward. Birth before death is
  ///         encoded as the more negative year being earlier:
  ///         birthYear=-2166, deathYear=-1991 for Abraham.
  final String yearSystem;
  final int? birthYear;
  final int? deathYear;
  final int? lifespan;

  /// Brief 1-2 sentence biography. Localized.
  final String summary;
  final String? summaryZhHans;
  final String? summaryZhHant;

  /// Verse references — canonical English book name + chapter + verse.
  /// Render as tappable chips that route through
  /// `resolveAndPrepareJump` so the reader scrolls to the verse with
  /// OT-fallback for NT-only versions.
  final List<String> refs;

  /// Optional role/title pill rendered below the name on the visual
  /// tree. Examples: "PATRIARCH", "MATRIARCH", "JUDGE", "KING",
  /// "PROPHET". Tribe/people-group labels (e.g. "EDOMITES",
  /// "MIDIANITES") also go here. Free-form short string; the widget
  /// just renders it as a small uppercase tag.
  final String? role;

  /// Optional accent style for the card tint. Drives a colour theme
  /// on the visual tree so the user can see the priestly (Levi) and
  /// royal (Judah) lines pop out of the dataset. Values:
  /// `priestly` (red-ish), `royal` (blue-ish), `messianic` (gold),
  /// `prophetic` (purple). Anything else falls back to the default.
  final String? accent;

  /// What the year on this record actually is, and what it rests on.
  /// Written by `tools/audit_dates.py`; `_meta.dating` in
  /// `assets/world_chart/family_tree.json` defines the vocabulary.
  ///
  /// `birth` — a birth, and derivable from an age the text states.
  ///           Shown exactly, and [datingRefs] gives the verses.
  /// `reign` — [birthYear] here is an accession or coregency year, not a
  ///           birth. Thirteen kings of Judah carried one of these in a
  ///           field named `birthYear`, so the reader was told Asa was
  ///           born in 911 BC when 911 is the year he came to the throne.
  ///           These render as a reign span from [reignStart]/[reignEnd]
  ///           and the birth year is not shown at all.
  /// `approximate` — a commonly published reconstruction that nothing we
  ///           ship fixes. Rendered with "c." so it does not read as a
  ///           date the text gives.
  final String datingKind;

  /// `scripture`, `scripture+thiele`, `thiele` or `conventional`.
  final String datingBasis;

  /// The verses the year is derived from. Empty unless [datingKind] is
  /// `birth`, since nothing else here rests on a stated figure.
  final List<String> datingRefs;

  /// Thiele's reign span, copied from `assets/world_chart/hebrew_kings.json`, which
  /// cites him. Present for everyone that file carries.
  final int? reignStart;
  final int? reignEnd;

  /// Optional canonical biblical era this person belongs to.
  /// Stable string id used by the family-tree page to group rows
  /// under section headers and emit per-row era badges. Values:
  /// `antediluvian`, `post_flood`, `patriarchs`, `mosaic`,
  /// `davidic_line`, `kings`, `exile`, `nt`. Anything else /
  /// missing falls back to "unknown" with no header / badge.
  final String? era;

  const BiblicalPerson({
    required this.id,
    required this.name,
    this.nameZhHans,
    this.nameZhHant,
    this.nameKjv = '',
    this.fatherId,
    this.motherId,
    this.spouseIds = const [],
    this.childIds = const [],
    required this.yearSystem,
    this.birthYear,
    this.deathYear,
    this.lifespan,
    required this.summary,
    this.summaryZhHans,
    this.summaryZhHant,
    this.refs = const [],
    this.role,
    this.accent,
    this.era,
    this.datingKind = 'approximate',
    this.datingBasis = 'conventional',
    this.datingRefs = const [],
    this.reignStart,
    this.reignEnd,
  });

  /// Locale-aware display name. Falls back across languages so we
  /// always return something non-empty.
  String localizedName(String locale) {
    if (locale == 'zh-Hant' && (nameZhHant ?? '').isNotEmpty) {
      return nameZhHant!;
    }
    if (locale.startsWith('zh') && (nameZhHans ?? '').isNotEmpty) {
      return nameZhHans!;
    }
    return name;
  }

  /// Locale-aware summary with the same fallback chain as [localizedName].
  String localizedSummary(String locale) {
    if (locale == 'zh-Hant' && (summaryZhHant ?? '').isNotEmpty) {
      return summaryZhHant!;
    }
    if (locale.startsWith('zh') && (summaryZhHans ?? '').isNotEmpty) {
      return summaryZhHans!;
    }
    return summary;
  }

  /// Render the year range as a human-readable string. AM dates get
  /// "AM" suffix; BC dates get "BC". Lifespan in parens when known.
  /// Returns empty when no birth or death year is set.
  ///
  /// [datingKind] governs what is shown. A `reign` record shows the reign
  /// and never the birth year, because the number it holds is an
  /// accession year; an `approximate` one is prefixed "c.". Every screen
  /// that prints a year goes through here, so the rule is stated once.
  String displayYears(String locale) {
    final am = yearSystem == 'am';
    final isZh = locale.startsWith('zh');
    if (datingKind == 'reign' && reignStart != null) {
      return _displayReign(locale, isZh);
    }
    String fmt(int? y) {
      if (y == null) return '';
      if (am) return annoMundiLabel(y, locale);
      if (y < 0) {
        // BC → 公元前 (Simplified) / 公元前 (Traditional, same chars)
        if (isZh) return '公元前 ${-y} 年';
        return '${-y} BC';
      }
      // AD → 公元 (Simplified) / 西元 (sometimes used in Traditional;
      // 公元 is also widely accepted on Taiwan / HK so use it for
      // consistency with 公元前 above).
      if (isZh) return '公元 $y 年';
      return 'AD $y';
    }
    final b = fmt(birthYear);
    final d = fmt(deathYear);
    String range;
    if (b.isNotEmpty && d.isNotEmpty) {
      range = '$b – $d';
    } else if (b.isNotEmpty) {
      range = b;
    } else if (d.isNotEmpty) {
      range = d;
    } else {
      return '';
    }
    if (datingKind == 'approximate') {
      range = '${approximatePrefix(locale)}$range';
    }
    if (lifespan != null) {
      final yrs = locale == 'zh-Hans'
          ? '$lifespan 岁'
          : locale == 'zh-Hant'
              ? '$lifespan 歲'
              : '$lifespan years';
      return '$range  ($yrs)';
    }
    return range;
  }

  /// A reign, worded as one. Thiele's span, and never a birth year.
  String _displayReign(String locale, bool isZh) {
    String year(int y) => y < 0
        ? (isZh ? '公元前 ${-y} 年' : '${-y} BC')
        : (isZh ? '公元 $y 年' : 'AD $y');
    final start = year(reignStart!);
    if (reignEnd == null) {
      return isZh ? '$start 即位' : 'acceded $start';
    }
    final end = year(reignEnd!);
    return isZh ? '在位 $start – $end' : 'reigned $start – $end';
  }

  factory BiblicalPerson.fromJson(Map<String, dynamic> j) {
    return BiblicalPerson(
      id: j['id'] as String,
      name: j['name'] as String,
      nameZhHans: j['nameZhHans'] as String?,
      nameZhHant: j['nameZhHant'] as String?,
      nameKjv: (j['nameKjv'] as String?) ?? '',
      fatherId: j['fatherId'] as String?,
      motherId: j['motherId'] as String?,
      spouseIds: (j['spouseIds'] as List?)?.cast<String>() ?? const [],
      childIds: (j['childIds'] as List?)?.cast<String>() ?? const [],
      yearSystem: (j['yearSystem'] as String?) ?? 'bc',
      birthYear: (j['birthYear'] as num?)?.toInt(),
      deathYear: (j['deathYear'] as num?)?.toInt(),
      lifespan: (j['lifespan'] as num?)?.toInt(),
      summary: j['summary'] as String,
      summaryZhHans: j['summaryZhHans'] as String?,
      summaryZhHant: j['summaryZhHant'] as String?,
      refs: (j['refs'] as List?)?.cast<String>() ?? const [],
      role: j['role'] as String?,
      accent: j['accent'] as String?,
      era: j['era'] as String?,
      datingKind: (j['dating']?['kind'] as String?) ?? 'approximate',
      datingBasis: (j['dating']?['basis'] as String?) ?? 'conventional',
      datingRefs:
          (j['dating']?['refs'] as List?)?.cast<String>() ?? const [],
      reignStart: (j['reignStart'] as num?)?.toInt(),
      reignEnd: (j['reignEnd'] as num?)?.toInt(),
    );
  }
}
