import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:yahwehs_words/constants/sermon_topics.dart';

const _locales = ['zh-Hans', 'zh-Hant', 'en'];

/// [sermonTopicI18n] is hand-maintained: its own docstring says to add an
/// entry "whenever a new topic appears in the corpus index", and nothing
/// enforces that. A missed entry degrades silently — a zh reader just gets
/// an English topic chip, with no error anywhere — which is exactly the
/// kind of drift a characterization test exists to catch.
void main() {
  final decoded =
      json.decode(File('assets/sermons/index.json').readAsStringSync());
  final items = decoded is List
      ? decoded
      : (decoded['sermons'] ?? decoded['items']) as List;
  final corpusTopics =
      items.map((s) => s['topic'] as String?).whereType<String>().toSet();

  test('every corpus topic has an i18n entry', () {
    final missing = corpusTopics.difference(sermonTopicI18n.keys.toSet());
    expect(missing, isEmpty,
        reason: 'a topic in assets/sermons/index.json with no entry in '
            'sermonTopicI18n renders in English on a Chinese-locale reader\'s '
            'screen, with no error anywhere: ${missing.join(", ")}');
  });

  test('no orphan i18n entry outlives its corpus topic', () {
    final orphans = sermonTopicI18n.keys.toSet().difference(corpusTopics);
    expect(orphans, isEmpty,
        reason: 'an entry whose key no longer occurs in index.json is a '
            'topic that was renamed upstream without its old translation '
            'being retired: ${orphans.join(", ")}');
  });

  test('every entry carries all three locales, none blank', () {
    final offenders = <String>[];
    sermonTopicI18n.forEach((topic, byLocale) {
      for (final locale in _locales) {
        final value = byLocale[locale];
        if (value == null || value.trim().isEmpty) {
          offenders.add('$topic/$locale');
        }
      }
    });
    expect(offenders, isEmpty,
        reason: 'a missing or blank locale value falls through to the '
            'English fallback silently: ${offenders.join(", ")}');
  });

  test('localizedSermonTopic returns the topic verbatim when unknown', () {
    expect(localizedSermonTopic('Some Future Topic', 'zh-Hans'),
        'Some Future Topic');
  });

  test('localizedSermonTopic falls back to en for an unknown locale', () {
    expect(localizedSermonTopic('Baptism', 'fr'), 'Baptism');
    expect(localizedSermonTopic('The Beatitudes', 'ja'), 'The Beatitudes');
  });

  test('localizedSermonTopic resolves a known topic + locale', () {
    expect(localizedSermonTopic('Baptism', 'zh-Hans'), '洗礼');
    expect(localizedSermonTopic('Baptism', 'zh-Hant'), '洗禮');
    expect(localizedSermonTopic('Baptism', 'en'), 'Baptism');
  });
}
