/// The questions the kings chart exists to answer, as pure functions
/// over a list of kings.
///
/// WHY THESE LIVE HERE. Four surfaces ask them — the comparison
/// columns and detail panel on `HebrewKingsPage`, the reign sheet the
/// chronology wheel opens (`wheel_sheets.dart`), the year lookup, and
/// the page's search box. The overlap rule itself is
/// [closedIntervalsOverlap] in `models/hebrew_king.dart` and is called,
/// never restated; everything below is a query built on top of it. A
/// second copy of "whose reigns touch" is the one defect that would be
/// invisible until two screens disagreed in front of a reader.
///
/// NOTHING HERE IS A LIST OF NAMES, and it is worth being exact about
/// what each half of a tally is derived from, because a 2026-09-06
/// audit found this paragraph claiming more than the code did.
///
///   the TOTAL      — the year fields, through [reignsOverlap], which
///                    compares the hull `reignStart..reignEnd`. It does
///                    not read `spans`. See [reignsOverlap]'s own
///                    comment for why the hull and not the spans, and
///                    for the builder and the asset test that keep the
///                    hull equal to the span union.
///   the SPLIT      — `spans[].kind`, through [HebrewKing.isRival] and
///                    [SpanKind.heldThrone].
///
/// Both move when a king is re-dated in `assets/world_chart/hebrew_kings.json`,
/// which is the property that matters; neither consults a name.
library;

import 'package:yahwehs_words/world_history/models/hebrew_king.dart';

/// Kings of the OTHER kingdom whose reign shared a year with [k],
/// earliest first.
///
/// Returns empty for a king of the united monarchy: David and Solomon
/// have no other throne to be compared with, and an empty list is the
/// honest answer rather than a missing section.
List<HebrewKing> contemporariesOf(Iterable<HebrewKing> all, HebrewKing k) {
  if (k.kingdom == Kingdom.united) return const [];
  final other = k.kingdom == Kingdom.judah ? Kingdom.israel : Kingdom.judah;
  final out = all
      .where((e) => e.kingdom == other && reignsOverlap(e, k))
      .toList(growable: false)
    ..sort(_byReign);
  return out;
}

/// How many contemporaries, and how many of them actually held the
/// throne.
///
/// THE TWO NUMBERS ARE BOTH TRUE AND NEITHER IS THE OTHER. Asa of
/// Judah (911-870) overlaps eight men of the north — Jeroboam I, Nadab,
/// Baasha, Elah, Zimri, Tibni, Omri, Ahab — of whom seven are kings of
/// Israel and one, Tibni, is a claimant: 1 Kings 16:21-22 gives him no
/// regnal formula and never says he reigned, and his dates are Thiele's
/// inference. So the chart reports 8 and 7 side by side rather than
/// picking one and hiding the disagreement.
///
/// WHAT IS DELIBERATELY NOT HERE IS A DURATION THRESHOLD. Zimri held
/// Tirzah seven days and is counted, because he carries the full
/// regnal formula (1 Kings 16:15-20) and reign length is not a
/// criterion Scripture uses. A "long enough to matter" rule would be
/// this app's editorial opinion wearing the costume of a fact, and it
/// is the only way to reach the smaller counts a reader might expect.
class ContemporaryTally {
  const ContemporaryTally({
    required this.total,
    required this.reigning,
    required this.rivals,
  });

  /// Everyone whose reign touched — [reigning] + [rivals].
  final int total;

  /// Those who held the throne on their own account.
  final int reigning;

  /// Those every one of whose spans is a [SpanKind.rival] claim.
  final int rivals;

  factory ContemporaryTally.of(Iterable<HebrewKing> kings) {
    var total = 0;
    var rivals = 0;
    for (final k in kings) {
      total++;
      if (k.isRival) rivals++;
    }
    return ContemporaryTally(
      total: total,
      reigning: total - rivals,
      rivals: rivals,
    );
  }

  bool get hasRivals => rivals > 0;
}

/// Everyone on a throne in [year] — negative for BC — earliest reign
/// first. Pass [kingdom] to ask about one throne only.
///
/// The same closed-interval rule as [contemporariesOf], applied to a
/// window one year wide, so a king who appears in one answer cannot
/// fail to appear in the other.
List<HebrewKing> reigningInYear(
  Iterable<HebrewKing> all,
  int year, {
  Kingdom? kingdom,
}) {
  final out = all
      .where((k) =>
          (kingdom == null || k.kingdom == kingdom) &&
          reignTouchesYear(k, year))
      .toList(growable: false)
    ..sort(_byReign);
  return out;
}

/// The years any king in [all] touches, as `(earliest, latest)`, or
/// null when there are none. What a year-lookup field may usefully be
/// asked, so the UI can say so instead of returning a silent nothing.
(int, int)? reignExtent(Iterable<HebrewKing> all) {
  int? lo;
  int? hi;
  for (final k in all) {
    if (lo == null || k.reignStart < lo) lo = k.reignStart;
    if (hi == null || k.reignEnd > hi) hi = k.reignEnd;
  }
  if (lo == null || hi == null) return null;
  return (lo, hi);
}

/// Kings matching [query], for the kings page's search box.
///
/// MATCHES THE LANGUAGE THE READER IS RUNNING, and then the other two.
/// A reader in `zh-Hant` typing 亞哈 must find Ahab; a reader in the
/// same locale typing "Ahab" — because the commentary open beside them
/// is in English — must find him too, and there is no cost to allowing
/// it. The running locale is still consulted FIRST so that its own
/// spelling is what ranks a match, and alternative names are searched
/// because half the northern kings are known by two (Azariah/Uzziah,
/// Jeconiah/Jehoiachin).
///
/// [refLabel] localises a scripture reference before it is compared, so
/// that searching 王上 finds what searching "1 Kings" finds. The caller
/// passes `localizedReferenceLabel`; the default leaves references in
/// the form the asset stores them, which is what a test wants.
///
/// Order is chronological, not by score. This is a filter over a chart
/// whose whole meaning is the time axis, and re-ordering it by
/// relevance would scramble the one thing the reader came for.
List<HebrewKing> searchKings(
  Iterable<HebrewKing> all,
  String query,
  String locale, {
  String Function(String reference, String locale)? refLabel,
}) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return all.toList(growable: false)..sort(_byReign);

  bool hit(String? s) => s != null && s.toLowerCase().contains(q);

  bool hitRef(String? ref) {
    if (ref == null) return false;
    if (hit(ref)) return true;
    final localised = refLabel?.call(ref, locale);
    return hit(localised);
  }

  bool matches(HebrewKing k) =>
      hit(k.nameFor(locale)) ||
      hit(k.altNameFor(locale)) ||
      k.names.values.any(hit) ||
      (k.altNames?.values.any(hit) ?? false) ||
      hitRef(k.kingsRef) ||
      hitRef(k.chroniclesRef) ||
      hitRef(k.accessionRef);

  return all.where(matches).toList(growable: false)..sort(_byReign);
}

/// Chronological, then by end year so that a co-regent and the father
/// he acceded beside keep a stable order, then by id so the list never
/// depends on the asset's own ordering.
int _byReign(HebrewKing a, HebrewKing b) {
  final byStart = a.reignStart.compareTo(b.reignStart);
  if (byStart != 0) return byStart;
  final byEnd = a.reignEnd.compareTo(b.reignEnd);
  if (byEnd != 0) return byEnd;
  return a.id.compareTo(b.id);
}
