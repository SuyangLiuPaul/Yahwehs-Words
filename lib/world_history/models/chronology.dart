/// The Genesis lifespans from Adam to Joseph, in Anno Mundi.
///
/// Backing data: `assets/world_chart/chronology.json`, built by
/// `scripts/build_chronology.py`, which reads every figure out of
/// `assets/kjv.json` and `assets/lxxwh.json` rather than holding a table
/// of its own. Each figure therefore carries the verse it was read from,
/// and the app can send a doubting reader straight to it.
///
/// Years are Anno Mundi — counted from the creation — and never BC.
/// `assets/world_chart/hebrew_kings.json` and `assets/world_chart/bible_timeline.json` use
/// negative years for BC, and these do not convert into those: fixing AM
/// against a Julian year takes an absolute anchor the text never
/// supplies. Ussher's 4004 BC is one such anchor, and one reconstruction
/// among several.
library;

/// One tradition's figures for one man.
///
/// [checked] records whether the parse that produced these numbers could
/// be verified against a third number the text states. Genesis 5 gives
/// the age at begetting, the years after, *and* the total, so a
/// mis-parse there cannot hide. Genesis 11 gives only the first two, so
/// its lifespans are sums and carry no such check. The distinction is
/// kept because a number that was verified and a number that was merely
/// added are not equally trustworthy, and the surface should be able to
/// say which is which.
class ChronologyFigures {
  const ChronologyFigures({
    required this.begatAt,
    required this.livedAfter,
    required this.lifespan,
    required this.birthAm,
    required this.deathAm,
    required this.checked,
    required this.refs,
  });

  /// His age when the next man in the line was born, or null when there
  /// is no next man — Joseph ends the chain, so the figure does not
  /// exist rather than being unknown.
  final int? begatAt;

  /// Years he lived after that, null for the same reason.
  final int? livedAfter;
  final int lifespan;
  final int birthAm;
  final int deathAm;
  final bool checked;

  /// Verse per figure, keyed `begatAt` / `livedAfter` / `lifespan`. A key
  /// is absent when the text states no such number and it was derived —
  /// absent means derived, and that is deliberately distinguishable from
  /// a verse that happens to be unknown.
  final Map<String, String> refs;

  static ChronologyFigures fromJson(Map<String, dynamic> j) =>
      ChronologyFigures(
        begatAt: (j['begatAt'] as num?)?.toInt(),
        livedAfter: (j['livedAfter'] as num?)?.toInt(),
        lifespan: (j['lifespan'] as num).toInt(),
        birthAm: (j['birthAm'] as num).toInt(),
        deathAm: (j['deathAm'] as num).toInt(),
        checked: j['checked'] == true,
        refs: {
          for (final e in ((j['refs'] as Map?) ?? const {}).entries)
            if (e.value is String) e.key.toString(): e.value as String,
        },
      );
}

class Patriarch {
  const Patriarch({
    required this.id,
    required this.line,
    required this.names,
    required this.figures,
    this.nameKjv = '',
  });

  final String id;

  /// `seth` for Genesis 5, `shem` for Genesis 11, `abraham` for Genesis
  /// 12-50, `levi` for Moses and Aaron. The printed chronologies have
  /// coloured by line of descent since the 17th century and it is the
  /// one grouping the text itself draws. The last two are not separate
  /// descents — the patriarchs are Shem's, Moses and Aaron are Jacob's —
  /// but the other ways an age reaches this chart: scattered through
  /// narrative from Genesis 12 on, and stated outside Genesis
  /// altogether. See `scripts/build_chronology.py`.
  final String line;
  final Map<String, String> names;

  /// Keyed by tradition id. Not every man is in every tradition —
  /// Kainan is in the Septuagint's Genesis 11 and not in the Hebrew's —
  /// so a missing entry means the tradition does not have him, which is
  /// itself worth showing.
  final Map<String, ChronologyFigures> figures;

  /// The Authorised Version's spelling, when it differs from the
  /// English name above; empty when the two agree.
  ///
  /// Four men have one: Enosh, Kenan, Mahalalel and Shelah, whom the
  /// KJV calls Enos, Cainan, Mahalaleel and Salah. The chart used to
  /// PRINT those four forms while `bible_timeline.json` printed the
  /// modern ones, so the wheel drew a spoke reading "Birth of Kenan"
  /// beside an arc reading "Cainan" — one man, two spellings, touching.
  /// The displayed name is now the modern one everywhere.
  ///
  /// This field is what stops that being a regression. The app ships
  /// the KJV and `kjvs.json`; a reader looking at Genesis 5:9 sees
  /// "Cainan" and types "Cainan", so the older spelling is searched
  /// wherever a name is searched and printed under the name on the
  /// sheet. Both forms are read off the shipped text and neither is
  /// invented — see `test/patriarch_spelling_test.dart`.
  ///
  /// Chinese needs no equivalent: 以挪士 / 该南 / 玛勒列 / 沙拉 are what
  /// the CUV reads and what every asset here already carried.
  final String nameKjv;

  String nameFor(String locale) => names[locale] ?? names['en'] ?? id;

  /// Every spelling this man answers to, in every script. Used by the
  /// wheel's search so that a name the app does not display is still a
  /// name the app can be asked for.
  Iterable<String> get allNames =>
      [...names.values, if (nameKjv.isNotEmpty) nameKjv];

  static Patriarch fromJson(Map<String, dynamic> j) => Patriarch(
        id: j['id'] as String,
        line: (j['line'] as String?) ?? 'seth',
        names: _localised(j['name']),
        nameKjv: (j['nameKjv'] as String?) ?? '',
        figures: {
          for (final e in ((j['figures'] as Map?) ?? const {}).entries)
            if (e.value is Map)
              e.key.toString(): ChronologyFigures.fromJson(
                  (e.value as Map).cast<String, dynamic>()),
        },
      );
}

class ChronologyTradition {
  const ChronologyTradition({
    required this.id,
    required this.names,
    required this.longNames,
    required this.floodAm,
    required this.endAm,
  });

  final String id;
  final Map<String, String> names;
  final Map<String, String> longNames;
  final int floodAm;
  final int endAm;

  String nameFor(String locale) => names[locale] ?? names['en'] ?? id;
  String longNameFor(String locale) =>
      longNames[locale] ?? longNames['en'] ?? nameFor(locale);

  static ChronologyTradition fromJson(Map<String, dynamic> j) =>
      ChronologyTradition(
        id: j['id'] as String,
        names: _localised(j['name']),
        longNames: _localised(j['longName']),
        floodAm: (j['floodAm'] as num).toInt(),
        endAm: (j['endAm'] as num).toInt(),
      );
}

class ChronologyEpoch {
  const ChronologyEpoch({
    required this.id,
    required this.names,
    required this.ref,
    required this.years,
    required this.notes,
  });

  final String id;
  final Map<String, String> names;
  final String? ref;

  /// The epoch falls in a different year in each tradition, which is the
  /// whole reason the chart offers a choice.
  final Map<String, int> years;
  final Map<String, String> notes;

  String nameFor(String locale) => names[locale] ?? names['en'] ?? id;
  String? noteFor(String locale) => notes[locale] ?? notes['en'];

  static ChronologyEpoch fromJson(Map<String, dynamic> j) => ChronologyEpoch(
        id: j['id'] as String,
        names: _localised(j['name']),
        ref: j['ref'] as String?,
        years: {
          for (final e in ((j['years'] as Map?) ?? const {}).entries)
            if (e.value is num) e.key.toString(): (e.value as num).toInt(),
        },
        notes: _localised(j['note']),
      );
}

/// A caveat the generator emitted because the numbers showed it, not
/// because anyone asserted it. See `scripts/build_chronology.py`.
class ChronologyNote {
  const ChronologyNote({
    required this.id,
    required this.tradition,
    required this.personId,
    required this.texts,
  });

  final String id;
  final String tradition;

  /// The man the caveat is about, when it is about one. This decides
  /// where the caveat is read: a note with no person is about the whole
  /// chart and is printed in the header, and a note with one is printed
  /// in that man's detail panel, with the header naming him so a reader
  /// who has selected nobody knows there is something to open. The
  /// header is a layout sibling of the chart, so every line it prints
  /// is a line the chart loses.
  final String? personId;
  final Map<String, String> texts;

  String textFor(String locale) => texts[locale] ?? texts['en'] ?? '';

  static ChronologyNote fromJson(Map<String, dynamic> j) => ChronologyNote(
        id: (j['id'] as String?) ?? '',
        tradition: (j['tradition'] as String?) ?? '',
        personId: j['personId'] as String?,
        texts: _localised(j['text']),
      );
}

/// One span the text puts a number of years to, between the exodus and
/// the temple. It has no place on the chart's axis and is not given one:
/// the text never says these periods run one after another.
class ChronologyPeriod {
  const ChronologyPeriod({
    required this.id,
    required this.kind,
    required this.names,
    required this.ref,
    required this.years,
  });

  final String id;

  /// servitude / rest / judge / reign / wilderness — what kind of span
  /// the verse is describing, which is the only ordering information
  /// available without inventing one.
  final String kind;
  final Map<String, String> names;
  final String ref;

  /// The figure each text states. The two do not always agree, and where
  /// they do not that is the finding, not an error.
  final Map<String, int> years;

  String nameFor(String locale) => names[locale] ?? names['en'] ?? id;

  static ChronologyPeriod fromJson(Map<String, dynamic> j) => ChronologyPeriod(
        id: (j['id'] as String?) ?? '',
        kind: (j['kind'] as String?) ?? '',
        names: _localised(j['name']),
        ref: (j['ref'] as String?) ?? '',
        years: {
          for (final e in ((j['years'] as Map?) ?? const {}).entries)
            if (e.value is num) e.key.toString(): (e.value as num).toInt(),
        },
      );
}

/// A stretch inside the same span that neither text puts a number to.
/// Listed because leaving it out would make the total below look complete.
class ChronologyGap {
  const ChronologyGap({
    required this.id,
    required this.ref,
    required this.notes,
  });

  final String id;
  final String ref;
  final Map<String, String> notes;

  String noteFor(String locale) => notes[locale] ?? notes['en'] ?? '';

  static ChronologyGap fromJson(Map<String, dynamic> j) => ChronologyGap(
        id: (j['id'] as String?) ?? '',
        ref: (j['ref'] as String?) ?? '',
        notes: _localised(j['note']),
      );
}

/// The whole span 1 Kings 6:1 measures, as one text states it.
class ChronologyStatedSpan {
  const ChronologyStatedSpan({
    required this.ordinal,
    required this.elapsed,
    required this.ref,
    required this.yearAt,
    required this.foundingAt,
    required this.units,
  });

  /// The year as the verse writes it — the 480th. An ordinal.
  final int ordinal;

  /// The years that have therefore run: one fewer. The subtraction is
  /// made in the generator, once, and said in words on the surface.
  final int elapsed;
  final String ref;

  /// Which of the edition's own verses states the year, and which states
  /// the founding the year is measured to. Our records are keyed on the
  /// Hebrew's numbering, so where the Greek runs several of its own
  /// verses inside one of ours these are not the same: the Greek gives
  /// the 440th year at 6:1 and the founding at 6:1c.
  final String yearAt;
  final String foundingAt;

  /// How many of the edition's own verses this one verse holds.
  final int units;

  /// The span is stated across two units rather than in one clause.
  /// Read, never asserted — see `FOUNDING_VERB` in the generator.
  bool get joined => yearAt != foundingAt;

  static ChronologyStatedSpan fromJson(Map<String, dynamic> j) =>
      ChronologyStatedSpan(
        ordinal: (j['ordinal'] as num?)?.toInt() ?? 0,
        elapsed: (j['elapsed'] as num?)?.toInt() ?? 0,
        ref: (j['ref'] as String?) ?? '',
        yearAt: (j['yearAt'] as String?) ?? '',
        foundingAt: (j['foundingAt'] as String?) ?? '',
        units: (j['units'] as num?)?.toInt() ?? 1,
      );
}

/// From the exodus to the temple: the era the text counts twice and does
/// not reconcile with itself. Counted, never plotted — see
/// `scripts/build_chronology.py`.
class ChronologyEra {
  const ChronologyEra({
    required this.id,
    required this.names,
    required this.stated,
    required this.counted,
    required this.residue,
    required this.splitIds,
    required this.periods,
    required this.gaps,
    required this.summary,
    required this.divergence,
  });

  final String id;
  final Map<String, String> names;
  final Map<String, ChronologyStatedSpan> stated;

  /// The periods below, added up, per tradition.
  final Map<String, int> counted;

  /// [counted] less the stated span. Positive means the figures the text
  /// states overrun the total the text states.
  final Map<String, int> residue;

  /// The periods the two texts number differently.
  final List<String> splitIds;
  final List<ChronologyPeriod> periods;
  final List<ChronologyGap> gaps;
  final Map<String, String> summary;
  final Map<String, String> divergence;

  String nameFor(String locale) => names[locale] ?? names['en'] ?? id;
  String summaryFor(String locale) => summary[locale] ?? summary['en'] ?? '';
  String divergenceFor(String locale) =>
      divergence[locale] ?? divergence['en'] ?? '';

  static ChronologyEra fromJson(Map<String, dynamic> j) => ChronologyEra(
        id: (j['id'] as String?) ?? '',
        names: _localised(j['name']),
        stated: {
          for (final e in ((j['stated'] as Map?) ?? const {}).entries)
            if (e.value is Map)
              e.key.toString(): ChronologyStatedSpan.fromJson(
                  (e.value as Map).cast<String, dynamic>()),
        },
        counted: {
          for (final e in ((j['counted'] as Map?) ?? const {}).entries)
            if (e.value is num) e.key.toString(): (e.value as num).toInt(),
        },
        residue: {
          for (final e in ((j['residue'] as Map?) ?? const {}).entries)
            if (e.value is num) e.key.toString(): (e.value as num).toInt(),
        },
        splitIds: ((j['splitIds'] as List?) ?? const [])
            .whereType<String>()
            .toList(),
        periods: ((j['periods'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(ChronologyPeriod.fromJson)
            .toList(),
        gaps: ((j['unnumbered'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(ChronologyGap.fromJson)
            .toList(),
        summary: _localised(j['summary']),
        divergence: _localised(j['divergence']),
      );
}

/// How the chart knows what it draws.
///
/// The generator has written all of this into the asset's `_meta` block
/// since the module shipped, and until now the app rendered none of it:
/// which editions the figures were read out of, what "checked" means and
/// how many figures carry it, how far the two texts actually diverge, and
/// that a second artefact built by a different script agrees. A chart of
/// dates is the most persuasive thing this app draws, so the answer to
/// "how do you know" has to be reachable from it.
///
/// Every string here is localised, because printing them in English is
/// the same defect as not printing them — a Chinese reader could not read
/// the answer either way. The asset paths are deliberately NOT part of
/// the prose: a path cannot be translated, and naming the edition sends
/// the reader to something they can actually open in this app.
class ChronologyProvenance {
  const ChronologyProvenance({
    required this.traditionsNote,
    required this.sources,
    required this.sumsChecked,
    required this.checksNote,
    required this.traditionAgreement,
    required this.secondWitness,
    required this.disagreements,
  });

  /// Why two texts are charted, and why the Samaritan Pentateuch is not.
  final Map<String, String> traditionsNote;

  /// Tradition id -> the localised sentence naming the edition its
  /// figures were read out of.
  final Map<String, Map<String, String>> sources;

  /// How many figures were checked against a third number the verse
  /// itself states, across both texts.
  final int sumsChecked;
  final Map<String, String> checksNote;
  final Map<String, String> traditionAgreement;
  final Map<String, String> secondWitness;

  /// Where the second witness and this chart disagree. The generator
  /// fails rather than emitting one, so this is empty in every shipped
  /// asset — and the surface still states the count, because "none" is a
  /// result and an absent line is not.
  final List<String> disagreements;

  String traditionsNoteFor(String locale) => _pick(traditionsNote, locale);
  String checksNoteFor(String locale) => _pick(checksNote, locale);
  String traditionAgreementFor(String locale) =>
      _pick(traditionAgreement, locale);
  String secondWitnessFor(String locale) => _pick(secondWitness, locale);
  String sourceFor(String traditionId, String locale) =>
      _pick(sources[traditionId] ?? const {}, locale);

  static String _pick(Map<String, String> m, String locale) =>
      m[locale] ?? m['en'] ?? '';

  static ChronologyProvenance fromMeta(Map<String, dynamic> meta) {
    final checks = ((meta['checks'] as Map?) ?? const {}).cast<String, dynamic>();
    final derived =
        ((meta['derivedFrom'] as Map?) ?? const {}).cast<String, dynamic>();
    return ChronologyProvenance(
      traditionsNote: _localised(meta['traditions']),
      sources: {
        for (final e in derived.entries)
          if (e.value is Map)
            e.key: _localised((e.value as Map)['text']),
      },
      sumsChecked: (checks['sumsChecked'] as num?)?.toInt() ?? 0,
      checksNote: _localised(checks['note']),
      traditionAgreement: _localised(checks['traditionAgreement']),
      secondWitness: _localised(checks['secondWitness']),
      disagreements:
          ((checks['disagreements'] as List?) ?? const []).map((e) => '$e').toList(),
    );
  }
}

class ChronologyData {
  const ChronologyData({
    required this.traditions,
    required this.epochs,
    required this.notes,
    required this.patriarchs,
    required this.era,
    required this.unitNotes,
    required this.provenance,
  });

  final List<ChronologyTradition> traditions;
  final List<ChronologyEpoch> epochs;
  final List<ChronologyNote> notes;
  final List<Patriarch> patriarchs;

  /// Absent only if the asset predates the era block; every surface that
  /// reads it must cope with that rather than assume.
  final ChronologyEra? era;
  /// The caveat that stops the axis being read as a BC dating. It is the
  /// one string in the asset's `_meta` block the app prints, so it is the
  /// one that has to exist in the reader's script.
  final Map<String, String> unitNotes;
  final ChronologyProvenance provenance;

  String unitNoteFor(String locale) =>
      unitNotes[locale] ?? unitNotes['en'] ?? '';

  ChronologyTradition traditionById(String id) =>
      traditions.firstWhere((t) => t.id == id, orElse: () => traditions.first);

  /// Everyone the given tradition actually has figures for, in
  /// generational order.
  List<Patriarch> inTradition(String traditionId) =>
      patriarchs.where((p) => p.figures.containsKey(traditionId)).toList();

  List<ChronologyNote> notesFor(String traditionId) =>
      notes.where((n) => n.tradition == traditionId).toList();

  List<ChronologyNote> notesForPerson(String traditionId, String personId) =>
      notes
          .where((n) => n.tradition == traditionId && n.personId == personId)
          .toList();

  Patriarch? byId(String id) {
    for (final p in patriarchs) {
      if (p.id == id) return p;
    }
    return null;
  }

  static ChronologyData fromJson(Map<String, dynamic> j) {
    final meta = ((j['_meta'] as Map?) ?? const {}).cast<String, dynamic>();
    return ChronologyData(
      traditions: ((j['traditions'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ChronologyTradition.fromJson)
          .toList(),
      epochs: ((j['epochs'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ChronologyEpoch.fromJson)
          .toList(),
      notes: ((j['notes'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ChronologyNote.fromJson)
          .toList(),
      patriarchs: ((j['patriarchs'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(Patriarch.fromJson)
          .toList(),
      era: j['era'] is Map
          ? ChronologyEra.fromJson((j['era'] as Map).cast<String, dynamic>())
          : null,
      unitNotes: _localised(meta['unitNote']),
      provenance: ChronologyProvenance.fromMeta(meta),
    );
  }
}

Map<String, String> _localised(Object? raw) => {
      for (final e in ((raw as Map?) ?? const {}).entries)
        if (e.value is String) e.key.toString(): e.value as String,
    };
