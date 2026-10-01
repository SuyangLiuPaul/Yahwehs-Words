import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahwehs_words/models/verse.dart';
import 'package:yahwehs_words/services/watch_reading_snapshot.dart';

void main() {
  Map<String, dynamic> snapshot(List<Verse> verses,
          {String locale = 'zh-Hans', String version = 'kjv'}) =>
      watchReadingSnapshot(
          book: 'Luke',
          chapter: 23,
          version: version,
          locale: locale,
          verses: verses);
  test(
      'watch chapter preserves split verse labels and excludes editorial notes',
      () {
    final value = snapshot(const [
      Verse(
          book: 'Luke',
          chapter: 23,
          verse: 34,
          verseLabel: '34a',
          text: '<b>Father</b><note:private annotation>',
          superscription: 'Heading',
          blockNotes: ['Not shared']),
      Verse(book: 'Luke', chapter: 23, verse: 34, text: 'Second half')
    ]);
    final rows = value['verses'] as List;
    expect(rows[0], {'number': '34a', 'text': 'Father', 'heading': 'Heading'});
    expect(rows[1]['number'], '34');
    expect(value['reference'], '路加福音 23');
    expect(value['truncated'], false);
    expect(jsonEncode(value), isNot(contains('private annotation')));
    expect(jsonEncode(value), isNot(contains('Not shared')));
  });
  test(
      'changing an edition changes the chapter identity while the label follows the UI locale',
      () {
    expect(snapshot([], version: 'cuvs-tr')['key'], 'cuvs-tr|Luke|23');
    expect(snapshot([], version: 'cuvs-tr')['reference'], '路加福音 23');
    expect(snapshot([], locale: 'en')['reference'], 'Luke 23');
  });
  test(
      'oversize chapters stop before a complete verse and advertise truncation',
      () {
    final value = snapshot([
      for (var i = 1; i <= 120; i++)
        Verse(book: 'Luke', chapter: 23, verse: i, text: '经' * 300)
    ]);
    final rows = value['verses'] as List;
    expect(value['truncated'], true);
    expect(value['total'], 120);
    expect(rows, isNotEmpty);
    expect(utf8.encode(jsonEncode(value)).length, lessThan(45000));
    expect(rows.every((row) => row['text'] == '经' * 300), true);
  });
}
