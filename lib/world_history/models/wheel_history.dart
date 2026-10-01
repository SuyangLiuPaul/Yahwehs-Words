/// `assets/world_chart/wheel_history.json` — world history for the chronology
/// wheel, plus the powers of the biblical world drawn as bands.
///
/// It is HALF the wheel's dataset. An earlier version of this comment
/// described the file as "the stretch the wheel covers after
/// `bible_timeline.json` ends (AD 95)", which described a division of
/// labour that was never implemented: the page loaded this file and
/// only this file, so the wheel drew Hammurabi and Confucius and the
/// First Olympiad while the Exodus, the divided kingdom, the fall of
/// Jerusalem and the whole New Testament were missing from it. The
/// `israel` and `judah` bands held 18 records between them, none of
/// them the story the bands are named for. [bibleNarrativeEvents] is
/// the missing half — the 105 events of `assets/world_chart/bible_timeline.json`
/// mapped onto these bands and merged at load — and it exists so that
/// the wheel's whole point, synchronism, works in the direction that
/// matters: the reader sees Hammurabi BESIDE the patriarchs.
///
/// Most of the file is a well-known historical fact at its conventional
/// date, selected and worded by this project. But NOT all of it, and an
/// earlier version of this comment said otherwise — "nothing is read out
/// of scripture, so nothing here carries a verse". That was false when it
/// was written: all 82 nations are read out of Genesis 10, 55 event
/// references cite scripture, and 24 of the 62 powers carry the verses
/// their span was read from. The comment was not merely stale, it was
/// load-bearing — [WheelPower] was written to match it and so parsed
/// neither `basis` nor `ref`/`refs`, which left the three Israelite
/// kingdoms telling the reader their dates were "not stated in
/// scripture" while the asset held the very verses. A wrong comment
/// about the data becomes a wrong claim to the reader.
///
/// So: every record says what its date rests on, in [WheelPower.basis]
/// and [WheelHistoryEvent.basis], and the wheel prints that rather than
/// assuming. Model and loader share a file because the payload is flat
/// lists.
library;

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'package:yahwehs_words/world_history/models/biblical_person.dart';
import 'package:yahwehs_words/world_history/models/timeline_event.dart';
import 'package:yahwehs_words/world_history/services/chronology_service.dart';
import 'package:yahwehs_words/world_history/services/family_tree_service.dart';
import 'package:yahwehs_words/world_history/models/hebrew_king.dart';
import 'package:yahwehs_words/world_history/services/hebrew_kings_service.dart';
import 'package:yahwehs_words/world_history/services/timeline_service.dart';


/// One concentric band of the wheel.
///
/// The engraved chronologies organise by NATION and INSTITUTION rather
/// than by kind-of-event: Israel is a band, Rome is a band, the church
/// is a band, and every dated thing is drawn on the band it belongs to.
/// That is what lets a reader follow one people down the centuries
/// instead of reading a single undifferentiated stream of dates.
///
/// [line] is the Genesis 10 descent the band is coloured by — the same
/// organising idea, and one this app can take because its root is
/// scripture (Genesis 10) rather than anyone's compiled chart. Two
/// values are not descents: 'institution' (the church, the text of
/// scripture) and 'none'.
class WheelStream {
  const WheelStream({
    required this.id,
    required this.line,
    required this.names,
  });

  final String id;
  final String line;
  final Map<String, String> names;

  String nameFor(String locale) => names[locale] ?? names['en'] ?? id;

  static WheelStream fromJson(Map<String, dynamic> j) => WheelStream(
        id: j['id'] as String,
        line: (j['line'] as String?) ?? 'none',
        names: _localised(j['name']),
      );
}

/// One name from the table of nations, Genesis 10 (and the line of Shem
/// through Genesis 11).
///
/// These are not dated — the text gives no years for them — so the
/// wheel draws them as the descent behind a band rather than as points
/// on the axis. Every one carries [ref], the verse it was read from,
/// which is the whole reason this table is worth shipping: a reader who
/// doubts a name can be sent straight to it.
class WheelNation {
  const WheelNation({
    required this.id,
    required this.line,
    required this.father,
    required this.generation,
    required this.stream,
    required this.ref,
    required this.names,
    required this.notes,
    this.nameKjv = '',
  });

  final String id;
  final String line;

  /// Empty for Shem, Ham and Japheth themselves.
  final String father;
  final int generation;
  final String stream;
  final String ref;
  final Map<String, String> names;
  final Map<String, String> notes;

  /// The Authorised Version's spelling, when it differs from the
  /// English name; empty when the two agree.
  ///
  /// One band of the 82 has one, and it is the sharpest case in the
  /// asset because this table exists to cite verses. The band's own
  /// [ref] is Genesis 10:24, which the KJV reads "Salah" and the BSB,
  /// NASB and LEB all read "Shelah". The band displays the modern form,
  /// because that is what a reader of four of the five English editions
  /// this app ships will see, and carries the KJV's here so that the
  /// name it does not print is still a name it can be asked for. What
  /// the verse actually reads in which edition is spelled out in
  /// [notes] rather than left for the reader to reconcile.
  final String nameKjv;

  String nameFor(String locale) => names[locale] ?? names['en'] ?? id;
  String noteFor(String locale) => notes[locale] ?? notes['en'] ?? '';

  static WheelNation fromJson(Map<String, dynamic> j) => WheelNation(
        id: j['id'] as String,
        line: (j['line'] as String?) ?? 'none',
        father: (j['father'] as String?) ?? '',
        generation: (j['generation'] as num?)?.toInt() ?? 0,
        stream: (j['stream'] as String?) ?? 'world',
        ref: (j['ref'] as String?) ?? '',
        names: _localised(j['name']),
        nameKjv: (j['nameKjv'] as String?) ?? '',
        notes: _localised(j['note']),
      );
}

/// One power of the biblical world, drawn as an arc band.
class WheelPower {
  const WheelPower({
    required this.id,
    required this.start,
    required this.end,
    required this.region,
    required this.stream,
    required this.basis,
    required this.approximate,
    required this.refs,
    required this.names,
    required this.notes,
  });

  final String id;

  /// Where it was, in the asset's twelve-value vocabulary.
  ///
  /// READ SINCE 2026-09-02, and it was not before. The disclosure test
  /// excused it as unread on the grounds that it was "very nearly a
  /// function of stream" — 20 of the 22 streams mapped to exactly one
  /// region. Adding 42 pontificates and five crusades broke that: the
  /// church band now runs through `europe` AND `levant`, because the
  /// papacy and the crusades genuinely happened in different places.
  /// A field that carries information and is never shown is
  /// information held back, so the power sheet shows it.
  final String region;

  /// The band this power is drawn on.
  final String stream;

  /// What the SPAN rests on: 'scripture', 'scripture+thiele' or
  /// 'conventional' — the same three values, and the same reason, as
  /// [WheelHistoryEvent.basis]. Stored on all 62 powers since the asset
  /// was compiled; 3 of them are `scripture+thiele` (the united
  /// monarchy, and the kingdoms of Israel and Judah), and until this
  /// field existed the wheel printed "conventional date, not stated in
  /// scripture" over all three.
  final String basis;

  /// True when references genuinely differ on the span, or it is a
  /// rounded century. Written explicitly in the data on every entry —
  /// an absent flag must not be the way "settled" is expressed.
  final bool approximate;

  /// The verses the span was read from, empty for a power dated only by
  /// convention. The asset spells this `ref` on the 10 records with one
  /// verse and `refs` on the 14 with several; both are read here into
  /// one list, because two spellings for one idea is how 42 references
  /// came to be stored and never shown.
  final List<String> refs;

  /// Astronomical years: negative is BC, and there is no year zero to
  /// worry about at this resolution — every span here is conventional
  /// and rounded already.
  final int start;

  /// Null for a power that has not ended. The alternative was to write
  /// this year into the data, which reads as "the state of Israel ended
  /// in 2026" and silently becomes a lie every January — an invented
  /// date in all but name. A band with no end is drawn to the axis end
  /// and labelled "present".
  final int? end;
  final Map<String, String> names;
  final Map<String, String> notes;

  bool get ongoing => end == null;

  /// The year to DRAW the band's end at, given where the axis stops.
  int endFor(int axisEnd) => end ?? axisEnd;

  String nameFor(String locale) => names[locale] ?? names['en'] ?? id;
  String noteFor(String locale) => notes[locale] ?? notes['en'] ?? '';

  static WheelPower fromJson(Map<String, dynamic> j) => WheelPower(
        id: j['id'] as String,
        start: (j['start'] as num).toInt(),
        end: (j['end'] as num?)?.toInt(),
        region: (j['region'] as String?) ?? '',
        stream: (j['stream'] as String?) ?? 'world',
        basis: (j['basis'] as String?) ?? 'conventional',
        approximate: j['approximate'] == true,
        refs: [
          if (j['ref'] is String && (j['ref'] as String).isNotEmpty)
            j['ref'] as String,
          ...((j['refs'] as List?) ?? const []).whereType<String>(),
        ],
        names: _localised(j['name']),
        notes: _localised(j['note']),
      );
}

/// A ministry: the years one prophet, apostle or named ruler is placed
/// in, as an arc in the same annulus the Genesis lifespans and the
/// reigns are drawn in.
///
/// A MINISTRY IS NOT A LIFE, and the distinction is the reason this
/// class exists rather than a `WheelPower` with a different colour.
/// Scripture almost never gives a prophet a birth or a death; what it
/// gives is the reigns he prophesied under (Isaiah 1:1) or a regnal
/// year it dates a word to (Jeremiah 1:2, Ezekiel 1:2). So the span is
/// a ministry, the note says how it was reached, and [anchorKings]
/// carries the reigns it was reached FROM.
///
/// [anchorKings] IS NOT A FORMULA, and reading it as one is the first
/// mistake anyone will make with this field. Six of the anchored rows
/// really are the union of the reigns they name and one (Amos) is the
/// intersection, because Amos 1:1 names Uzziah and Jeroboam II
/// CONCURRENTLY. The other nine are not either: Ezekiel runs to the
/// twenty-seventh year of his own exile (Ezekiel 29:17), which is
/// fifteen years past the end of the last reign he names, and Huldah is
/// one day in Josiah's eighteenth year. What holds for every anchored
/// row is weaker and true: the span OVERLAPS the reigns it cites.
/// `wheel_ministries_test.dart` pins the strong claim only where the
/// note makes it.
class WheelMinistry {
  const WheelMinistry({
    required this.id,
    required this.start,
    required this.end,
    required this.region,
    required this.stream,
    required this.basis,
    required this.approximate,
    required this.refs,
    required this.anchorKings,
    required this.names,
    required this.notes,
  });

  final String id;

  /// Astronomical years, negative for BC. Unlike [WheelPower.end] this
  /// is never null: every ministry here has ended.
  final int start;
  final int end;

  /// Where it happened — the same vocabulary the powers use.
  final String region;

  /// The band this ministry belongs to for search and filtering. Every
  /// prophet and apostle is on `scripture` or `church` rather than on
  /// the political band of the kingdom he prophesied to, and that is
  /// deliberate twice over: it is what he actually is, and it keeps
  /// `wheel_history_integrity_test.dart`'s "a king the wheel names must
  /// be inside his reign" check off him — Zechariah the prophet (-520)
  /// and Zechariah king of Israel (-753) are one name and two men.
  final String stream;

  /// 'scripture+thiele' or 'conventional'. NEVER 'scripture': scripture
  /// states no BC year for anyone, so a bare `scripture` on a span
  /// would be a claim the text does not make. Pinned in the test.
  final String basis;

  final bool approximate;

  /// The verses that FIX the span — not every verse about the man.
  final List<String> refs;

  /// The `hebrew_kings.json` ids the span was reached from. Empty for
  /// the rows that rest on the Persian or Roman king-lists instead.
  final List<String> anchorKings;

  final Map<String, String> names;
  final Map<String, String> notes;

  String nameFor(String locale) => names[locale] ?? names['en'] ?? id;
  String noteFor(String locale) => notes[locale] ?? notes['en'] ?? '';

  static WheelMinistry fromJson(Map<String, dynamic> j) => WheelMinistry(
        id: j['id'] as String,
        start: (j['start'] as num).toInt(),
        end: (j['end'] as num).toInt(),
        region: (j['region'] as String?) ?? 'levant',
        stream: (j['stream'] as String?) ?? 'scripture',
        basis: (j['basis'] as String?) ?? 'conventional',
        approximate: j['approximate'] == true,
        refs: ((j['refs'] as List?) ?? const []).whereType<String>().toList(),
        anchorKings:
            ((j['anchorKings'] as List?) ?? const []).whereType<String>().toList(),
        names: _localised(j['name']),
        notes: _localised(j['note']),
      );
}

/// A record whose whole content is that this chart draws NOTHING, and
/// why.
///
/// THE ABSENCE WAS ALREADY A DECISION; what it was not was a disclosed
/// one. Twelve of the seventeen prophetic books have a ministry arc and
/// Malachi has a dated event, so a reader who works down the prophets
/// and reaches Joel finds silence — and silence from a search box does
/// not read as "the text supplies no anchor", it reads as an oversight.
/// The rule this file has followed since its first commit is that a
/// year is never invented; the rule it had not followed is that the
/// refusal has to be visible to the person it is being made for.
///
/// THREE RECORDS, NOT ONE, and the count was measured rather than
/// assumed — see `wheel_omissions_test.dart`, which asks the corpus
/// which prophetic books reach no record at all in any of the three
/// scripts. Joel, Obadiah and Habakkuk are the answer, and each note
/// says what its own book withholds, because the three are not the same
/// case: Joel's superscription simply stops, Obadiah's verse 11 names a
/// day without saying which day, and Habakkuk 1:6 names a nation still
/// to be raised up, which is half of the bracket Nahum got a span from.
///
/// NO YEAR, NO SPAN, NO STREAM, and all three absences are the point.
/// A `start`/`end` here would be the fabrication the record exists to
/// refuse; a `stream` would put it on a band, and a band can be
/// switched off, which would let a filter the reader set for the CHART
/// hide a statement about something the chart does not draw. So the
/// hit carries an empty `streamId` and can never be flagged hidden.
///
/// Everything else a wheel record has, it has: an id, the three names,
/// the note in three scripts, and the verses — so the reader who wants
/// to check the claim can open the very verse the claim is about.
class WheelOmission {
  const WheelOmission({
    required this.id,
    required this.refs,
    required this.names,
    required this.notes,
  });

  final String id;

  /// The verses the note reasons FROM — the superscription that names
  /// no king, and the one verse in the book that comes nearest to an
  /// anchor. Tappable on the sheet, like every other reference here.
  final List<String> refs;

  final Map<String, String> names;
  final Map<String, String> notes;

  String nameFor(String locale) => names[locale] ?? names['en'] ?? id;
  String noteFor(String locale) => notes[locale] ?? notes['en'] ?? '';

  static WheelOmission fromJson(Map<String, dynamic> j) => WheelOmission(
        id: j['id'] as String,
        refs: ((j['refs'] as List?) ?? const []).whereType<String>().toList(),
        names: _localised(j['name']),
        notes: _localised(j['note']),
      );
}

/// One person a wheel event names, resolved at merge time.
///
/// The names are COPIED rather than looked up at paint time, and that
/// is the point of the class. `FamilyTreeService.byId` is synchronous
/// and returns null until its own load has finished, so a chip that
/// resolved itself while drawing would render empty for one frame and
/// — worse — the search running beside it would agree, reporting an
/// absence that was really a race. [bibleNarrativeEvents] takes the
/// people as an argument, so by the time any wheel record exists its
/// links are already resolved or already dropped, and both the chip
/// and the haystack read the same resolved list.
class WheelPersonLink {
  const WheelPersonLink({
    required this.id,
    required this.names,
    this.nameKjv = '',
  });

  /// The Authorised Version's spelling of this person, when it differs
  /// from the English one; empty otherwise. Carried for the same reason
  /// the three scripts are: the chip prints one spelling and the reader
  /// may be typing another, and this app ships the edition that uses
  /// the other one.
  final String nameKjv;

  /// `family_tree.json` id. Held so a tap can open the real record;
  /// never shown.
  final String id;

  /// Locale → display name, `en` always present.
  final Map<String, String> names;

  String nameFor(String locale) => names[locale] ?? names['en'] ?? id;

  /// Every script this person is written in, for the search haystack.
  /// The chip renders one and the reader may be typing another — and
  /// the one the reader has in front of them may be the KJV's, which is
  /// never displayed here and is still searchable.
  Iterable<String> get allNames =>
      [...names.values, if (nameKjv.isNotEmpty) nameKjv];
}

/// One dated event, drawn on the band of the stream it belongs to.
class WheelHistoryEvent {
  const WheelHistoryEvent({
    required this.id,
    required this.year,
    required this.era,
    required this.stream,
    required this.basis,
    required this.approximate,
    required this.refs,
    required this.titles,
    required this.descs,
    this.datingRefs = const [],
    this.septuagintYear,
    this.timelineEra,
    this.people = const [],
  });

  final String id;
  final int year;

  /// `church`, `bible` or `world` — which of the three threads the
  /// event belongs to.
  final String era;

  /// The band this event is drawn on.
  final String stream;

  /// What the year rests on: 'scripture', 'scripture+thiele',
  /// 'thiele' or 'conventional'. The wheel says so on every detail
  /// sheet, because
  /// a date the text states and a date a reference supplies are not
  /// equally strong and the reader is entitled to know which is which.
  final String basis;

  final bool approximate;
  final List<String> refs;
  final Map<String, String> titles;
  final Map<String, String> descs;

  /// The four fields below arrive only from [bibleNarrativeEvents];
  /// `wheel_history.json` has no record carrying any of them, so
  /// [fromJson] does not look for them. They are the apparatus that
  /// makes a derived year checkable, and the wheel inherited the years
  /// without it: 18 of the merged events state an interval the reader
  /// could not see the verses for, and 8 printed one year where the
  /// timeline page prints two.

  /// The verses whose intervals the year was counted along — NOT
  /// [refs], which is where the event is narrated. See
  /// [TimelineEvent.datingRefs]: on nine of them the two sets name no
  /// chapter in common.
  final List<String> datingRefs;

  /// Where the year falls if Exodus 12:40 is read as the Septuagint
  /// reads it. Null unless the chain runs through that verse.
  final int? septuagintYear;

  /// The era of `bible_timeline.json` this came from, or null for the
  /// wheel's own records. Carried for one reason: `antediluvian` marks
  /// the eight events that are NOT counted back from the Thiele
  /// anchor, and a wheel that draws them on the same axis as the ones
  /// that are owes the reader the same seam note the timeline page
  /// gives. [era] cannot answer this — the merge sets it to `bible`.
  final String? timelineEra;

  /// The people this event names, in the asset's own order.
  ///
  /// `bible_timeline.json` files `personIds` on 68 of its 105 events —
  /// 88 links naming 37 people — and for four phases the merge dropped
  /// them at the constructor, which is the same failure #318 phase 19
  /// fixed for `datingRefs` one field earlier. The consequence here was
  /// not only a missing row: the wheel's search reads the record text,
  /// and FIVE of the 37 (Aaron, Amram, Jeconiah, Jochebed, Miriam) are
  /// named by no title or description anywhere in the wheel's 588
  /// records, in any of the three scripts. Measured through
  /// `searchWheel` itself, the wheel answered "no results" for each of
  /// them while holding records that name them.
  ///
  /// This is the wheel's half of what BibleWorks' Timeline calls the
  /// event context menu (`bwh39`), where one caption carries both verse
  /// lookups and named-entity lookups into a resource. We keep the two
  /// kinds in separate labelled rows rather than one menu, because a
  /// verse chip navigates the reader out to the text and a person chip
  /// does not.
  final List<WheelPersonLink> people;

  String titleFor(String locale) => titles[locale] ?? titles['en'] ?? id;
  String descFor(String locale) => descs[locale] ?? descs['en'] ?? '';

  static WheelHistoryEvent fromJson(Map<String, dynamic> j) =>
      WheelHistoryEvent(
        id: j['id'] as String,
        year: (j['year'] as num).toInt(),
        era: (j['era'] as String?) ?? 'church',
        stream: (j['stream'] as String?) ?? 'world',
        basis: (j['basis'] as String?) ?? 'conventional',
        approximate: j['approximate'] == true,
        refs: ((j['refs'] as List?) ?? const []).whereType<String>().toList(),
        titles: _localised(j['title']),
        descs: _localised(j['desc']),
      );
}

/// The file's own header, and the only place the wheel says where its
/// dates come from and where it stops.
class WheelHistoryMeta {
  const WheelHistoryMeta({
    required this.provenance,
    required this.coverage,
    required this.scope,
    required this.axis,
  });

  final Map<String, String> provenance;
  final Map<String, String> coverage;
  final Map<String, String> scope;
  final Map<String, String> axis;

  String provenanceFor(String locale) => _pick(provenance, locale);
  String coverageFor(String locale) => _pick(coverage, locale);
  String scopeFor(String locale) => _pick(scope, locale);
  String axisFor(String locale) => _pick(axis, locale);

  static const WheelHistoryMeta empty =
      WheelHistoryMeta(provenance: {}, coverage: {}, scope: {}, axis: {});

  static WheelHistoryMeta fromJson(Map<String, dynamic> j) => WheelHistoryMeta(
        provenance: _localised(j['provenance']),
        coverage: _localised(j['coverage']),
        scope: _localised(j['scope']),
        axis: _localised(j['axis']),
      );
}

class WheelHistoryData {
  const WheelHistoryData({
    required this.streams,
    required this.nations,
    required this.powers,
    required this.ministries,
    required this.omissions,
    required this.events,
    required this.meta,
  });

  final List<WheelStream> streams;
  final List<WheelNation> nations;
  final List<WheelPower> powers;
  final List<WheelMinistry> ministries;

  /// The records that state an absence — see [WheelOmission]. Not a
  /// sixth thing the wheel DRAWS: nothing here reaches the painter, and
  /// `packWheelBand` is never given this list. It exists so the search
  /// box can answer for something the chart deliberately leaves blank.
  final List<WheelOmission> omissions;
  final List<WheelHistoryEvent> events;
  final WheelHistoryMeta meta;

  /// The nations whose descent feeds one band, in generational order —
  /// what a reader sees when they open a band and ask "who is this?"
  List<WheelNation> nationsOf(String streamId) =>
      nations.where((n) => n.stream == streamId).toList()
        ..sort((a, b) => a.generation.compareTo(b.generation));

  List<WheelPower> powersOf(String streamId) =>
      powers.where((p) => p.stream == streamId).toList();

  List<WheelMinistry> ministriesOf(String streamId) =>
      ministries.where((m) => m.stream == streamId).toList();

  WheelMinistry? ministryById(String id) {
    for (final m in ministries) {
      if (m.id == id) return m;
    }
    return null;
  }

  WheelOmission? omissionById(String id) {
    for (final o in omissions) {
      if (o.id == id) return o;
    }
    return null;
  }

  List<WheelHistoryEvent> eventsOf(String streamId) =>
      events.where((e) => e.stream == streamId).toList();

  static WheelHistoryData fromJson(Map<String, dynamic> j) =>
      WheelHistoryData(
        streams: ((j['streams'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(WheelStream.fromJson)
            .toList(),
        nations: ((j['nations'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(WheelNation.fromJson)
            .toList(),
        powers: ((j['powers'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(WheelPower.fromJson)
            .toList()
          ..sort((a, b) => a.start.compareTo(b.start)),
        ministries: ((j['ministries'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(WheelMinistry.fromJson)
            .toList()
          ..sort((a, b) => a.start.compareTo(b.start)),
        // NOT sorted. Every other list here sorts by year, and these
        // records have none — sorting them by anything would be
        // asserting an order the data does not carry. They come back in
        // the order the asset writes them, which is the order of the
        // books.
        omissions: ((j['omissions'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(WheelOmission.fromJson)
            .toList(),
        events: ((j['events'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(WheelHistoryEvent.fromJson)
            .toList()
          ..sort((a, b) => a.year.compareTo(b.year)),
        meta: WheelHistoryMeta.fromJson(
            ((j['_meta'] as Map?) ?? const {}).cast<String, dynamic>()),
      );
}

Map<String, String> _localised(Object? raw) => {
      for (final e in ((raw as Map?) ?? const {}).entries)
        if (e.value is String) e.key.toString(): e.value as String,
    };

String _pick(Map<String, String> m, String locale) =>
    m[locale] ?? m['en'] ?? '';

/// Prefix on every id [bibleNarrativeEvents] produces. The two assets
/// were compiled separately and share no id today, but nothing stops
/// one of them adding `exile` or `jonah` tomorrow, and a collision
/// would show as the wrong detail sheet rather than as a crash.
const String kBibleEventIdPrefix = 'bible:';

/// Which band each timeline era is drawn on. The wheel organises by
/// PEOPLE, not by kind-of-event, so the mapping is a question about
/// whose history the event belongs to, not about its subject.
///
/// `antediluvian` goes to `world` — the residual band, the one whose
/// Genesis 10 line is `none` and which already carries the Iron Age
/// and the Bantu expansion. Creation, the Flood and Babel belong to
/// no one people for the same reason those do: they are before the
/// peoples, and Babel is where the peoples the other bands are named
/// for begin. Its English label reads "Elsewhere", which fits a
/// migration better than it fits the Creation; renaming a band that
/// 54 existing events are correctly on is a bigger change than this
/// merge, so it is left alone and noted here.
const Map<String, String> kTimelineEraStream = {
  'antediluvian': 'world',
  'patriarchs': 'israel',
  'mosaic': 'israel',
  'conquest': 'israel',
  'monarchy': 'israel',
  'exile': 'judah',
  'intertestamental': 'judah',
  'nt': 'judah',
};

/// The records whose era answers the question wrongly.
///
/// Two boundaries the era key cannot see. After 931 BC `monarchy`
/// covers two kingdoms, and Hezekiah, Isaiah, Jeremiah and Josiah are
/// southern — leaving them on `israel` would draw Josiah's reform on a
/// band whose kingdom had fallen a century earlier. (The four are the
/// whole southern set: the other post-931 `monarchy` records — Elijah,
/// Elisha, Jonah, the fall of Samaria — are northern and stay.) And
/// `nt` spans Pentecost: everything up to the Ascension happened to
/// Judea and is drawn there, everything from Acts 2 onward is the
/// church's own history, which is why the wheel's church band
/// otherwise began in AD 64 with the fire of Rome.
///
/// Two records the era describes correctly and the band would not.
/// Job is dated to the patriarchal era but the record's own text puts
/// him outside the family — "a righteous man from Uz … no Mosaic law,
/// Tabernacle, or Levitical priesthood in view" — so drawing him on
/// Israel's band would be the app contradicting its own description.
/// And the Septuagint is not an event in Judah's history but in the
/// text's: the `scripture` band is where Qumran, P52 and the Vulgate
/// already are, and it had no record of the Greek Old Testament at all.
const Map<String, String> kTimelineStreamOverrides = {
  'job_trial': 'world',
  'hezekiah_reform': 'judah',
  'isaiah': 'judah',
  'jeremiah': 'judah',
  'josiah_reform': 'judah',
  'septuagint': 'scripture',
  'pentecost': 'church',
  'stephen_martyred': 'church',
  'paul_converted': 'church',
  'paul_journeys': 'church',
  'jerusalem_council': 'church',
  'paul_rome': 'church',
  'john_patmos': 'church',
};

/// Timeline events the wheel already tells, listed by name so a test
/// fails if either asset moves.
///
/// One entry: `temple_destroyed` (AD 70) is `jerusalem_destroyed` on
/// the wheel's `judah` band, same year, and the wheel's record carries
/// the surrounding revolt (AD 66) and Masada (AD 73) with it. Reading
/// the wheel's 133 records in −2400…AD 150 against all 98 timeline
/// records turned up no other pair naming one fact.
const Set<String> kTimelineIdsAlreadyOnWheel = {'temple_destroyed'};

/// The Bible's own narrative, shaped for the wheel.
///
/// Pure so it can be measured without a binding. [refs] carries only
/// where the event is NARRATED — [TimelineEvent.datingRefs], the
/// verses a derived year was counted along, is a different claim and
/// belongs beside the year rather than in the wheel's jump list. It
/// travels in [WheelHistoryEvent.datingRefs] and is printed under its
/// own label; for three phases it did not travel at all, which left
/// the wheel saying "interval from scripture" over a chip list that
/// states no interval.
///
/// [people] is `family_tree.json`, passed in rather than looked up, so
/// this stays pure and so the resolution happens once at load instead
/// of once per paint. An id the tree does not hold is DROPPED here
/// rather than carried as a name-less chip:
/// `test/timeline_person_join_test.dart` asserts all 88 resolve, so a
/// drop means the assets have moved apart, and a chip that cannot open
/// anything is worse than an absent one.
///
/// EVERY field of [TimelineEvent] must be accounted for here.
/// `test/wheel_timeline_field_coverage_test.dart` reads that class's
/// declarations out of the source and fails if one of them is not
/// mentioned in this function's body — the defect this function has now
/// shipped three times (`basis`, then `datingRefs`/`septuagintYear`/
/// `era`, then `personIds`) is a field silently lost at a constructor
/// call, which no test of the asset and no test of either page can see.
/// Which of the wheel's powers is a throne `hebrew_kings.json` has
/// kings for.
///
/// WRITTEN OUT BECAUSE THERE IS NO SHARED KEY. The two assets were
/// built for different purposes and name nothing the same way, which
/// `cross_asset_year_agreement_test.dart` says of every join between
/// them: the agreement is asserted, never inferred. A power renamed
/// without this map renamed loses its kings silently, so a test pins
/// both sides.
///
/// `israel-united-monarchy` IS DELIBERATELY ABSENT, and that is the
/// whole reason this is a map and not a rule about `scripture+thiele`
/// powers. The power runs from 1050 BC, which is Saul; the kings file
/// is Thiele's chart of the divided monarchy and starts at David in
/// 1010 BC, with no Saul in it at all. Listing "the kings" under a
/// power whose own note names Saul would drop him without saying so —
/// an absence the reader would read as a claim. The two kings the file
/// does hold for that span, David and Solomon, are already on the
/// wheel as dated events.
const Map<String, Kingdom> kWheelPowerKingdoms = {
  'kingdom-of-judah': Kingdom.judah,
  'kingdom-of-israel': Kingdom.israel,
};

List<WheelHistoryEvent> bibleNarrativeEvents(
  List<TimelineEvent> events, {
  List<BiblicalPerson> people = const [],
}) {
  final byId = {for (final p in people) p.id: p};
  return [
      for (final e in events)
        if (!kTimelineIdsAlreadyOnWheel.contains(e.id))
          WheelHistoryEvent(
            id: '$kBibleEventIdPrefix${e.id}',
            year: e.year,
            era: 'bible',
            stream: kTimelineStreamOverrides[e.id] ??
                kTimelineEraStream[e.era] ??
                'world',
            basis: e.basis,
            approximate: e.approximate,
            refs: e.refs,
            datingRefs: e.datingRefs,
            septuagintYear: e.septuagintYear,
            timelineEra: e.era,
            people: [
              for (final id in e.personIds)
                if (byId[id] != null)
                  WheelPersonLink(id: id, nameKjv: byId[id]!.nameKjv, names: {
                    'en': byId[id]!.name,
                    if ((byId[id]!.nameZhHans ?? '').isNotEmpty)
                      'zh-Hans': byId[id]!.nameZhHans!,
                    if ((byId[id]!.nameZhHant ?? '').isNotEmpty)
                      'zh-Hant': byId[id]!.nameZhHant!,
                  }),
            ],
            titles: {
              'en': e.titleEn,
              if (e.titleZhHans.isNotEmpty) 'zh-Hans': e.titleZhHans,
              if (e.titleZhHant.isNotEmpty) 'zh-Hant': e.titleZhHant,
            },
            descs: {
              if (e.descEn.isNotEmpty) 'en': e.descEn,
              if (e.descZhHans.isNotEmpty) 'zh-Hans': e.descZhHans,
              if (e.descZhHant.isNotEmpty) 'zh-Hant': e.descZhHant,
            },
          )
    ];
}

class WheelHistoryService {
  WheelHistoryService._();
  static final WheelHistoryService instance = WheelHistoryService._();

  WheelHistoryData? _cache;

  /// The loaded data, or null before [load] has finished — the same
  /// synchronous door `ChronologyService` and `HebrewKingsService`
  /// already offer, and for the same caller: the arc band is built
  /// inside a paint pass and cannot await.
  WheelHistoryData? get cached => _cache;

  /// Merged at load rather than written into the asset, so the two
  /// files stay single sources: `bible_timeline.json` is audited by
  /// `tools/audit_dates.py` and read by the timeline page, and a copy
  /// of it inside `wheel_history.json` would drift out of step with
  /// the audit the first time a year moved. Everything downstream —
  /// the hub counts, the stream filter, the declutter, the search
  /// box, the detail sheets — sees one list and needs no special case.
  ///
  /// The family tree is awaited HERE, not in the page, and that is what
  /// lets `WheelPersonLink` be a value rather than a lookup. Anything
  /// holding a [WheelHistoryData] is past this await, so
  /// `FamilyTreeService.byId` is warm for the tap handler as well as
  /// for the chip.
  Future<WheelHistoryData> load() async {
    final cached = _cache;
    if (cached != null) return cached;
    final raw = await rootBundle.loadString('assets/world_chart/wheel_history.json');
    final base =
        WheelHistoryData.fromJson(json.decode(raw) as Map<String, dynamic>);
    final loaded = await Future.wait([
      TimelineService.instance.loadAll(),
      FamilyTreeService.instance.loadAll(),
    ]);
    // The two divided kingdoms list their kings from `hebrew_kings.json`
    // when their sheet opens, and that lookup is synchronous. Awaited
    // here for the same reason the family tree is: a synchronous read
    // that answers empty because the file has not landed yet reports an
    // absence that was really a race. Cached, so this costs one bundle
    // read for the life of the app.
    await HebrewKingsService.instance.load();
    // The Genesis lifespans, drawn as arcs in the annulus, come from
    // `chronology.json` — the Anno Mundi figures — and are turned into
    // BC years against `bible_timeline.json`'s `_meta.creation`, which
    // the `TimelineService` load above has just parsed. BOTH have to be
    // warm before the first paint or the layer draws nothing on the way
    // in and appears a frame later, and a chart that assembles itself in
    // stages reads as broken.
    await ChronologyService.instance.load();
    final data = WheelHistoryData(
      streams: base.streams,
      nations: base.nations,
      powers: base.powers,
      ministries: base.ministries,
      omissions: base.omissions,
      meta: base.meta,
      events: [
        ...base.events,
        ...bibleNarrativeEvents(
          loaded.first as List<TimelineEvent>,
          people: loaded.last as List<BiblicalPerson>,
        ),
      ]..sort((a, b) => a.year.compareTo(b.year)),
    );
    _cache = data;
    return data;
  }
}
