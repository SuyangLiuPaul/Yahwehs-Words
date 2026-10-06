import 'dart:convert';

import 'package:flutter/services.dart';

/// Data for the two hidden study pages (圣经原则 / 神的应许). The JSON is
/// generated from a verified research pass and is Bible-first: every verse text
/// comes from the app's own Bibles (simplified, traditional, KJV), every sermon is
/// only a link, and every external source named was opened and read.
/// Traditional-Chinese strings are converted from Simplified.

/// A localized string: zh-Hans, zh-Hant and (sometimes) en.
class StudyText {
  final Map<String, String> _m;
  const StudyText(this._m);

  factory StudyText.from(Object? j) =>
      StudyText(Map<String, String>.from((j as Map?) ?? const {}));

  /// English falls back to Simplified Chinese: the research is written in
  /// Chinese, so an English reader still sees the content, not a blank.
  String of(String locale) {
    if (locale == 'zh-Hant') return _m['zh-Hant'] ?? _m['zh-Hans'] ?? '';
    if (locale == 'zh-Hans') return _m['zh-Hans'] ?? '';
    return _m['en'] ?? _m['zh-Hans'] ?? '';
  }

  /// True when [locale] has its own wording rather than the Chinese fallback.
  bool hasNative(String locale) => locale == 'en' ? _m.containsKey('en') : true;

  bool get isEmpty => _m.isEmpty;

  bool matches(String q, String locale) {
    final n = q.trim().toLowerCase();
    if (n.isEmpty) return true;
    return _m.values.any((v) => v.toLowerCase().contains(n));
  }
}

/// A Bible passage with its text in the three bundled editions.
class StudyVerse {
  final String ref; // full English, e.g. "Isaiah 55:7"
  final StudyText text;
  const StudyVerse(this.ref, this.text);
  factory StudyVerse.fromJson(Map<String, dynamic> j) => StudyVerse(
      j['ref'] as String,
      StudyText({
        'zh-Hans': j['zh-Hans'] as String,
        'zh-Hant': j['zh-Hant'] as String,
        'en': j['en'] as String,
      }));
}

/// A sermon this entry links to. Only the id and the title: tapping opens it.
class StudySermon {
  final String id;
  final StudyText title;
  const StudySermon(this.id, this.title);
  factory StudySermon.fromJson(Map<String, dynamic> j) =>
      StudySermon(j['id'] as String, StudyText.from(j['title']));
}

class StudySource {
  final StudyText name;
  final String url;
  const StudySource(this.name, this.url);
  factory StudySource.fromJson(Map<String, dynamic> j) =>
      StudySource(StudyText.from(j['name']), j['url'] as String);
}

class StudyLabel {
  final StudyText label;
  final StudyText note;
  const StudyLabel(this.label, this.note);
  factory StudyLabel.fromJson(Map<String, dynamic> j) => StudyLabel(
      StudyText.from(j['label']), StudyText.from(j['note'] ?? const {}));
}

/// "Isaiah 55:7-9" -> (book: "Isaiah", chapter: 55). Null when it does not parse.
({String book, int chapter})? studyParseRef(String ref) {
  final m = RegExp(r'^(.+?)\s+(\d+):').firstMatch(ref.trim());
  if (m == null) return null;
  return (book: m.group(1)!, chapter: int.parse(m.group(2)!));
}

/// Every (book, chapter) a list of references touches.
Set<(String, int)> studyChaptersOf(Iterable<String> refs) {
  final out = <(String, int)>{};
  for (final r in refs) {
    final p = studyParseRef(r);
    if (p != null) out.add((p.book, p.chapter));
  }
  return out;
}

List<StudySermon> _sermons(Object? j) => [
      for (final s in (j as List))
        StudySermon.fromJson(s as Map<String, dynamic>)
    ];
List<StudySource> _sources(Object? j) => [
      for (final s in (j as List))
        StudySource.fromJson(s as Map<String, dynamic>)
    ];
List<StudyVerse> _verses(Object? j) => [
      for (final s in (j as List)) StudyVerse.fromJson(s as Map<String, dynamic>)
    ];

class StudyPromise {
  final String id, group, cond, status;
  final StudyText title, who, condText, fulfil;
  final StudyText? history;
  final List<String> refs, fulfilRefs;
  final List<StudyVerse> verseBlocks;
  final List<StudySource> sources;
  final List<StudySermon> sermons;
  const StudyPromise({
    required this.id,
    required this.group,
    required this.cond,
    required this.status,
    required this.title,
    required this.who,
    required this.condText,
    required this.fulfil,
    required this.history,
    required this.refs,
    required this.fulfilRefs,
    required this.verseBlocks,
    required this.sources,
    required this.sermons,
  });
  factory StudyPromise.fromJson(Map<String, dynamic> j) => StudyPromise(
        id: j['id'] as String,
        group: j['group'] as String,
        cond: j['cond'] as String,
        status: j['status'] as String,
        title: StudyText.from(j['title']),
        who: StudyText.from(j['who']),
        condText: StudyText.from(j['condText']),
        fulfil: StudyText.from(j['fulfil']),
        history: j['history'] == null ? null : StudyText.from(j['history']),
        refs: (j['refs'] as List).cast<String>(),
        fulfilRefs: (j['fulfilRefs'] as List).cast<String>(),
        verseBlocks: _verses(j['verseBlocks']),
        sources: _sources(j['sources']),
        sermons: _sermons(j['sermons']),
      );

  /// Books and chapters this promise cites (the promise itself and where the
  /// Bible reports its fulfilment): used by the book / chapter filter.
  Set<(String, int)> get chapters => studyChaptersOf([...refs, ...fulfilRefs]);

  bool matches(String q, String locale) =>
      title.matches(q, locale) ||
      fulfil.matches(q, locale) ||
      refs.any((r) => r.toLowerCase().contains(q.trim().toLowerCase())) ||
      sermons.any((s) => s.id == q.trim());
}

class StudyPrinciple {
  final String id, cat;
  final int n;
  final StudyText title, line;
  final List<StudyVerse> verseBlocks;
  final List<StudyText> says, limits;
  final List<String> verses;
  final List<StudySermon> sermons;
  final List<StudySource> sources;
  const StudyPrinciple({
    required this.id,
    required this.n,
    required this.cat,
    required this.title,
    required this.line,
    required this.verseBlocks,
    required this.says,
    required this.limits,
    required this.verses,
    required this.sermons,
    required this.sources,
  });
  factory StudyPrinciple.fromJson(Map<String, dynamic> j) => StudyPrinciple(
        id: j['id'] as String,
        n: j['n'] as int,
        cat: j['cat'] as String,
        title: StudyText.from(j['title']),
        line: StudyText.from(j['line']),
        verseBlocks: _verses(j['verseBlocks']),
        says: [for (final p in (j['says'] as List)) StudyText.from(p)],
        limits: [for (final p in (j['limits'] as List)) StudyText.from(p)],
        verses: (j['verses'] as List).cast<String>(),
        sermons: _sermons(j['sermons']),
        sources: _sources(j['sources']),
      );

  /// Books and chapters this principle cites: used by the book / chapter filter.
  Set<(String, int)> get chapters =>
      studyChaptersOf([...verses, ...verseBlocks.map((v) => v.ref)]);

  bool matches(String q, String locale) =>
      title.matches(q, locale) ||
      line.matches(q, locale) ||
      verses.any((r) => r.toLowerCase().contains(q.trim().toLowerCase())) ||
      sermons.any((s) => s.id == q.trim());
}

/// One Old Testament passage a New Testament verse quotes or alludes to.
class StudyOtRef {
  final String ref; // full English
  final String type; // quote | paraphrase | allusion
  final List<String> srcs; // LEB / NET
  final StudyVerse block;
  const StudyOtRef(this.ref, this.type, this.srcs, this.block);
  factory StudyOtRef.fromJson(Map<String, dynamic> j) => StudyOtRef(
      j['ref'] as String,
      j['type'] as String,
      (j['srcs'] as List).cast<String>(),
      StudyVerse.fromJson(j['block'] as Map<String, dynamic>));
}

/// A New Testament verse (or run of verses) and the Old Testament it cites.
class StudyCorrespondence {
  final String id, nt, main;
  final String? formula; // fulfil | written | null
  final StudyVerse ntBlock;
  final List<StudyOtRef> ot;
  const StudyCorrespondence(
      this.id, this.nt, this.main, this.formula, this.ntBlock, this.ot);
  factory StudyCorrespondence.fromJson(Map<String, dynamic> j) =>
      StudyCorrespondence(
          j['id'] as String,
          j['nt'] as String,
          j['main'] as String,
          j['formula'] as String?,
          StudyVerse.fromJson(j['ntBlock'] as Map<String, dynamic>),
          [
            for (final o in (j['ot'] as List))
              StudyOtRef.fromJson(o as Map<String, dynamic>)
          ]);

  Set<(String, int)> get ntChapters => studyChaptersOf([nt]);
  Set<(String, int)> get otChapters => studyChaptersOf(ot.map((o) => o.ref));

  bool matches(String q, String locale) {
    final n = q.trim().toLowerCase();
    if (n.isEmpty) return true;
    return nt.toLowerCase().contains(n) ||
        ot.any((o) => o.ref.toLowerCase().contains(n)) ||
        ntBlock.text.matches(n, locale) ||
        ot.any((o) => o.block.text.matches(n, locale));
  }
}

/// A place where the New Testament itself calls an Old Testament person,
/// event or institution a type / shadow / example / allegory.
class StudyTypology {
  final String id;
  final StudyText title, word, says;
  final List<String> ot, nt;
  final List<StudyVerse> otBlocks, ntBlocks;
  const StudyTypology(this.id, this.title, this.word, this.says, this.ot,
      this.nt, this.otBlocks, this.ntBlocks);
  factory StudyTypology.fromJson(Map<String, dynamic> j) => StudyTypology(
      j['id'] as String,
      StudyText.from(j['title']),
      StudyText.from(j['word']),
      StudyText.from(j['says']),
      (j['ot'] as List).cast<String>(),
      (j['nt'] as List).cast<String>(),
      _verses(j['otBlocks']),
      _verses(j['ntBlocks']));
}

/// A New Testament verse with Old Testament passages cross-referenced both ways.
class StudyRelated {
  final String nt;
  final List<String> ot;
  const StudyRelated(this.nt, this.ot);
}

class StudyTestaments {
  final List<StudyCorrespondence> entries;
  final List<StudyTypology> typology;
  final List<StudyRelated> related;
  const StudyTestaments(this.entries, this.typology, this.related);
}

class StudyPromises {
  final Map<String, StudyLabel> status, conds;
  final List<(String, StudyText)> groups;
  final List<StudyPromise> promises;
  const StudyPromises(this.status, this.conds, this.groups, this.promises);
}

class StudyPrinciples {
  final List<(String, StudyText)> categories;
  final List<StudyPrinciple> principles;
  const StudyPrinciples(this.categories, this.principles);
}

class StudyData {
  static Map<String, StudyLabel> _labels(Object? j) => {
        for (final e in (j as Map).entries)
          e.key as String:
              StudyLabel.fromJson(Map<String, dynamic>.from(e.value as Map))
      };

  static Future<StudyPromises> loadPromises(
      {Future<String> Function(String)? loader}) async {
    final j = jsonDecode(await (loader ?? rootBundle.loadString)(
        'assets/study_promises.json')) as Map<String, dynamic>;
    return StudyPromises(
      _labels(j['status']),
      _labels(j['conds']),
      [
        for (final g in (j['groups'] as List))
          ((g as Map)['id'] as String, StudyText.from(g['name']))
      ],
      [
        for (final p in (j['promises'] as List))
          StudyPromise.fromJson(p as Map<String, dynamic>)
      ],
    );
  }

  static Future<StudyTestaments> loadTestaments(
      {Future<String> Function(String)? loader}) async {
    final j = jsonDecode(await (loader ?? rootBundle.loadString)(
        'assets/study_testaments.json')) as Map<String, dynamic>;
    return StudyTestaments([
      for (final e in (j['entries'] as List))
        StudyCorrespondence.fromJson(e as Map<String, dynamic>)
    ], [
      for (final t in (j['typology'] as List))
        StudyTypology.fromJson(t as Map<String, dynamic>)
    ], [
      for (final r in (j['related'] as List))
        StudyRelated((r as List)[0] as String, (r[1] as List).cast<String>())
    ]);
  }

  static Future<StudyPrinciples> loadPrinciples(
      {Future<String> Function(String)? loader}) async {
    final j = jsonDecode(await (loader ?? rootBundle.loadString)(
        'assets/study_principles.json')) as Map<String, dynamic>;
    return StudyPrinciples([
      for (final c in (j['categories'] as List))
        ((c as Map)['id'] as String, StudyText.from(c['name']))
    ], [
      for (final p in (j['principles'] as List))
        StudyPrinciple.fromJson(p as Map<String, dynamic>)
    ]);
  }
}
