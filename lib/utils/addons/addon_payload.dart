/// A parsed module → the app's own verse JSON.
///
/// The principle is Sword's original importer's and it is the right one: store
/// the APP'S verse shape, and read it back through the very parser every
/// bundled edition goes through (`FetchVerses.decodeVerses`). An imported
/// text then cannot take a code path of its own and drift from how every
/// other edition loads.
///
/// Book names are written in the script the reader will see them in — English,
/// 简体 or 繁體 — because `Verse.book` is what the references beside the text
/// are built from, exactly as for the bundled Chinese editions.
library;

import 'dart:convert';

import 'addon_canon.dart';
import 'addon_types.dart';

/// Prefix on every imported edition's code. A namespace, and a load-bearing
/// one: it is what stops an import called `kjv` shadowing the bundled KJV, and
/// lets every surface tell a supplied text from a shipped one by the code
/// alone.
const String kAddonVersionPrefix = 'user-';

/// Largest normalised payload kept, in bytes. The biggest edition the app
/// ships is ~9 MB; this admits any real Bible and refuses a file that cannot
/// be one (and protects the 15-edition in-memory cache).
const int kMaxPayloadBytes = 24 * 1024 * 1024;

/// The code for an import called [label]: lower-cased, anything not a letter
/// or digit collapsed to `-`, prefixed. Chinese and other non-ASCII labels
/// fall back to a short stable hash so two different names never collide.
String addonCodeForLabel(String label) {
  final trimmed = label.trim();
  var slug = trimmed
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  if (slug.isEmpty) {
    // 100% non-ASCII (e.g. a Chinese name): a stable hash of the name.
    var h = 0x811c9dc5;
    for (final r in trimmed.runes) {
      h = ((h ^ r) * 0x01000193) & 0xFFFFFFFF;
    }
    slug = 'text-${h.toRadixString(36)}';
  }
  if (slug.length > 40) slug = slug.substring(0, 40).replaceAll(RegExp(r'-+$'), '');
  return '$kAddonVersionPrefix$slug';
}

/// The language family of a module: `en`, `zh-Hans`, `zh-Hant`, or `other`.
///
/// From what the file DECLARES where it declares something we recognise, else
/// from what its text IS. Used only to choose a picker tab and the script of
/// the book names — never to rewrite any text.
String languageFamilyFor(ParsedModule m) {
  final declared = m.meta.language.trim().toLowerCase().replaceAll('_', '-');
  switch (declared) {
    case 'en':
    case 'eng':
    case 'english':
    case 'en-us':
    case 'en-gb':
      return 'en';
    case 'zh-hant':
    case 'zh-tw':
    case 'zh-hk':
    case 'cht':
    case 'zht':
    case 'zh-mo':
      return 'zh-Hant';
    case 'zh':
    case 'zho':
    case 'chi':
    case 'cmn':
    case 'chs':
    case 'zhs':
    case 'zh-hans':
    case 'zh-cn':
    case 'zh-sg':
      return 'zh-Hans';
  }
  // By content: sample the text.
  var cjk = 0, latin = 0, total = 0;
  var trad = 0, simp = 0;
  const tradOnly = '說這個們來時會學國對從開關無點場長軍門間問聽讀譯詩經書';
  const simpOnly = '说这个们来时会学国对从开关无点场长军门间问听读译诗经书';
  var sampled = 0;
  for (final v in m.verses) {
    if (sampled++ >= 200) break;
    for (final r in v.text.runes) {
      if (r >= 0x4E00 && r <= 0x9FFF) {
        cjk++;
        final ch = String.fromCharCode(r);
        if (tradOnly.contains(ch)) trad++;
        if (simpOnly.contains(ch)) simp++;
      } else if ((r >= 0x41 && r <= 0x5A) || (r >= 0x61 && r <= 0x7A)) {
        latin++;
      }
      total++;
    }
  }
  if (total == 0) return 'other';
  if (cjk > total * 0.3) return trad > simp ? 'zh-Hant' : 'zh-Hans';
  if (latin > total * 0.6) {
    // Latin letters: English if the file says nothing contrary.
    return declared.isEmpty ? 'en' : 'other';
  }
  return 'other';
}

/// The script the book names are written in for [family].
String scriptForFamily(String family) =>
    (family == 'zh-Hans' || family == 'zh-Hant') ? family : 'en';

String bookNameFor(int canonIndex, String script) {
  switch (script) {
    case 'zh-Hans':
      return kCanonBooksHans[canonIndex - 1];
    case 'zh-Hant':
      return kCanonBooksHant[canonIndex - 1];
    default:
      return kCanonBooks[canonIndex - 1];
  }
}

/// The encoded edition and what it holds.
class AddonPayload {
  AddonPayload(this.json, this.verseCount, this.books, this.bytes);
  final String json;
  final int verseCount;
  final Set<int> books;
  final int bytes;
}

/// Encode [m]'s verses as the app's verse JSON, books named in [script].
///
/// Built by hand rather than `jsonEncode` over 31,000 maps: a Whole-Bible
/// import would build that many throwaway maps, doubling its peak memory on a
/// device that may not have it.
AddonPayload encodeAddonPayload(ParsedModule m, String script) {
  final buf = StringBuffer('[');
  var first = true;
  for (final v in m.verses) {
    if (!first) buf.write(',');
    first = false;
    buf
      ..write('{"book":')
      ..write(json.encode(bookNameFor(v.book, script)))
      ..write(',"chapter":"')
      ..write(v.chapter)
      ..write('","verse":"')
      ..write(v.verse)
      ..write('","text":')
      ..write(json.encode(v.text));
    if (v.paragraphStart) buf.write(',"isParagraphStart":true');
    if (v.superscription.isNotEmpty) {
      buf
        ..write(',"superscription":')
        ..write(json.encode(v.superscription));
    }
    buf.write('}');
  }
  buf.write(']');
  final s = buf.toString();
  final bytes = utf8.encode(s).length;
  if (bytes > kMaxPayloadBytes) {
    throw ImportRefusal(ImportProblem.tooLarge, detail: '$bytes');
  }
  return AddonPayload(s, m.verses.length, m.books, bytes);
}
