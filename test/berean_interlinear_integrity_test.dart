import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahwehs_words/services/tagged_text_service.dart';

void main() {
  final rows = jsonDecode(File('assets/bib.json').readAsStringSync()) as List;
  final tagged = <String, Map<String, dynamic>>{
    for (final file
        in Directory('assets/tagged/bib').listSync().whereType<File>())
      file.uri.pathSegments.last.replaceAll('.json', '').replaceAll('_', ' '):
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>
  };
  test('official NT import has 27 books, 260 chapters and 7941 unique verses',
      () {
    expect(rows.length, 7941);
    expect(rows.map((v) => v['book']).toSet().length, 27);
    expect(rows.map((v) => '${v['book']}:${v['chapter']}').toSet().length, 260);
    expect(
        rows
            .map((v) => '${v['book']}:${v['chapter']}:${v['verse']}')
            .toSet()
            .length,
        rows.length);
    expect(tagged.length, 27);
  });
  test(
      'every reader verse has matching word runs and valid Greek Strong’s tags',
      () {
    var count = 0;
    String normalize(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();
    for (final row in rows) {
      final runs =
          tagged[row['book']]!['${row['chapter']}:${row['verse']}'] as List;
      expect(normalize(runs.map((r) => r['w']).join()),
          normalize(row['text'] as String),
          reason: '${row['book']} ${row['chapter']}:${row['verse']}');
      for (final run in runs) {
        if (run['s'] != '') {
          count++;
          expect(RegExp(r'^G\d+$').hasMatch(run['s'] as String), isTrue);
        }
      }
    }
    expect(count, 138129);
  });
  test('source word morphology and transliteration survive the model', () {
    final runs = tagged['John']!['1:1'] as List;
    final run = TaggedRun.fromJson(Map<String, dynamic>.from(
        runs.firstWhere((r) => r['s'] == 'G3056') as Map));
    expect(run.transliteration, 'Logos');
    expect(run.originalText, 'Λόγος');
    expect(run.grammar, contains('N-NMS'));
  });
  test(
      'the disputed 1 Corinthians 7:15 tag is untagged, with its source text retained',
      () {
    final runs = tagged['1 Corinthians']!['7:15'] as List;
    final disputed =
        runs.singleWhere((r) => r['w'] == '(you)' && r['t'] == 'hymas');
    expect(disputed['s'], '');
    final manifest = jsonDecode(
        File('docs/berean-interlinear-import.json').readAsStringSync());
    expect(manifest['source_strong_conflicts'], hasLength(1));
  });
}
