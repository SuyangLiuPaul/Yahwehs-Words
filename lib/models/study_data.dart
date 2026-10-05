import 'dart:convert';

import 'package:flutter/services.dart';

/// Data for the two hidden study pages (圣经原则 / 神的应许). The JSON is
/// generated from a verified research pass: every Bible reference resolves in
/// the app's own text, every sermon quote was checked verbatim against the
/// sermon corpus. Traditional-Chinese strings are converted from Simplified.

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

class StudyQuote {
  final String sermonId;
  final StudyText quote;
  final StudyText sermonTitle;
  const StudyQuote(this.sermonId, this.quote, this.sermonTitle);
  factory StudyQuote.fromJson(Map<String, dynamic> j) => StudyQuote(
      j['id'] as String,
      StudyText.from(j['quote']),
      StudyText.from(j['title']));
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

class StudyPromise {
  final String id, group, cond, status;
  final StudyText title, who, condText, fulfil;
  final StudyText? history;
  final List<String> refs, fulfilRefs;
  final List<StudySource> sources;
  final List<StudyQuote> sermons;
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
        sources: [
          for (final s in (j['sources'] as List))
            StudySource.fromJson(s as Map<String, dynamic>)
        ],
        sermons: [
          for (final s in (j['sermons'] as List))
            StudyQuote.fromJson(s as Map<String, dynamic>)
        ],
      );

  bool matches(String q, String locale) =>
      title.matches(q, locale) ||
      fulfil.matches(q, locale) ||
      refs.any((r) => r.toLowerCase().contains(q.trim().toLowerCase()));
}

/// One sermon claim compared with the Bible (a "proposition" about promises, or
/// a "principle").
class StudyClaim {
  final String id, verdict;
  final int n;
  final StudyText title, verdictNote;
  final StudyText? tagline;
  final List<StudyQuote> quotes;
  final List<String> verses;
  final List<StudyText> points;
  final List<String> existing;
  const StudyClaim({
    required this.id,
    required this.n,
    required this.verdict,
    required this.title,
    required this.verdictNote,
    required this.tagline,
    required this.quotes,
    required this.verses,
    required this.points,
    required this.existing,
  });
  factory StudyClaim.fromJson(Map<String, dynamic> j) => StudyClaim(
        id: j['id'] as String,
        n: j['n'] as int,
        verdict: j['verdict'] as String,
        title: StudyText.from(j['title']),
        verdictNote: StudyText.from(j['verdictNote']),
        tagline: j['tagline'] == null ? null : StudyText.from(j['tagline']),
        // principles call them "quotes", propositions call them "sermons"
        quotes: [
          for (final s in ((j['quotes'] ?? j['sermons']) as List))
            StudyQuote.fromJson(s as Map<String, dynamic>)
        ],
        verses: (j['verses'] as List).cast<String>(),
        points: [for (final p in (j['points'] as List)) StudyText.from(p)],
        existing: (j['existing'] as List? ?? const []).cast<String>(),
      );

  bool matches(String q, String locale) =>
      title.matches(q, locale) ||
      (tagline?.matches(q, locale) ?? false) ||
      points.any((p) => p.matches(q, locale)) ||
      verses.any((r) => r.toLowerCase().contains(q.trim().toLowerCase())) ||
      quotes.any((x) => x.sermonId == q.trim());
}

class StudyPromises {
  final Map<String, StudyLabel> status, verdicts, conds;
  final List<(String, StudyText)> groups;
  final List<StudyPromise> promises;
  final List<StudyClaim> propositions;
  final List<StudySource> sources;
  const StudyPromises(this.status, this.verdicts, this.conds, this.groups,
      this.promises, this.propositions, this.sources);
}

class StudyPrinciples {
  final Map<String, StudyLabel> verdicts;
  final List<StudyClaim> principles;
  const StudyPrinciples(this.verdicts, this.principles);
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
      _labels(j['verdicts']),
      _labels(j['conds']),
      [
        for (final g in (j['groups'] as List))
          ((g as Map)['id'] as String, StudyText.from(g['name']))
      ],
      [
        for (final p in (j['promises'] as List))
          StudyPromise.fromJson(p as Map<String, dynamic>)
      ],
      [
        for (final p in (j['propositions'] as List))
          StudyClaim.fromJson(p as Map<String, dynamic>)
      ],
      [
        for (final s in (j['sources'] as List))
          StudySource.fromJson(s as Map<String, dynamic>)
      ],
    );
  }

  static Future<StudyPrinciples> loadPrinciples(
      {Future<String> Function(String)? loader}) async {
    final j = jsonDecode(await (loader ?? rootBundle.loadString)(
        'assets/study_principles.json')) as Map<String, dynamic>;
    return StudyPrinciples(_labels(j['verdicts']), [
      for (final p in (j['principles'] as List))
        StudyClaim.fromJson(p as Map<String, dynamic>)
    ]);
  }
}
