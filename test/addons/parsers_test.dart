// Every parser, against the synthetic fixtures built by
// tools/make_addon_fixtures.py (and, for theWord's whole-Bible layout, a file
// built here from the canon's verse counts).
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:yahwehs_words/utils/addons/addon_canon.dart';
import 'package:yahwehs_words/utils/addons/addon_types.dart';
import 'package:yahwehs_words/utils/addons/parse_module.dart';

Uint8List _fx(String name) =>
    Uint8List.fromList(File('test/fixtures/addons/$name').readAsBytesSync());

Future<ParsedModule> _parse(String file, [String? asName]) =>
    parseModule(_fx(file), asName ?? file);

ParsedVerse? _v(ParsedModule m, String book, int c, int v) {
  final b = kCanonBooks.indexOf(book) + 1;
  for (final x in m.verses) {
    if (x.book == b && x.chapter == c && x.verse == v) return x;
  }
  return null;
}

Future<ImportRefusal> _refusal(Future<ParsedModule> f) async {
  try {
    await f;
  } on ImportRefusal catch (e) {
    return e;
  }
  fail('expected an ImportRefusal');
}

void main() {
  group('MyBible.zone', () {
    test('a small Bible: text, markup and metadata', () async {
      final m = await _parse('mybible_min.SQLite3');
      expect(m.format, AddonFormat.myBible);
      expect(m.meta.title, 'Synthetic Test Bible');
      expect(m.meta.language, 'en');
      expect(m.meta.strongsPresent, isTrue);
      expect(m.verses.length, 8);
      expect(_v(m, 'Genesis', 1, 1)!.text,
          'In the beginning God created the heaven and the earth.');
      // <i> → [..], <pb/> mid-verse is not a newline, text kept
      expect(_v(m, 'Genesis', 1, 2)!.text,
          'And the earth was [without form], and void;and darkness was upon the face of the deep.');
      // <S>, <J> stripped, <n> a note
      expect(_v(m, 'Genesis', 1, 4)!.text,
          'And God saw the light, that it was good<note: note one>.');
      expect(_v(m, 'Genesis', 2, 1)!.text,
          'Thus the heavens and the earth were finished\nand all the host of them.');
      // <f> marker dropped, <m> dropped
      expect(_v(m, 'John', 3, 16)!.text,
          'For God so loved the world, that he gave his only begotten Son.');
      expect(_v(m, 'John', 3, 17)!.text,
          'For God sent not his Son into the world to condemn the world.');
      expect(_v(m, 'Revelation', 22, 21)!.book, 66);
      expect(m.report.strongsTagsDropped, 1);
      expect(m.report.footnoteMarkersDropped, 1);
      expect(m.report.versesAccepted, 8);
    });

    test('books_all, subheadings, and a psalm title numbered 0', () async {
      final m = await _parse('mybible_books_all.SQLite3');
      expect(m.verses.length, 3); // verse 0 is folded onto verse 1, not a verse
      final ps = _v(m, 'Psalms', 23, 1)!;
      expect(ps.superscription, 'A Psalm of David.');
      expect(ps.text, 'The LORD is my shepherd; I shall not want.');
      expect(m.report.superscriptionsFolded, 1);
      expect(m.report.headingsDropped, 1); // the `stories` row
    });

    test('Russian numbering is recorded, not remapped; foreign books are named',
        () async {
      final m = await _parse('mybible_russian.SQLite3');
      expect(m.meta.versification, AddonVersification.russianPsalms);
      expect(m.report.warnings.map((w) => w.code), contains('russianNumbering'));
      expect(_v(m, 'Psalms', 22, 1)!.text, contains('Russian numbering'));
      expect(m.report.booksDropped.keys,
          containsAll(['Prayer of Manasseh', 'Additions to Esther', 'To the Laodiceans', '#999']));
      expect(m.verses.length, 2); // Psalm 22:1 and Genesis 1:1
    });

    test('a deep b-tree is read completely', () async {
      final m = await _parse('mybible_deep_tree.SQLite3');
      final expected = (json.decode(
              File('test/fixtures/addons/mybible_deep_tree.expected.json')
                  .readAsStringSync()) as Map)['verses'] as List;
      expect(m.verses.length, expected.length);
      expect(m.report.versesDuplicate, 0);
    });

    test('verses longer than a page survive overflow intact', () async {
      final m = await _parse('mybible_overflow.SQLite3');
      final long = m.verses.map((v) => v.text.length).reduce((a, b) => a > b ? a : b);
      expect(long, 11000 - 12 + '#11000'.length);
    });

    test('commentaries, dictionaries are recognised but not imported', () async {
      var r = await _refusal(_parse('mybible_commentary.SQLite3'));
      expect(r.problem, ImportProblem.notABible);
      expect(r.detail, 'commentary');
      r = await _refusal(_parse('mybible_dictionary.SQLite3'));
      expect(r.problem, ImportProblem.notABible);
      expect(r.detail, 'dictionary');
    });

    test('the file NAME is irrelevant: detection is by content', () async {
      final m = await _parse('mybible_min.SQLite3', 'my-renamed-file.bin');
      expect(m.format, AddonFormat.myBible);
    });
  });

  group('MySword', () {
    test('a Bible: tags normalised, out-of-canon book named', () async {
      final m = await _parse('mysword_bible.bbl.mybible');
      expect(m.format, AddonFormat.mySword);
      expect(m.meta.title, 'MySword Test Bible');
      expect(m.meta.abbreviation, 'MST');
      expect(m.meta.language, 'eng');
      expect(m.meta.strongsPresent, isTrue);
      expect(_v(m, 'Genesis', 1, 2)!.text,
          'And the earth was [without form], and void;and darkness was upon the face of the deep.');
      expect(_v(m, 'Genesis', 1, 3)!.text,
          'And God said, Let there be light<note: a footnote>.');
      expect(_v(m, 'John', 3, 16)!.text,
          'For God so loved the world, that he gave his only begotten Son.');
      expect(m.report.booksDropped, {'#67': 1});
      expect(m.report.crossRefsDropped, 1);
      expect(m.report.headingsDropped, 1);
    });

    test('an encrypted module is refused by name', () async {
      final r = await _refusal(_parse('mysword_encrypted.bbl.mybible'));
      expect(r.problem, ImportProblem.encrypted);
    });

    test('a Chinese module reports its language', () async {
      final m = await _parse('mysword_zh.bbl.mybible');
      expect(m.meta.language, 'zho');
      expect(_v(m, 'Genesis', 1, 1)!.text, '起初神创造天地。');
    });
  });

  group('theWord', () {
    test('a New Testament: positions become references', () async {
      final m = await _parse('theword_nt.nt');
      expect(m.format, AddonFormat.theWord);
      expect(m.verses.length, 7957 - 1); // one `- - -` gap
      expect(_v(m, 'Matthew', 1, 1)!.text,
          'The book of the generation of [Jesus] Christ, the son of David.');
      expect(_v(m, 'Matthew', 1, 2), isNull, reason: '"- - -" is an absent verse');
      expect(_v(m, 'John', 3, 16)!.text,
          'For God so loved the world, that he gave his only begotten Son<note: some witnesses omit this>.');
      expect(_v(m, 'Revelation', 22, 21)!.text,
          'The grace of our Lord Jesus Christ be with you all. Amen.');
      expect(m.meta.abbreviation, 'SYN');
      expect(m.meta.title, 'Synthetic theWord NT');
      expect(m.meta.strongsPresent, isTrue);
      expect(m.books.length, 27);
      expect(m.coversOldTestament, isFalse);
      expect(m.coversNewTestament, isTrue);
    });

    test('a damaged tag never leaks a number into Mark 1:1', () async {
      final m = await _parse('theword_nt.nt');
      final t = _v(m, 'Mark', 1, 1)!.text;
      expect(t, 'The beginning of the gospel of Jesus Christ.');
      expect(RegExp(r'\d').hasMatch(t), isFalse);
    });

    test('<CM> at the end of a verse opens a paragraph on the next', () async {
      final m = await _parse('theword_nt.nt');
      // Revelation 22:21 ends with <CM>; nothing follows, so nothing opens.
      expect(_v(m, 'Revelation', 22, 21)!.paragraphStart, isFalse);
    });

    test('the wrong number of verse lines is refused WITH the count', () async {
      final r = await _refusal(_parse('theword_nt_short.nt'));
      expect(r.problem, ImportProblem.wrongVerseCount);
      expect(r.detail, '7956/7957');
    });

    test('a whole Bible has exactly 31,102 verse lines', () async {
      final lines = <String>[];
      for (var b = 0; b < 66; b++) {
        for (var c = 0; c < kCanonVerseCounts[b].length; c++) {
          for (var v = 1; v <= kCanonVerseCounts[b][c]; v++) {
            lines.add('${kCanonBooks[b]} ${c + 1}:$v text<WH1>');
          }
        }
      }
      expect(lines.length, 31102);
      final bytes = Uint8List.fromList(
          utf8.encode('﻿${[...lines, 'short.title = WB'].join('\r\n')}\r\n'));
      final m = await parseModule(bytes, 'whole.ont');
      expect(m.verses.length, 31102);
      expect(m.meta.abbreviation, 'WB');
      expect(m.books.length, 66);
      expect(_v(m, 'Genesis', 1, 1)!.text, 'Genesis 1:1 text');
      expect(_v(m, 'Revelation', 22, 21)!.text, 'Revelation 22:21 text');
    });

    test('an Old Testament: 23,145 lines', () async {
      final lines = <String>[];
      for (var b = 0; b < 39; b++) {
        for (var c = 0; c < kCanonVerseCounts[b].length; c++) {
          for (var v = 1; v <= kCanonVerseCounts[b][c]; v++) {
            lines.add('x');
          }
        }
      }
      expect(lines.length, 23145);
      final m = await parseModule(
          Uint8List.fromList(utf8.encode(lines.join('\n'))), 'old.ot');
      expect(m.coversOldTestament, isTrue);
      expect(m.coversNewTestament, isFalse);
    });

    test('an encrypted extension is refused', () async {
      final r = await _refusal(
          parseModule(Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]), 'bible.ontx'));
      expect(r.problem, ImportProblem.encrypted);
    });
  });

  group('Zefania', () {
    test('a sloppy file: mismatched tags, a lying book, a foreign book', () async {
      final m = await _parse('zefania_sloppy.xml');
      expect(m.format, AddonFormat.zefania);
      expect(m.meta.title, 'Sloppy Test Bible');
      expect(m.meta.language, 'ENG');
      expect(_v(m, 'Genesis', 1, 3)!.text,
          'And God said, Let there be light<note: a note>: and there was light.');
      expect(_v(m, 'Genesis', 1, 2)!.text,
          'And the earth was without form, and void;\nand darkness was upon the face of the deep.');
      expect(_v(m, 'Genesis', 1, 4)!.text,
          'And God saw the light, that it was good: & God divided the light from the darkness.');
      expect(_v(m, 'John', 3, 16)!.text,
          'For God so loved the world, that he gave his only begotten Son.');
      // bnumber 2 says "Exodus", bname says Matthew: refused, not guessed.
      expect(_v(m, 'Exodus', 1, 1), isNull);
      expect(_v(m, 'Matthew', 1, 1), isNull);
      expect(m.report.booksDropped['Matthew'], 1);
      expect(m.report.booksDropped['Tobit'], 1);
      expect(m.report.warnings.map((w) => w.code), contains('zefaniaBookMismatch'));
      expect(m.report.headingsDropped, 1);
      expect(m.report.crossRefsDropped, 1);
    });
  });

  group('JSON and CSV', () {
    test('JSON', () async {
      final m = await _parse('addon.json');
      expect(m.format, AddonFormat.appJson);
      expect(m.verses.length, 3);
      expect(_v(m, 'John', 3, 16)!.text, 'For God so loved the world.');
    });

    test('CSV: quotes, doubled quotes, line breaks inside a field', () async {
      final m = await _parse('addon.csv');
      expect(m.format, AddonFormat.csv);
      expect(m.verses.length, 3);
      expect(_v(m, 'Genesis', 1, 2)!.text,
          'And the earth was without form, and void;\nand darkness was upon the face of the deep.');
      expect(_v(m, 'John', 3, 16)!.text,
          'For God so loved the world, that he gave his only begotten Son, "believe".');
      expect(m.report.booksDropped, {'Tobit': 1});
    });

    test('CSV without a header, semicolon separated, Chinese book names', () async {
      final csv = '创世记;1;1;起初神创造天地。\n創世記;1;2;地是空虛混沌。\n';
      final m = await parseModule(Uint8List.fromList(utf8.encode(csv)), 'x.csv');
      expect(m.verses.length, 2);
      expect(m.verses.first.book, 1);
    });

    test('a book that is not an exact name is dropped, never guessed', () async {
      final csv = 'book,chapter,verse,text\nJud,1,1,which book?\nGenesis,1,1,ok\n';
      final m = await parseModule(Uint8List.fromList(utf8.encode(csv)), 'x.csv');
      expect(m.verses.length, 1);
      expect(m.report.booksDropped, {'Jud': 1});
    });
  });

  group('refusals', () {
    test('nothing', () async {
      expect((await _refusal(parseModule(Uint8List(0), 'a.json'))).problem,
          ImportProblem.empty);
    });
    test('a zip archive', () async {
      final r = await _refusal(parseModule(
          Uint8List.fromList([0x50, 0x4B, 0x03, 0x04, 0, 0, 0, 0]), 'kjv.zip'));
      expect(r.problem, ImportProblem.zipArchive);
    });
    test('e-Sword', () async {
      final r = await _refusal(
          parseModule(Uint8List.fromList(utf8.encode('x' * 50)), 'KJV.bblx'));
      expect(r.problem, ImportProblem.eSword);
    });
    test('something we have never heard of', () async {
      final r = await _refusal(
          parseModule(Uint8List.fromList(utf8.encode('hello world\n' * 5)), 'a.dat'));
      expect(r.problem, ImportProblem.notRecognised);
    });
    test('a damaged SQLite file', () async {
      final b = _fx('mybible_min.SQLite3');
      final cut = Uint8List.sublistView(b, 0, 4096 + 100);
      final r = await _refusal(parseModule(cut, 'x.SQLite3'));
      expect(r.problem, anyOf(ImportProblem.corruptFile, ImportProblem.notRecognised,
          ImportProblem.unsupportedLayout));
    });
    test('cancelling stops the parse and imports nothing', () async {
      final cancel = CancelToken()..cancel();
      final r = await _refusal(parseModule(_fx('mybible_deep_tree.SQLite3'),
          'x.SQLite3', cancel: cancel));
      expect(r.problem, ImportProblem.cancelled);
    });
  });
}
