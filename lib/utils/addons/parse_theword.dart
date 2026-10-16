/// theWord Bible modules (`.ont` whole Bible, `.ot`, `.nt`) → [ParsedModule].
///
/// The layout, verified against a real `.ont` by `tools/import_yahweh_ont.py`
/// in the sibling app's repo: UTF-8 (usually with a BOM), ONE VERSE PER LINE
/// in the KJV versification — 31,102 lines for a whole Bible, 23,145 for an
/// Old Testament, 7,957 for a New Testament — followed by a block of
/// `key = value` lines (`short.title`, `version.major`, …).
///
/// A verse the translation does not have is a line that is blank or `- - -`.
///
/// Because the file has no verse NUMBERS, only positions, a file with the
/// wrong number of verse lines cannot be placed at all: it is refused with the
/// count it had, rather than placed wrongly. (Placing Genesis 1:1 on Genesis
/// 1:2 would be worse than not importing.)
///
/// The encrypted variants (`.ontx`, `.otx`, `.ntx`) are refused by name.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'addon_canon.dart';
import 'addon_types.dart';
import 'canon_fit.dart';
import 'markup_normaliser.dart';
import 'parse_support.dart';

const int kTheWordOntLines = 31102;
const int kTheWordOtLines = 23145;
const int kTheWordNtLines = 7957;

enum _Layout { ont, ot, nt }

Future<ParsedModule> parseTheWord(
    Uint8List bytes, String fileName, ParseContext ctx) async {
  final lower = fileName.toLowerCase();
  if (lower.endsWith('.ontx') ||
      lower.endsWith('.otx') ||
      lower.endsWith('.ntx')) {
    throw const ImportRefusal(ImportProblem.encrypted);
  }

  var text = utf8.decode(bytes, allowMalformed: true);
  if (text.startsWith('﻿')) text = text.substring(1);
  final lines = text.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final l = lines[i];
    if (l.endsWith('\r')) lines[i] = l.substring(0, l.length - 1);
  }
  while (lines.isNotEmpty && lines.last.trim().isEmpty) {
    lines.removeLast();
  }

  final layout = _layoutFor(lower, lines.length);
  if (layout == null) {
    throw ImportRefusal(ImportProblem.wrongVerseCount,
        detail: '${lines.length}');
  }
  final need = switch (layout) {
    _Layout.ont => kTheWordOntLines,
    _Layout.ot => kTheWordOtLines,
    _Layout.nt => kTheWordNtLines,
  };
  if (lines.length < need) {
    throw ImportRefusal(ImportProblem.wrongVerseCount,
        detail: '${lines.length}/$need');
  }

  final firstBook = layout == _Layout.nt ? 40 : 1;
  final lastBook = layout == _Layout.ot ? 39 : 66;

  final report = ImportReport();
  final fit = CanonFitter(report);
  var hadStrongs = false;
  var li = 0;
  var n = 0;
  for (var b = firstBook; b <= lastBook; b++) {
    final counts = kCanonVerseCounts[b - 1];
    for (var c = 1; c <= counts.length; c++) {
      for (var v = 1; v <= counts[c - 1]; v++) {
        final line = lines[li++];
        n++;
        await ctx.tick(n, 'parsing', need);
        final t = line.trim();
        if (t.isEmpty || t == '- - -') continue;
        final nv = normaliseVerse(t, MarkupDialect.gbf, report);
        if (nv.hadStrongs) hadStrongs = true;
        fit.add(b, c, v, nv.text,
            paragraphStart: nv.startsParagraph,
            endsParagraph: nv.endsParagraph);
      }
    }
  }

  // The settings block.
  final meta = <String, String>{};
  for (var i = need; i < lines.length; i++) {
    final eq = lines[i].indexOf('=');
    if (eq <= 0) continue;
    meta[lines[i].substring(0, eq).trim().toLowerCase()] =
        lines[i].substring(eq + 1).trim();
  }

  return ParsedModule(
    format: AddonFormat.theWord,
    meta: ModuleMeta(
      title: _cleanMeta(meta['title']) ?? _cleanMeta(meta['short.title']) ?? '',
      abbreviation: _cleanMeta(meta['short.title']) ?? '',
      description: _cleanMeta(meta['description']) ?? '',
      language: _cleanMeta(meta['language']) ?? '',
      strongsPresent: hadStrongs,
      versification: AddonVersification.standard,
    ),
    verses: fit.finish(),
    report: report,
  );
}

String? _cleanMeta(String? s) {
  if (s == null) return null;
  final r = ImportReport();
  final t = normaliseVerse(s, MarkupDialect.zefania, r).text.replaceAll('\n', ' ');
  return t.isEmpty ? null : t;
}

_Layout? _layoutFor(String lowerName, int lineCount) {
  if (lowerName.endsWith('.ont')) return _Layout.ont;
  if (lowerName.endsWith('.ot')) return _Layout.ot;
  if (lowerName.endsWith('.nt')) return _Layout.nt;
  return _layoutForLineCount(lineCount);
}

/// For a file whose name does not say: the layout whose verse count it fits,
/// allowing for the settings block after the verses. Null when it fits none.
_Layout? _layoutForLineCount(int n) {
  if (n >= kTheWordOntLines) return _Layout.ont;
  if (n >= kTheWordOtLines && n < kTheWordOtLines + 500) return _Layout.ot;
  if (n >= kTheWordNtLines && n < kTheWordNtLines + 500) return _Layout.nt;
  return null;
}

/// True when [lineCount] could be a theWord module (the sniffer's test).
bool plausibleTheWordLineCount(int lineCount) =>
    _layoutForLineCount(lineCount) != null;
