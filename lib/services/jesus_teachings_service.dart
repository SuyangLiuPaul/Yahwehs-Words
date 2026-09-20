/// The teachings of the Lord Jesus, and what the app already knows about
/// each one.
///
/// COPIED FROM YAHWEH'S SWORD, 2026-09-21 — 「主耶稣的教导我也要搬一份到
/// words」, and 「应该是直接写在sword里面的」: Sword is where this is
/// written. `assets/jesus_teachings.json` here is a byte-for-byte copy of
/// Sword's, and this file is Sword's `jesus_teachings_service.dart` with
/// the package name changed. Edit it THERE and copy it across; the
/// generator is Sword's too, and it cannot run here because Words does
/// not bundle Nave's Topical Bible, one of its inputs.
/// `jesus_teachings_test.dart` checks every sermon and plate the copy
/// names still exists in this app's own corpus.
///
/// The data is built by Sword's `scripts/build_jesus_teachings.py`, which
/// holds the whole argument for how the list is arranged and what it may
/// claim. Two points matter enough to repeat here, because they decide
/// what this page is allowed to SAY:
///
///   * THE ARRANGEMENT IS EDITORIAL. There is no canonical enumeration
///     of Jesus' teachings. The parables are a stable category; the
///     discourses are not, and every published list is somebody's
///     scheme. The page tells the reader so.
///   * A CROSS-REFERENCE IS NOT A DERIVATION. The Treasury of Scripture
///     Knowledge asserts that two passages are RELATED. It does not
///     assert that one rests on the other, and nothing in this file
///     upgrades that. The only links that carry a claim of dependence
///     are those where an apostle says so himself — [TeachingLink.lordsWord]
///     — and there are five places in the New Testament like that.
library;

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// One reference span, as the generator emitted it.
class TeachingRef {
  const TeachingRef({
    required this.book,
    required this.chapter,
    required this.start,
    required this.end,
  });

  factory TeachingRef.fromJson(Map<String, dynamic> j) => TeachingRef(
        book: j['book'] as String,
        chapter: j['chapter'] as int,
        start: j['start'] as int,
        end: j['end'] as int,
      );

  final String book;
  final int chapter;
  final int start;
  final int end;

  /// What `parseReference` expects, and what a reader would write.
  String get label =>
      end > start ? '$book $chapter:$start-$end' : '$book $chapter:$start';
}

/// One apostolic passage related to a teaching.
class TeachingLink {
  const TeachingLink({required this.ref, this.lordsWord});

  factory TeachingLink.fromJson(Map<String, dynamic> j) => TeachingLink(
        ref: j['ref'] as String,
        lordsWord: j['lordsWord'] as String?,
      );

  final String ref;

  /// Non-null only where the apostle himself says he is passing on the
  /// Lord's own word — "received of the Lord", "the Lord commanded".
  /// This is the one place on the page where a link asserts dependence
  /// rather than relation, and it is scripture making the assertion.
  final String? lordsWord;
}

/// One sermon from the bundled corpus that expounds a teaching.
class TeachingSermon {
  const TeachingSermon({
    required this.id,
    required this.title,
    required this.date,
    required this.topic,
  });

  factory TeachingSermon.fromJson(Map<String, dynamic> j) => TeachingSermon(
        id: j['id'] as String,
        title: Map<String, String>.from(
            (j['title'] as Map).map((k, v) => MapEntry('$k', '$v'))),
        date: j['date'] as String? ?? '',
        topic: j['topic'] as String? ?? '',
      );

  final String id;

  /// Keyed `en` / `zh-CN` / `zh-TW`, as the sermon corpus keys them.
  final Map<String, String> title;
  final String date;
  final String topic;

  String titleFor(String locale) =>
      title[locale == 'zh-Hant'
          ? 'zh-TW'
          : locale == 'zh-Hans'
              ? 'zh-CN'
              : 'en'] ??
      title['en'] ??
      '';
}

/// One teaching that folded into another — the Beatitudes inside the
/// Sermon on the Mount, the sermon on the sower inside the parables of
/// the kingdom. The list is one level deep on purpose; these are what
/// that one row is made of.
class TeachingPart {
  const TeachingPart(
      {required this.title, required this.label, required this.ref});

  factory TeachingPart.fromJson(Map<String, dynamic> j) => TeachingPart(
        title: Map<String, String>.from(
            (j['title'] as Map).map((k, v) => MapEntry('$k', '$v'))),
        label: j['label'] as String? ?? '',
        ref: j['ref'] as String? ?? '',
      );

  final Map<String, String> title;
  final String label;

  /// The first of the passages in [label] — what a tap opens, because
  /// a label naming three synoptic parallels is not a reference.
  final String ref;

  String titleFor(String locale) =>
      title[locale] ?? title['en'] ?? title.values.first;
}

/// One illustration plate, with the name a reader should see.
class TeachingPlate {
  const TeachingPlate({required this.id, required this.title});

  factory TeachingPlate.fromJson(Map<String, dynamic> j) => TeachingPlate(
        id: j['id'] as String,
        title: Map<String, String>.from(
            (j['title'] as Map).map((k, v) => MapEntry('$k', '$v'))),
      );

  final String id;
  final Map<String, String> title;

  String titleFor(String locale) => title[locale] ?? title['en'] ?? id;
}

class JesusTeaching {
  const JesusTeaching({
    required this.id,
    required this.title,
    required this.note,
    required this.refs,
    required this.label,
    required this.origins,
    required this.contains,
    required this.kind,
    required this.sermons,
    required this.oldTestament,
    required this.apostles,
    required this.plates,
  });

  factory JesusTeaching.fromJson(Map<String, dynamic> j) => JesusTeaching(
        id: j['id'] as String,
        title: Map<String, String>.from(
            (j['title'] as Map).map((k, v) => MapEntry('$k', '$v'))),
        note: (j['note'] as Map?)
            ?.map((k, v) => MapEntry('$k', '$v'))
            .cast<String, String>(),
        refs: [
          for (final r in (j['refs'] as List))
            TeachingRef.fromJson(r as Map<String, dynamic>)
        ],
        label: j['label'] as String? ?? '',
        origins: [for (final o in (j['origins'] as List? ?? [])) '$o'],
        contains: [
          for (final c in (j['contains'] as List? ?? []))
            TeachingPart.fromJson(c as Map<String, dynamic>)
        ],
        kind: j['kind'] as String? ?? 'teaching',
        sermons: [
          for (final s in (j['sermons'] as List? ?? []))
            TeachingSermon.fromJson(s as Map<String, dynamic>)
        ],
        oldTestament: [
          for (final r in (j['oldTestament'] as List? ?? [])) '$r'
        ],
        apostles: [
          for (final a in (j['apostles'] as List? ?? []))
            TeachingLink.fromJson(a as Map<String, dynamic>)
        ],
        plates: [
          for (final p in (j['plates'] as List? ?? []))
            TeachingPlate.fromJson(p as Map<String, dynamic>)
        ],
      );

  final String id;
  final Map<String, String> title;

  /// Nave's own sentence, where the app's section heading replaced it
  /// as the title, or the name of an entry this one absorbed. Null when
  /// the title is already the source's own.
  ///
  /// Keyed by locale, and NOT filled in for every locale: an English
  /// sentence under a Chinese title is not a note, it is noise, so the
  /// page shows nothing where there is no translation.
  final Map<String, String>? note;

  String? noteFor(String locale) => note?[locale];
  final List<TeachingRef> refs;

  /// The refs as one printable string, built once by the generator so
  /// the page and any test read the same words.
  final String label;

  /// Where this entry came from: `structure`, `sermon`, `nave`. Shown
  /// to the reader, because an editorial arrangement that will not say
  /// which parts are editorial is not being honest about itself.
  final List<String> origins;

  /// What this row is made of. The page is ONE LEVEL DEEP — the owner
  /// asked for a list a reader can take in at a glance, so the Sermon
  /// on the Mount is one row and the twenty-one teachings that sit
  /// inside it are named here, inside it, rather than indented beneath
  /// it as twenty-one more rows.
  final List<TeachingPart> contains;

  /// `discourse`, `parable` or `teaching`. Decided by the sources — the
  /// owner's own sermon series says which sermons are on parables, Nave
  /// says "parable" in the line itself, and the discourses are the
  /// text's own divisions. Nothing is forced into a category.
  final String kind;

  final List<TeachingSermon> sermons;
  final List<String> oldTestament;
  final List<TeachingLink> apostles;
  final List<TeachingPlate> plates;

  bool get isDiscourse => origins.contains('structure');

  String titleFor(String locale) =>
      title[locale] ?? title['en'] ?? title.values.first;
}

class JesusTeachingsData {
  const JesusTeachingsData({required this.teachings, required this.claims});

  final List<JesusTeaching> teachings;

  /// `_meta.claims` — what the page is allowed to say about its links,
  /// carried out of the data rather than retyped in the UI so the two
  /// cannot drift. Trilingual: it is a disclaimer, and a disclaimer in
  /// a language the reader did not ask for is not one.
  final Map<String, String> claims;

  String claimsFor(String locale) => claims[locale] ?? claims['en'] ?? '';
}

class JesusTeachingsService {
  JesusTeachingsService._();

  static final JesusTeachingsService instance = JesusTeachingsService._();

  JesusTeachingsData? _cache;
  Future<JesusTeachingsData>? _inFlight;

  JesusTeachingsData? get cached => _cache;

  Future<JesusTeachingsData> load() =>
      _inFlight ??= _load().then((value) => _cache = value);

  Future<JesusTeachingsData> _load() async {
    final raw = await rootBundle.loadString('assets/jesus_teachings.json');
    final doc = json.decode(raw) as Map<String, dynamic>;
    return JesusTeachingsData(
      teachings: [
        for (final t in (doc['teachings'] as List))
          JesusTeaching.fromJson(t as Map<String, dynamic>)
      ],
      claims: Map<String, String>.from(
          (((doc['_meta'] as Map?)?['claims'] as Map?) ?? const {})
              .map((k, v) => MapEntry('$k', '$v'))),
    );
  }
}
