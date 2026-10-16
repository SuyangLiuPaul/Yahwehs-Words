/// The one door: bytes and a file name in, a [ParsedModule] or an
/// [ImportRefusal] out.
///
/// Detection is by CONTENT first. A MyBible module is routinely renamed and
/// is usually distributed zipped; a `.bbl.mybible` can be called anything. The
/// file name is only a hint for the plain-text formats, which have no magic
/// number to look at.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'addon_types.dart';
import 'parse_mybible.dart';
import 'parse_mysword.dart';
import 'parse_plain.dart';
import 'parse_support.dart';
import 'parse_theword.dart';
import 'parse_zefania.dart';
import 'sqlite_reader.dart';

/// Largest file the importer will look at.
const int kMaxModuleBytes = SqliteLimits.maxFileBytes;

/// e-Sword's module extensions. Named in the refusal: the most-recognised
/// name in this space is also the one we say no to, and the reader should
/// hear it from us rather than guess.
const _eSwordExt = [
  '.bblx', '.cmtx', '.dctx', '.topx', '.devx', '.harx', '.refx', '.mapx',
  '.notx', '.bbli', '.cmti', '.dcti', '.topi', '.devi',
];

/// What [detectModule] found, before anything is parsed.
class DetectedModule {
  const DetectedModule(this.format, this.kind);
  final AddonFormat? format;
  final AddonKind kind;
}

/// Parse [bytes] (named [fileName]) as a Bible module, or throw an
/// [ImportRefusal] saying exactly why not.
Future<ParsedModule> parseModule(
  Uint8List bytes,
  String fileName, {
  CancelToken? cancel,
  ProgressCallback? onProgress,
}) async {
  final ctx = ParseContext(cancel: cancel, onProgress: onProgress);
  if (bytes.isEmpty) throw const ImportRefusal(ImportProblem.empty);
  if (bytes.length > kMaxModuleBytes) {
    throw ImportRefusal(ImportProblem.tooLarge, detail: '${bytes.length}');
  }
  final lower = fileName.toLowerCase();

  // Binary magic first.
  if (_startsWith(bytes, const [0x50, 0x4B, 0x03, 0x04])) {
    throw const ImportRefusal(ImportProblem.zipArchive);
  }
  if (_eSwordExt.any(lower.endsWith)) {
    throw const ImportRefusal(ImportProblem.eSword);
  }
  if (_isSqlite(bytes)) {
    return _parseSqlite(bytes, ctx);
  }
  if (lower.endsWith('.twm')) {
    throw const ImportRefusal(ImportProblem.notRecognised, detail: 'twm');
  }

  // Everything else is text.
  if (lower.endsWith('.ontx') || lower.endsWith('.otx') || lower.endsWith('.ntx')) {
    throw const ImportRefusal(ImportProblem.encrypted);
  }
  final head = _head(bytes);
  final trimmed = head.trimLeft();
  if (lower.endsWith('.ont') || lower.endsWith('.ot') || lower.endsWith('.nt')) {
    return parseTheWord(bytes, fileName, ctx);
  }
  if (trimmed.startsWith('<?xml') ||
      RegExp(r'<XMLBIBLE\b', caseSensitive: false).hasMatch(head)) {
    if (RegExp(r'<XMLBIBLE\b', caseSensitive: false).hasMatch(head) ||
        lower.endsWith('.xml')) {
      if (RegExp(r'<(osis|usx|usfx|bible\b)', caseSensitive: false).hasMatch(head) &&
          !RegExp(r'<XMLBIBLE\b', caseSensitive: false).hasMatch(head)) {
        throw const ImportRefusal(ImportProblem.notRecognised, detail: 'xml');
      }
      return parseZefania(bytes, ctx);
    }
    throw const ImportRefusal(ImportProblem.notRecognised, detail: 'xml');
  }
  if (trimmed.startsWith('[') || trimmed.startsWith('{')) {
    return parseAppJson(bytes, ctx);
  }
  if (lower.endsWith('.csv') || lower.endsWith('.tsv') || lower.endsWith('.txt')) {
    // A .txt may be a theWord module someone renamed; the line count decides.
    if (lower.endsWith('.txt') && _looksLikeTheWord(bytes)) {
      return parseTheWord(bytes, fileName, ctx);
    }
    return parseCsv(bytes, ctx);
  }
  if (_looksLikeCsvHeader(trimmed)) return parseCsv(bytes, ctx);
  if (_looksLikeTheWord(bytes)) return parseTheWord(bytes, fileName, ctx);
  throw const ImportRefusal(ImportProblem.notRecognised);
}

Future<ParsedModule> _parseSqlite(Uint8List bytes, ParseContext ctx) async {
  final SqliteFile db;
  try {
    db = SqliteFile.open(bytes);
    // Force the schema read so a damaged sqlite_master fails here.
    db.tables;
  } on SqliteTooLargeException {
    throw ImportRefusal(ImportProblem.tooLarge, detail: '${bytes.length}');
  } on UnsupportedSqliteException catch (e) {
    throw ImportRefusal(ImportProblem.unsupportedLayout, detail: e.message);
  } on SqliteException catch (e) {
    throw ImportRefusal(ImportProblem.corruptFile, detail: e.message);
  }
  try {
    // e-Sword 11's Details carries OldTestament/NewTestament.
    if (looksLikeESword(db)) throw const ImportRefusal(ImportProblem.eSword);

    final my = myBibleKind(db);
    if (my == AddonKind.bible) return await parseMyBibleBible(db, ctx);
    if (my != AddonKind.other) {
      throw ImportRefusal(ImportProblem.notABible, detail: my.name);
    }
    final sw = mySwordKind(db);
    if (sw == AddonKind.bible) return await parseMySwordBible(db, ctx);
    if (sw != AddonKind.other) {
      throw ImportRefusal(ImportProblem.notABible, detail: sw.name);
    }
    throw const ImportRefusal(ImportProblem.notRecognised, detail: 'sqlite');
  } on SqliteCancelledException {
    throw const ImportRefusal(ImportProblem.cancelled);
  } on SqliteTooLargeException {
    throw ImportRefusal(ImportProblem.tooLarge, detail: '${bytes.length}');
  } on UnsupportedSqliteException catch (e) {
    throw ImportRefusal(ImportProblem.unsupportedLayout, detail: e.message);
  } on SqliteException catch (e) {
    throw ImportRefusal(ImportProblem.corruptFile, detail: e.message);
  }
}

bool _startsWith(Uint8List b, List<int> magic) {
  if (b.length < magic.length) return false;
  for (var i = 0; i < magic.length; i++) {
    if (b[i] != magic[i]) return false;
  }
  return true;
}

bool _isSqlite(Uint8List b) =>
    b.length >= 16 &&
    _startsWith(b, const [
      0x53, 0x51, 0x4C, 0x69, 0x74, 0x65, 0x20, 0x66, 0x6F, 0x72, 0x6D, 0x61,
      0x74, 0x20, 0x33, 0x00,
    ]);

String _head(Uint8List b) {
  final n = b.length < 4096 ? b.length : 4096;
  var s = utf8.decode(Uint8List.sublistView(b, 0, n), allowMalformed: true);
  if (s.startsWith('﻿')) s = s.substring(1);
  return s;
}

bool _looksLikeCsvHeader(String head) {
  final first = head.split('\n').first.toLowerCase();
  return first.contains('book') && first.contains('chapter') && first.contains('verse');
}

bool _looksLikeTheWord(Uint8List b) {
  // Count lines cheaply.
  var lines = 0;
  for (final c in b) {
    if (c == 0x0A) lines++;
  }
  return plausibleTheWordLineCount(lines + 1);
}
