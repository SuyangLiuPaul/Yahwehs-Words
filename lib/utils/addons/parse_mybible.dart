/// MyBible.zone Bible modules → [ParsedModule].
///
/// Layout from the published specification (see `mybible_book_numbers.dart`
/// for where). `info(name,value)`, `verses(book_number,chapter,verse,text)`,
/// optional `books_all` / `books` / `stories` / `introductions`.
///
/// Only the Bible is read. Commentaries, dictionaries and cross-reference
/// modules share the file format and are recognised by the sniffer so the
/// reader is told plainly that they are not imported yet.
library;

import 'addon_canon.dart';
import 'addon_types.dart';
import 'canon_fit.dart';
import 'markup_normaliser.dart';
import 'mybible_book_numbers.dart';
import 'parse_support.dart';
import 'sqlite_reader.dart';

Future<ParsedModule> parseMyBibleBible(SqliteFile db, ParseContext ctx) async {
  final report = ImportReport();

  final info = <String, String>{};
  final infoTable = db.table('info');
  if (infoTable != null) {
    final n = infoTable.columnIndex('name');
    final v = infoTable.columnIndex('value');
    if (n >= 0 && v >= 0) {
      db.scan(infoTable, (_, row) {
        info[cellString(row[n]).toLowerCase()] = cellString(row[v]);
      });
    }
  }

  final verses = db.table('verses');
  if (verses == null) {
    throw const ImportRefusal(ImportProblem.unsupportedLayout, detail: 'verses');
  }
  final cBook = verses.columnIndex('book_number');
  final cChap = verses.columnIndex('chapter');
  final cVerse = verses.columnIndex('verse');
  final cText = verses.columnIndex('text');
  if (cBook < 0 || cChap < 0 || cVerse < 0 || cText < 0) {
    throw const ImportRefusal(ImportProblem.unsupportedLayout,
        detail: 'verses columns');
  }

  // Names the file gives its books, only to NAME what is dropped.
  final fileNames = <int, String>{};
  for (final tn in const ['books_all', 'books']) {
    final t = db.table(tn);
    if (t == null) continue;
    final nb = t.columnIndex('book_number');
    final nl = t.columnIndex('long_name');
    final ns = t.columnIndex('short_name');
    if (nb < 0) continue;
    db.scan(t, (_, row) {
      final num = cellInt(row[nb]);
      if (num == null) return;
      final name = cellString(nl >= 0 ? row[nl] : '').trim();
      final short = cellString(ns >= 0 ? row[ns] : '').trim();
      fileNames.putIfAbsent(num, () => name.isNotEmpty ? name : short);
    });
  }

  final fit = CanonFitter(report);
  var hadStrongs = cellTrue(info['strong_numbers']);
  var n = 0;
  final total = 0;

  await db.scanAsync(verses, (_, row) {
    n++;
    final bn = cellInt(row[cBook]);
    final ch = cellInt(row[cChap]);
    final vs = cellInt(row[cVerse]);
    if (bn == null || ch == null || vs == null) {
      report.versesDroppedOutsideCanon++;
      return;
    }
    final idx = kMyBibleCanonIndex[bn];
    if (idx == null) {
      final other = kMyBibleOtherBooks[bn];
      final name = other ??
          (fileNames[bn]?.isNotEmpty == true ? fileNames[bn]! : '#$bn');
      report.dropBook(name);
      return;
    }
    final nv = normaliseVerse(cellString(row[cText]), MarkupDialect.myBible, report);
    if (nv.hadStrongs) hadStrongs = true;
    fit.add(idx, ch, vs, nv.text,
        paragraphStart: nv.startsParagraph, endsParagraph: nv.endsParagraph);
  }, cancelled: () => ctx.cancel?.cancelled ?? false);
  ctx.checkCancelled();
  ctx.onProgress?.call('parsing', n, total);

  // Subheadings in their own table are not shown (yet): count, say so.
  final stories = db.table('stories');
  if (stories != null) {
    var c = 0;
    db.scan(stories, (_, __) => c++);
    report.headingsDropped += c;
  }

  final russian = cellTrue(info['russian_numbering']);
  if (russian) report.warn('russianNumbering');
  if (info['right_to_left'] != null && cellTrue(info['right_to_left'])) {
    report.warn('rightToLeft');
  }

  final finalVerses = fit.finish();

  final title = (info['description'] ?? '').trim();
  return ParsedModule(
    format: AddonFormat.myBible,
    meta: ModuleMeta(
      title: title,
      description: _plainInfo(info['detailed_info'] ?? ''),
      language: (info['language'] ?? '').trim(),
      rightToLeft: cellTrue(info['right_to_left']),
      strongsPresent: hadStrongs,
      versification: russian
          ? AddonVersification.russianPsalms
          : AddonVersification.standard,
    ),
    verses: finalVerses,
    report: report,
  );
}

/// `detailed_info` is an HTML snippet; keep its words, never its markup.
String _plainInfo(String html) {
  if (html.isEmpty) return '';
  final r = ImportReport();
  return normaliseVerse(html.replaceAll(RegExp(r'</?(p|div|br)[^>]*>'), ' '),
          MarkupDialect.zefania, r)
      .text
      .replaceAll('\n', ' ');
}

/// Which module kind a MyBible-layout SQLite file is, by its tables.
AddonKind myBibleKind(SqliteFile db) {
  if (db.hasTable('commentaries')) return AddonKind.commentary;
  if (db.hasTable('cross_references')) return AddonKind.crossReferences;
  final d = db.table('dictionary');
  if (d != null && d.columnIndex('topic') >= 0) return AddonKind.dictionary;
  final v = db.table('verses');
  if (v != null && v.columnIndex('book_number') >= 0) return AddonKind.bible;
  return AddonKind.other;
}

/// Total verses the canon has — exposed for the report's "N of 31,102".
int get kCanonVerseTotal => kCanonVerseCounts.fold<int>(
    0, (a, b) => a + b.fold<int>(0, (x, y) => x + y));
