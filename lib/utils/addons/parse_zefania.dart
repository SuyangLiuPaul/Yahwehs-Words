/// Zefania XML Bibles → [ParsedModule].
///
/// Zefania is an open XML Bible format: `XMLBIBLE` › `BIBLEBOOK` (`bnumber`,
/// `bname`) › `CHAPTER` (`cnumber`) › `VERS` (`vnumber`). Real files are
/// sloppy — mismatched or lower-cased closing tags, wrong abbreviations — and
/// a strict XML parser rejects a whole Bible for one stray `</vers>`. So this
/// is a forgiving scanner over the four structural tags, not an XML parser; a
/// verse ends at the next structural tag, whatever it was closed with.
///
/// A book is matched by `bnumber` AND `bname`. When they disagree the book is
/// REFUSED, named in the report: a Zefania file that calls book 2 "Matthew" is
/// telling us it was numbered by something else, and guessing which of its two
/// claims is right would put scripture under the wrong heading.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'addon_types.dart';
import 'book_name_resolver.dart';
import 'canon_fit.dart';
import 'markup_normaliser.dart';
import 'parse_support.dart';

final RegExp _structure = RegExp(
    r'<(/?)(BIBLEBOOK|CHAPTER|VERS)\b([^>]*)>',
    caseSensitive: false);
final RegExp _attr =
    RegExp(r'''([A-Za-z_:][\w:.-]*)\s*=\s*(?:"([^"]*)"|'([^']*)')''');

Map<String, String> _attrs(String s) => {
      for (final m in _attr.allMatches(s))
        m[1]!.toLowerCase(): m[2] ?? m[3] ?? '',
    };

int? _leadingInt(String? s) {
  if (s == null) return null;
  final m = RegExp(r'^\s*(\d+)').firstMatch(s);
  return m == null ? null : int.tryParse(m[1]!);
}

Future<ParsedModule> parseZefania(Uint8List bytes, ParseContext ctx) async {
  var text = _decode(bytes);
  if (text.startsWith('﻿')) text = text.substring(1);

  final report = ImportReport();
  final fit = CanonFitter(report);
  var hadStrongs = false;

  report.headingsDropped +=
      RegExp(r'<CAPTION\b', caseSensitive: false).allMatches(text).length;

  // Book/chapter state while walking the structural tags in order.
  int? book; // canon index, or null when the current book is not imported
  var bookName = '';
  var bookDropped = false;
  int? chapter;
  final matches = _structure.allMatches(text).toList();
  var counted = 0;
  for (var i = 0; i < matches.length; i++) {
    final m = matches[i];
    final closing = m[1] == '/';
    final tag = m[2]!.toUpperCase();
    final attrs = _attrs(m[3] ?? '');
    switch (tag) {
      case 'BIBLEBOOK':
        if (closing) {
          book = null;
          chapter = null;
          break;
        }
        chapter = null;
        bookName = (attrs['bname'] ?? attrs['bsname'] ?? '').trim();
        final bn = _leadingInt(attrs['bnumber']);
        final byName = bookName.isEmpty ? null : resolveBookName(bookName);
        bookDropped = false;
        if (bn != null && bn >= 1 && bn <= 66) {
          if (byName != null && byName != bn) {
            report.dropBook(bookName.isEmpty ? '#$bn' : bookName, 0);
            report.warn('zefaniaBookMismatch', '$bookName ($bn)');
            book = null;
            bookDropped = true;
          } else {
            book = bn;
          }
        } else {
          // Outside 1–66: a book the app does not carry — unless its NAME
          // claims a canonical book, which contradicts its number.
          if (byName != null) report.warn('zefaniaBookMismatch', '$bookName ($bn)');
          report.dropBook(bookName.isEmpty ? '#${bn ?? '?'}' : bookName, 0);
          book = null;
          bookDropped = true;
        }
      case 'CHAPTER':
        if (closing) {
          chapter = null;
          break;
        }
        chapter = _leadingInt(attrs['cnumber']);
      case 'VERS':
        if (closing) break;
        final v = _leadingInt(attrs['vnumber']);
        // Content runs to the next structural tag, whatever it is.
        final start = m.end;
        final end = i + 1 < matches.length ? matches[i + 1].start : text.length;
        final raw = text.substring(start, end);
        counted++;
        await ctx.tick(counted, 'parsing', 0);
        if (bookDropped) {
          report.dropBook(bookName.isEmpty ? '?' : bookName);
          break;
        }
        if (book == null || chapter == null || v == null) {
          report.versesDroppedOutsideCanon++;
          break;
        }
        final nv = normaliseVerse(raw, MarkupDialect.zefania, report);
        if (nv.hadStrongs) hadStrongs = true;
        fit.add(book, chapter, v, nv.text,
            paragraphStart: nv.startsParagraph, endsParagraph: nv.endsParagraph);
    }
  }
  // dropBook(name, 0) registered the name; make sure a book that only had
  // zero counted verses still shows with at least what we counted above.
  report.booksDropped.removeWhere((k, v) => v == 0);

  final title = _firstTag(text, 'title') ?? _attrs(_rootAttrs(text))['biblename'] ?? '';
  return ParsedModule(
    format: AddonFormat.zefania,
    meta: ModuleMeta(
      title: _plainMeta(title),
      description: _plainMeta(_firstTag(text, 'description') ?? ''),
      language: _plainMeta(_firstTag(text, 'language') ?? ''),
      strongsPresent: hadStrongs,
    ),
    verses: fit.finish(),
    report: report,
  );
}

String _rootAttrs(String text) {
  final m = RegExp(r'<XMLBIBLE\b([^>]*)>', caseSensitive: false).firstMatch(text);
  return m?[1] ?? '';
}

String? _firstTag(String text, String name) {
  final m = RegExp('<$name[^>]*>(.*?)</$name>', caseSensitive: false, dotAll: true)
      .firstMatch(text);
  return m?[1]?.trim();
}

String _plainMeta(String s) {
  if (s.isEmpty) return '';
  final r = ImportReport();
  return normaliseVerse(s, MarkupDialect.zefania, r).text.replaceAll('\n', ' ');
}

/// UTF-8 unless the XML declaration says otherwise.
String _decode(Uint8List bytes) {
  final head = latin1.decode(bytes.sublist(0, bytes.length < 200 ? bytes.length : 200));
  final m = RegExp(r'''encoding\s*=\s*["']([^"']+)["']''', caseSensitive: false)
      .firstMatch(head);
  final enc = m?[1]?.toLowerCase();
  if (enc == 'iso-8859-1' || enc == 'latin1' || enc == 'windows-1252') {
    return latin1.decode(bytes);
  }
  return utf8.decode(bytes, allowMalformed: true);
}
