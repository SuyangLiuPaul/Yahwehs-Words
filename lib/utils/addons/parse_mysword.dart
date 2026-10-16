/// MySword `.bbl.mybible` Bible modules → [ParsedModule].
///
/// Layout verified against a real publisher module by
/// `tools/import_yahweh_modules.py` in the sibling app's repo:
/// `Bible(Book, Chapter, Verse, Scripture)` with plain 1–66 book numbers, and
/// a one-row `Details` table. `Details` is not exercised by that script, so
/// every column of it is treated as optional.
///
/// An encrypted module (`Details.Encryption` non-zero) is refused by name —
/// the app never tries to open what its publisher locked.
library;

import 'addon_types.dart';
import 'canon_fit.dart';
import 'markup_normaliser.dart';
import 'parse_support.dart';
import 'sqlite_reader.dart';

Future<ParsedModule> parseMySwordBible(SqliteFile db, ParseContext ctx) async {
  final report = ImportReport();

  final details = <String, Object?>{};
  final dt = db.table('Details');
  if (dt != null) {
    var first = true;
    db.scan(dt, (_, row) {
      if (!first) return;
      first = false;
      for (var i = 0; i < dt.columns.length && i < row.length; i++) {
        details[dt.columns[i].toLowerCase()] = row[i];
      }
    });
  }
  final enc = details['encryption'];
  if (enc != null && '$enc'.trim().isNotEmpty && '$enc'.trim() != '0') {
    throw const ImportRefusal(ImportProblem.encrypted);
  }

  final bible = db.table('Bible');
  if (bible == null) {
    throw const ImportRefusal(ImportProblem.unsupportedLayout, detail: 'Bible');
  }
  final cBook = bible.columnIndex('Book');
  final cChap = bible.columnIndex('Chapter');
  final cVerse = bible.columnIndex('Verse');
  final cText = bible.columnIndex('Scripture');
  if (cBook < 0 || cChap < 0 || cVerse < 0 || cText < 0) {
    throw const ImportRefusal(ImportProblem.unsupportedLayout,
        detail: 'Bible columns');
  }

  final fit = CanonFitter(report);
  var hadStrongs = cellTrue(details['strong']);
  var n = 0;
  await db.scanAsync(bible, (_, row) {
    n++;
    final b = cellInt(row[cBook]);
    final ch = cellInt(row[cChap]);
    final vs = cellInt(row[cVerse]);
    if (b == null || ch == null || vs == null) {
      report.versesDroppedOutsideCanon++;
      return;
    }
    if (b < 1 || b > 66) {
      report.dropBook('#$b');
      return;
    }
    final nv =
        normaliseVerse(cellString(row[cText]), MarkupDialect.gbf, report);
    if (nv.hadStrongs) hadStrongs = true;
    fit.add(b, ch, vs, nv.text,
        paragraphStart: nv.startsParagraph, endsParagraph: nv.endsParagraph);
  }, cancelled: () => ctx.cancel?.cancelled ?? false);
  ctx.checkCancelled();
  ctx.onProgress?.call('parsing', n, 0);

  final rtl = cellTrue(details['righttoleft']);
  if (rtl) report.warn('rightToLeft');

  return ParsedModule(
    format: AddonFormat.mySword,
    meta: ModuleMeta(
      title: cellString(details['title']).trim(),
      abbreviation: cellString(details['abbreviation']).trim(),
      description: _plain(cellString(details['description'])),
      language: cellString(details['language']).trim(),
      rightToLeft: rtl,
      strongsPresent: hadStrongs,
      versification: AddonVersification.unknown,
    ),
    verses: fit.finish(),
    report: report,
  );
}

String _plain(String s) {
  if (s.isEmpty) return '';
  final r = ImportReport();
  return normaliseVerse(s, MarkupDialect.zefania, r).text.replaceAll('\n', ' ');
}

/// What a MySword-family SQLite file is, by its tables. `Bible` + `Details`
/// is a Bible; e-Sword 11's `.bbli` has the same two tables but its `Details`
/// carries `OldTestament` / `NewTestament`, which MySword's does not.
AddonKind mySwordKind(SqliteFile db) {
  if (db.hasTable('Bible')) return AddonKind.bible;
  if (db.hasTable('Commentary') || db.hasTable('commentary')) {
    return AddonKind.commentary;
  }
  if (db.hasTable('dictionary') || db.hasTable('Dictionary')) {
    return AddonKind.dictionary;
  }
  return AddonKind.other;
}

/// True when the Details table looks like e-Sword's rather than MySword's.
bool looksLikeESword(SqliteFile db) {
  final d = db.table('Details');
  if (d == null) return false;
  return d.columnIndex('OldTestament') >= 0 ||
      d.columnIndex('NewTestament') >= 0;
}
