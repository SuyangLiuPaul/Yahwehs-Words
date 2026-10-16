/// Map a book name a module wrote to one of the 66 canonical books.
///
/// Exact names only — English, 简体, 繁體 — plus a handful of unambiguous
/// alternatives. NO abbreviations: "Jud" is Judges or Jude, "Jn" is a gospel
/// or three letters, and a guess here puts scripture under the wrong heading.
/// A name this cannot place is dropped and named in the import report, which
/// is the honest outcome.
library;

import 'addon_canon.dart';

/// Alternative spellings that name exactly one canonical book.
const Map<String, int> _aliases = {
  'psalm': 19,
  'psalter': 19,
  'song of songs': 22,
  'song of solomon': 22,
  'songs': 22,
  'canticles': 22,
  'canticle of canticles': 22,
  'revelation of john': 66,
  'revelation of st. john': 66,
  'revelations': 66,
  'apocalypse': 66,
  'the revelation': 66,
  'acts of the apostles': 44,
  'lamentation': 25,
  'ecclesiastes': 21,
  'qoheleth': 21,
  'jeremias': 24,
  'obadias': 31,
  'canticle': 22,
};

Map<String, int>? _cache;

String _norm(String s) => s
    .replaceAll(RegExp(r'[ \s]+'), ' ')
    .replaceAll('.', '')
    .trim()
    .toLowerCase();

Map<String, int> _table() {
  final cached = _cache;
  if (cached != null) return cached;
  final m = <String, int>{};
  for (var i = 0; i < kCanonBooks.length; i++) {
    m[_norm(kCanonBooks[i])] = i + 1;
    m[_norm(kCanonBooksHans[i])] = i + 1;
    m[_norm(kCanonBooksHant[i])] = i + 1;
  }
  m.addAll(_aliases);
  return _cache = m;
}

/// 1-based canon index of [name], or null when it is not a name this knows.
int? resolveBookName(String name) {
  final n = _norm(name);
  if (n.isEmpty) return null;
  return _table()[n];
}
