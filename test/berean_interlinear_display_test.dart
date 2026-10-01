import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yahwehs_words/services/fetch_verses.dart';
import 'package:yahwehs_words/services/tagged_text_service.dart';
import 'package:yahwehs_words/utils/berean_interlinear_display.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String normalize(String text) => text.replaceAll(RegExp(r'\s+'), ' ').trim();

  test('only BIB omits empty English wrappers, retaining real glosses', () {
    const source = 'τὸν () Ἰσαάκ (Isaac), ‹ὁ› ( )';
    expect(formatBereanInterlinearText(source, version: 'bib'),
        'τὸν Ἰσαάκ (Isaac), ‹ὁ›');
    expect(formatBereanInterlinearText(source, version: 'BIB'),
        'τὸν Ἰσαάκ (Isaac), ‹ὁ›');
    for (final edition in ['bsb-yhwh', 'cuvs-yhwh', 'user-fixture', '']) {
      expect(formatBereanInterlinearText(source, version: edition), source);
    }
  });

  test('Greek article receives the empty gloss metadata and stays tappable',
      () {
    final raw = <TaggedRun>[
      const TaggedRun(text: ', [τὸν', strongs: ''),
      const TaggedRun(text: '] ', strongs: ''),
      const TaggedRun(
          text: '()',
          strongs: 'G3588',
          grammar: ['Art-AMS'],
          transliteration: 'ton',
          originalText: 'τὸν'),
      const TaggedRun(text: ' Ἰσαάκ ', strongs: ''),
    ];
    final formatted = TaggedTextService.formatBereanRuns(raw);
    expect(formatted.map((r) => r.text).join(), ', [τὸν] Ἰσαάκ ');
    final article = formatted.singleWhere((r) => r.isTagged);
    expect(article.text, 'τὸν');
    expect(article.strongs, 'G3588');
    expect(article.grammar, ['Art-AMS']);
    expect(article.transliteration, 'ton');
    expect(article.originalText, 'τὸν');
    expect(raw[2].text, '()', reason: 'the source runs are never mutated');
  });

  test('an unmatched future source pair keeps its metadata without guessing',
      () {
    const unmatched = TaggedRun(
        text: '()',
        strongs: 'G3588',
        transliteration: 'ton',
        originalText: 'τὸν');
    final formatted = TaggedTextService.formatBereanRuns([
      const TaggedRun(text: 'θεός ', strongs: ''),
      unmatched,
    ]);
    expect(formatted.last, same(unmatched));
  });

  test(
      'an ambiguous future Greek span keeps its diagnostic instead of relabeling',
      () {
    const empty = TaggedRun(
        text: '()',
        strongs: 'G3588',
        transliteration: 'ton',
        originalText: 'τὸν');
    final formatted = TaggedTextService.formatBereanRuns([
      const TaggedRun(text: 'τὸν τὸν ', strongs: ''),
      empty,
    ]);
    expect(formatted.last, same(empty));
  });

  test('all real BIB empty glosses keep Greek, Strong codes and morphology',
      () {
    var emptyGlosses = 0;
    for (final file
        in Directory('assets/tagged/bib').listSync().whereType<File>()) {
      final verses =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      for (final entry in verses.entries) {
        final raw = (entry.value as List)
            .map((r) => TaggedRun.fromJson(Map<String, dynamic>.from(r as Map)))
            .toList();
        final formatted = TaggedTextService.formatBereanRuns(raw);
        final context = '${file.path} ${entry.key}';
        final sourceText = raw.map((r) => r.text).join();
        expect(normalize(formatted.map((r) => r.text).join()),
            normalize(formatBereanInterlinearText(sourceText, version: 'bib')),
            reason: context);
        List<Object?> metadata(List<TaggedRun> runs) => [
              for (final r in runs.where((r) => r.transliteration != null))
                (
                  r.strongs,
                  r.implied.join('|'),
                  r.grammar.join('|'),
                  r.transliteration,
                  r.originalText
                ),
            ];
        expect(metadata(formatted), metadata(raw), reason: context);
        for (final run
            in raw.where((r) => RegExp(r'^\(\s*\)$').hasMatch(r.text))) {
          emptyGlosses++;
          expect(
              formatted.where((r) =>
                  r.text == run.originalText &&
                  r.strongs == run.strongs &&
                  r.transliteration == run.transliteration &&
                  r.grammar.join('|') == run.grammar.join('|')),
              isNotEmpty,
              reason: '$context must retain its Greek tap target');
        }
      }
    }
    expect(emptyGlosses, greaterThan(0),
        reason: 'exercise the actual imported empty glosses');
  });

  test('Greek substring and note boundaries never become invented tap targets',
      () {
    const article = TaggedRun(
        text: '()', strongs: 'G3588', transliteration: 'ho', originalText: 'ὁ');
    final insideWord = TaggedTextService.formatBereanRuns([
      const TaggedRun(text: 'ὁμοῦ ', strongs: ''),
      article,
    ]);
    expect(insideWord.last, same(article));
    final acrossNote = TaggedTextService.formatBereanRuns([
      const TaggedRun(text: 'ὁ ', strongs: ''),
      const TaggedRun(text: '<note:source footnote>', strongs: ''),
      article,
    ]);
    expect(acrossNote.last, same(article));
    expect(acrossNote[1].text, '<note:source footnote>');
  });

  test(
      'empty gloss normalization preserves variant markers and split source runs',
      () {
    for (final source in ['τὸν', ', τὸν', '‹τὸν›', '[τὸν]']) {
      final out = TaggedTextService.formatBereanRuns([
        TaggedRun(text: source, strongs: ''),
        const TaggedRun(text: ' ', strongs: ''),
        const TaggedRun(
            text: '()',
            strongs: 'G3588',
            grammar: ['Art-AMS'],
            transliteration: 'ton',
            originalText: 'τὸν'),
      ]);
      expect(out.map((r) => r.text).join(), source);
      expect(out.singleWhere((r) => r.isTagged).text, 'τὸν');
    }
    const translated = TaggedRun(
        text: '(the)',
        strongs: 'G3588',
        transliteration: 'ho',
        originalText: 'ὁ');
    expect(TaggedTextService.formatBereanRuns([translated]).single,
        same(translated));
  });

  test('case-sensitive bundle resolves BIB normal and numbered book files',
      () async {
    for (final (book, chapter, verse) in [
      ('Matthew', 1, 2),
      ('John', 1, 2),
      ('1 John', 1, 2),
      ('Romans', 4, 6),
    ]) {
      final runs = await TaggedTextService.forVerse(
          version: 'bib', englishBook: book, chapter: chapter, verse: verse);
      expect(runs, isNotNull,
          reason: '$book uses the actual TitleCase asset key');
      expect(runs!.where((r) => r.isTagged), isNotEmpty);
      expect(runs.where((r) => RegExp(r'^\(\s*\)$').hasMatch(r.text)), isEmpty);
    }
  });

  test('loaded BIB reader text omits wrappers without changing imported source',
      () async {
    final rows = await FetchVerses.loadVerseList('bib');
    expect(rows, isNotNull);
    final verse = rows!.singleWhere(
        (r) => r.book == 'Matthew' && r.chapter == 1 && r.verse == 2);
    expect(verse.text, contains('τὸν Ἰσαάκ (Isaac)'));
    expect(verse.text, isNot(contains('()')));
    final original =
        jsonDecode(File('assets/bib.json').readAsStringSync()) as List;
    final source = original.singleWhere((r) =>
        r['book'] == 'Matthew' &&
        r['chapter'] == '1' &&
        r['verse'] == '2')['text'] as String;
    expect(source, contains('τὸν () Ἰσαάκ (Isaac)'));
  });

  test('existing lowercase tagged editions retain their own text', () async {
    final runs = await TaggedTextService.forVerse(
        version: 'bsb-yhwh', englishBook: 'Genesis', chapter: 1, verse: 1);
    expect(runs, isNotNull);
    expect(
        runs!.firstWhere((r) => r.text.contains('created')).strongs, 'H1254');
  });
}
