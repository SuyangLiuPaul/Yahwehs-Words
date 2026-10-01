import 'dart:convert';
import '../models/verse.dart';
import '../constants/bible_versions.dart';
import '../utils/version_mapper.dart';

/// Only public verse text is shared: no notes, searches, highlights or credentials.
/// A bounded chapter fits WatchConnectivity's application context; never silently
/// cut a verse or renumber a split verse. Oversize chapters explicitly say so.
Map<String, dynamic> watchReadingSnapshot(
    {required String book,
    required int chapter,
    required String version,
    required String locale,
    required List<Verse> verses}) {
  final rows = <Map<String, String>>[];
  var bytes = 0;
  for (final verse in verses) {
    final text = verse.text
        .replaceAll(RegExp(r'<note:[^>]*>'), '')
        .replaceAll(RegExp(r'<[^>]+>'), '');
    final row = {
      'number': verse.verseLabel,
      'text': text,
      'heading': verse.superscription
    };
    final size = utf8.encode(jsonEncode(row)).length;
    if (bytes + size > 44000) break;
    rows.add(row);
    bytes += size;
  }
  return {
    'key': '$version|$book|$chapter',
    'reference': localizedReferenceLabel('$book $chapter', locale),
    'version': version,
    'versionLabel': fullBibleVersionLabel(version),
    'verses': rows,
    'total': verses.length,
    'truncated': rows.length < verses.length
  };
}
