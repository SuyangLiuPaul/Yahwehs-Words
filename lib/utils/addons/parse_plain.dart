/// Our own two simple formats: JSON and CSV.
///
/// These are the escape hatch. Anybody can produce either from anything — a
/// spreadsheet, a script, a Bible they typed themselves — so they are what
/// the app defines rather than what it reverse-engineers.
///
/// **JSON**: `[{"book":"Genesis","chapter":1,"verse":1,"text":"…"}, …]` —
/// the shape the app has always accepted for a reader's own version
/// (`chapter` and `verse` may be numbers or numeric strings).
///
/// **CSV**: `book,chapter,verse,text` with an optional header row, RFC 4180
/// quoting (fields may contain commas, doubled quotes and line breaks), and
/// comma, semicolon or tab separators.
///
/// `book` is an exact English, 简体 or 繁體 book name (`book_name_resolver`).
/// Text is taken as written — it is the reader's own file, in the app's own
/// markup if they wish — apart from control characters.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'addon_types.dart';
import 'book_name_resolver.dart';
import 'canon_fit.dart';
import 'parse_support.dart';

String _cleanText(String s) {
  final b = StringBuffer();
  for (final r in s.runes) {
    if (r < 0x20 && r != 0x0A && r != 0x09) continue;
    if (r >= 0xE000 && r <= 0xE004) continue;
    b.writeCharCode(r);
  }
  return b.toString().replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();
}

Future<ParsedModule> parseAppJson(Uint8List bytes, ParseContext ctx) async {
  var text = utf8.decode(bytes, allowMalformed: true);
  if (text.startsWith('﻿')) text = text.substring(1);
  dynamic decoded;
  try {
    decoded = json.decode(text);
  } catch (_) {
    throw const ImportRefusal(ImportProblem.corruptFile, detail: 'json');
  }
  if (decoded is! List) {
    throw const ImportRefusal(ImportProblem.notRecognised, detail: 'json');
  }
  final report = ImportReport();
  final fit = CanonFitter(report);
  var n = 0;
  for (final row in decoded) {
    n++;
    await ctx.tick(n, 'parsing', decoded.length);
    if (row is! Map) {
      report.versesDroppedOutsideCanon++;
      continue;
    }
    final name = '${row['book'] ?? ''}'.trim();
    final ch = int.tryParse('${row['chapter']}'.trim());
    final vs = int.tryParse('${row['verse']}'.trim());
    final t = row['text'];
    if (name.isEmpty || ch == null || vs == null || t is! String) {
      report.versesDroppedOutsideCanon++;
      continue;
    }
    final idx = resolveBookName(name);
    if (idx == null) {
      report.dropBook(name);
      continue;
    }
    fit.add(idx, ch, vs, _cleanText(t));
  }
  return ParsedModule(
    format: AddonFormat.appJson,
    meta: const ModuleMeta(),
    verses: fit.finish(),
    report: report,
  );
}

Future<ParsedModule> parseCsv(Uint8List bytes, ParseContext ctx) async {
  var text = utf8.decode(bytes, allowMalformed: true);
  if (text.startsWith('﻿')) text = text.substring(1);
  final firstLine = text.split('\n').first;
  final sep = _separator(firstLine);
  final rows = _parseRows(text, sep);
  if (rows.isEmpty) {
    throw const ImportRefusal(ImportProblem.empty);
  }

  // Header row?
  var cBook = 0, cChap = 1, cVerse = 2, cText = 3;
  var start = 0;
  final head = rows.first.map((c) => c.trim().toLowerCase()).toList();
  if (head.contains('book') && head.contains('text')) {
    cBook = head.indexOf('book');
    cChap = head.indexOf('chapter');
    cVerse = head.indexOf('verse');
    cText = head.indexOf('text');
    if (cChap < 0 || cVerse < 0) {
      throw const ImportRefusal(ImportProblem.notRecognised, detail: 'csv header');
    }
    start = 1;
  } else if (rows.first.length < 4) {
    throw const ImportRefusal(ImportProblem.notRecognised, detail: 'csv columns');
  }

  final report = ImportReport();
  final fit = CanonFitter(report);
  for (var i = start; i < rows.length; i++) {
    await ctx.tick(i, 'parsing', rows.length);
    final r = rows[i];
    final need = [cBook, cChap, cVerse, cText].reduce((a, b) => a > b ? a : b);
    if (r.length <= need) {
      if (r.every((c) => c.trim().isEmpty)) continue;
      report.versesDroppedOutsideCanon++;
      continue;
    }
    final name = r[cBook].trim();
    final ch = int.tryParse(r[cChap].trim());
    final vs = int.tryParse(r[cVerse].trim());
    if (name.isEmpty || ch == null || vs == null) {
      report.versesDroppedOutsideCanon++;
      continue;
    }
    final idx = resolveBookName(name);
    if (idx == null) {
      report.dropBook(name);
      continue;
    }
    fit.add(idx, ch, vs, _cleanText(r[cText]));
  }
  return ParsedModule(
    format: AddonFormat.csv,
    meta: const ModuleMeta(),
    verses: fit.finish(),
    report: report,
  );
}

String _separator(String firstLine) {
  final commas = ','.allMatches(firstLine).length;
  final semis = ';'.allMatches(firstLine).length;
  final tabs = '\t'.allMatches(firstLine).length;
  if (tabs > commas && tabs > semis) return '\t';
  if (semis > commas) return ';';
  return ',';
}

/// RFC 4180: quoted fields may contain the separator, doubled quotes and line
/// breaks. Tolerates a missing final newline and blank lines.
List<List<String>> _parseRows(String text, String sep) {
  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var inQuotes = false;
  var any = false; // has this row seen any character
  final s = sep.codeUnitAt(0);
  for (var i = 0; i < text.length; i++) {
    final c = text.codeUnitAt(i);
    if (inQuotes) {
      if (c == 0x22) {
        if (i + 1 < text.length && text.codeUnitAt(i + 1) == 0x22) {
          field.writeCharCode(0x22);
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        field.writeCharCode(c);
      }
      continue;
    }
    if (c == 0x22 && field.isEmpty) {
      inQuotes = true;
      any = true;
    } else if (c == s) {
      row.add(field.toString());
      field.clear();
      any = true;
    } else if (c == 0x0A || c == 0x0D) {
      if (c == 0x0D && i + 1 < text.length && text.codeUnitAt(i + 1) == 0x0A) i++;
      if (any || field.isNotEmpty) {
        row.add(field.toString());
        rows.add(row);
      }
      row = <String>[];
      field.clear();
      any = false;
    } else {
      field.writeCharCode(c);
      any = true;
    }
  }
  if (any || field.isNotEmpty) {
    row.add(field.toString());
    rows.add(row);
  }
  return rows;
}
