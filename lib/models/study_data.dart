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

  bool matches(String q, String locale) =>
      title.matches(q, locale) ||
      line.matches(q, locale) ||
      verses.any((r) => r.toLowerCase().contains(q.trim().toLowerCase())) ||
      sermons.any((s) => s.id == q.trim());
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
