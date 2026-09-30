/// Romanised Chinese is an explicit search option, separate from fuzzy
/// synonyms and English inflection. Callers pass the same sanitised text
/// their literal index uses, so divine-name spellings stay consistent.
library;

import 'package:pinyin/pinyin.dart' show PinyinHelper;

bool? _enabled;
bool get pinyinSearchConfigured => _enabled != null;
bool get pinyinSearchEnabled => _enabled ?? false;
void setPinyinSearchEnabled(bool enabled) => _enabled = enabled;

final _hanRuns = RegExp(r'[\u3400-\u9fff\uf900-\ufaff]+');
final _latin = RegExp(r'[a-zA-Z\u00c0-\u024f]');
final _combining = RegExp(r'[\u0300-\u036f]');
final _tones = RegExp(r'([a-z])[1-5]');
final _separators = RegExp(r"[\s'’\-]+");
final _letters = RegExp(r'^[a-z]+$');
const _toneChars = 'āáǎàēéěèīíǐìōóǒòūúǔùüǖǘǚǜ';
const _toneBases = 'aaaaeeeeiiiioooouuuuvvvvv';

String _foldTones(String text) {
  var out = text.toLowerCase().replaceAll('u\u0308', 'v');
  for (var i = 0; i < _toneChars.length; i++) {
    out = out.replaceAll(_toneChars[i], _toneBases[i]);
  }
  return out.replaceAll(_combining, '');
}

String? _query;
String? _queryKey;
String? _reading(String query) {
  if (_query == query) return _queryKey;
  _query = query;
  // A Chinese-only query keeps its literal meaning, even with this on.
  if (!_latin.hasMatch(query)) return _queryKey = null;
  final converted = query.replaceAllMapped(_hanRuns,
      (m) => PinyinHelper.getPinyinE(m[0]!, separator: '', defPinyin: ''));
  final key = _foldTones(converted)
      .replaceAllMapped(_tones, (m) => m[1]!)
      .replaceAll(_separators, '');
  return _queryKey = key.length >= 2 && _letters.hasMatch(key) ? key : null;
}

class _PinyinCorpus {
  const _PinyinCorpus(this.full, this.initials, this.boundaries);
  final String full;
  final String initials;
  final List<int> boundaries;
}

// Bound memory across edition switches. Unknown characters and non-Han
// runs separate syllables instead of manufacturing a match through them.
const kPinyinMemoLimit = 40000;
final Map<String, _PinyinCorpus> _corpus = {};
_PinyinCorpus _keyOf(String text) {
  final cached = _corpus[text];
  if (cached != null) return cached;
  final full = StringBuffer();
  final initials = StringBuffer();
  final boundaries = <int>[];
  for (final run in _hanRuns.allMatches(text)) {
    full.write('|');
    initials.write('|');
    boundaries.add(full.length);
    final syllables =
        PinyinHelper.getPinyinE(run[0]!, separator: ' ', defPinyin: '|')
            .split(' ');
    for (final syllable in syllables) {
      final folded = _foldTones(syllable);
      if (folded.isEmpty) continue;
      full.write(folded);
      initials.write(_letters.hasMatch(folded) ? folded[0] : '|');
      boundaries.add(full.length);
    }
  }
  final key = _PinyinCorpus(full.toString(), initials.toString(), boundaries);
  if (_corpus.length < kPinyinMemoLimit) _corpus[text] = key;
  return key;
}

/// Full pinyin matches only at syllable boundaries: `shen` must not
/// match the first four letters of `sheng`. Initials are intentionally
/// broader; both sorts are labelled as pinyin by the result UI.
bool pinyinMatches(String scriptureText, String query) {
  final reading = _reading(query);
  if (reading == null || !_hanRuns.hasMatch(scriptureText)) return false;
  final key = _keyOf(scriptureText);
  var start = key.full.indexOf(reading);
  while (start >= 0) {
    if (key.boundaries.contains(start) &&
        key.boundaries.contains(start + reading.length)) {
      return true;
    }
    start = key.full.indexOf(reading, start + 1);
  }
  return key.initials.contains(reading);
}

/// Clear only ephemeral matching state; normal preference changes never
/// throw away the converted corpus. Tests can restore the unconfigured
/// compatibility state without leaking an earlier preference.
void resetPinyinSearchForTest() {
  _enabled = null;
  _query = null;
  _queryKey = null;
  _corpus.clear();
}
