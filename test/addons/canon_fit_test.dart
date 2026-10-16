import 'package:flutter_test/flutter_test.dart';
import 'package:yahwehs_words/utils/addons/addon_types.dart';
import 'package:yahwehs_words/utils/addons/book_name_resolver.dart';
import 'package:yahwehs_words/utils/addons/canon_fit.dart';

void main() {
  test('verse 0 becomes the superscription of verse 1', () {
    final r = ImportReport();
    final f = CanonFitter(r)
      ..add(19, 3, 0, 'A Psalm of David.')
      ..add(19, 3, 1, 'LORD, how are they increased');
    final v = f.finish().single;
    expect(v.superscription, 'A Psalm of David.');
    expect(r.superscriptionsFolded, 1);
  });

  test('a title with no verse 1 to ride on is counted, not invented', () {
    final r = ImportReport();
    final f = CanonFitter(r)..add(19, 3, 0, 'Title');
    expect(f.finish(), isEmpty);
    expect(r.versesDroppedOutsideCanon, 1);
  });

  test('a chapter the canon does not have is dropped and counted', () {
    final r = ImportReport();
    final f = CanonFitter(r)
      ..add(19, 151, 1, 'Psalm 151')
      ..add(19, 150, 1, 'ok')
      ..add(1, 0, 1, 'chapter zero');
    expect(f.finish().length, 1);
    expect(r.versesDroppedOutsideCanon, 2);
  });

  test('a verse past the usual end of its chapter is KEPT', () {
    final f = CanonFitter(ImportReport())..add(1, 1, 40, 'an extra verse');
    expect(f.finish().single.verse, 40);
  });

  test('a duplicate: first wins, the rest counted', () {
    final r = ImportReport();
    final f = CanonFitter(r)
      ..add(1, 1, 1, 'first')
      ..add(1, 1, 1, 'second');
    expect(f.finish().single.text, 'first');
    expect(r.versesDuplicate, 1);
  });

  test('empty text is skipped and counted', () {
    final r = ImportReport();
    final f = CanonFitter(r)..add(1, 1, 1, '');
    expect(f.finish(), isEmpty);
    expect(r.versesEmpty, 1);
  });

  test('output is in canon order whatever order the file was in', () {
    final f = CanonFitter(ImportReport())
      ..add(43, 3, 16, 'b')
      ..add(1, 1, 2, 'a2')
      ..add(1, 1, 1, 'a1');
    expect(f.finish().map((v) => v.text).toList(), ['a1', 'a2', 'b']);
  });

  test('a paragraph that ENDS at a verse opens the next one', () {
    final f = CanonFitter(ImportReport())
      ..add(1, 1, 1, 'a', endsParagraph: true)
      ..add(1, 1, 2, 'b')
      ..add(1, 1, 3, 'c');
    final out = f.finish();
    expect(out.map((v) => v.paragraphStart).toList(), [false, true, false]);
  });

  group('book names', () {
    test('exact English, 简体 and 繁體 names resolve', () {
      expect(resolveBookName('Genesis'), 1);
      expect(resolveBookName('  genesis '), 1);
      expect(resolveBookName('1 Samuel'), 9);
      expect(resolveBookName('创世记'), 1);
      expect(resolveBookName('創世記'), 1);
      expect(resolveBookName('Revelation'), 66);
    });
    test('a few unambiguous alternatives resolve', () {
      expect(resolveBookName('Psalm'), 19);
      expect(resolveBookName('Song of Songs'), 22);
      expect(resolveBookName('Revelation of John'), 66);
    });
    test('abbreviations are NOT guessed', () {
      for (final s in ['Jud', 'Jn', 'Gen', 'Matt', 'Ps', '', 'Tobit']) {
        expect(resolveBookName(s), isNull, reason: '"$s"');
      }
    });
  });
}
