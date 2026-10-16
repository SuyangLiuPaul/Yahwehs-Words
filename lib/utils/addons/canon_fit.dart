/// Fit a module's verses to this app's canon, and account for every verse that
/// does not fit.
///
/// Nothing is silently lost and nothing is invented. What the rules do:
///
/// | case | action |
/// |---|---|
/// | book not in the 66 | dropped by the PARSER, named in the report |
/// | chapter < 1, or past the book's last chapter | dropped, counted |
/// | verse 0 (a psalm title in MyBible / MySword) | folded onto verse 1 as its superscription |
/// | verse past the usual last verse of its chapter | KEPT — the reader derives its verses from the list, so an extra verse simply shows |
/// | the same (book, chapter, verse) twice | first wins, the rest counted |
/// | empty text | skipped, counted |
///
/// Versification is RECORDED (`ModuleMeta.versification`), never "corrected":
/// remapping a Septuagint-numbered Psalter onto the Hebrew numbering would be
/// inventing an alignment the file does not carry, and this repo has a long
/// memory of what that costs (`assets/versification.json` exists because
/// joining differently-numbered editions "handed 1,823 references another
/// verse's Hebrew").
library;

import 'addon_canon.dart';
import 'addon_types.dart';

class CanonFitter {
  CanonFitter(this.report);

  final ImportReport report;

  // (book, chapter, verse) → verse. Insertion order is irrelevant: sorted
  // at the end.
  final Map<int, ParsedVerse> _verses = {};
  final Map<int, String> _titles = {}; // (book, chapter) → superscription text

  // Verses that open a paragraph because the PREVIOUS verse closed one.
  final Set<int> _opensParagraph = {};

  static int _key(int book, int chapter, int verse) =>
      (book * 1000 + chapter) * 1000 + verse;

  /// Add one verse. [book] is already a 1-based canon index.
  ///
  /// [endsParagraph]: the text closed a paragraph, so the NEXT verse of the
  /// chapter opens one. (MyBible `<pb/>` and GBF `<CM>` mark the END of a
  /// paragraph; marking the start instead would put every break one verse
  /// early.)
  void add(int book, int chapter, int verse, String text,
      {bool paragraphStart = false, bool endsParagraph = false}) {
    if (book < 1 || book > 66) return; // parsers never pass this
    final lastChapter = kCanonVerseCounts[book - 1].length;
    if (chapter < 1 || chapter > lastChapter || verse < 0 || verse > 999) {
      report.versesDroppedOutsideCanon++;
      return;
    }
    if (text.isEmpty) {
      report.versesEmpty++;
      return;
    }
    if (verse == 0) {
      final k = book * 1000 + chapter;
      if (_titles.containsKey(k)) {
        report.versesDuplicate++;
      } else {
        _titles[k] = text;
      }
      return;
    }
    final key = _key(book, chapter, verse);
    if (_verses.containsKey(key)) {
      report.versesDuplicate++;
      return;
    }
    if (endsParagraph) _opensParagraph.add(_key(book, chapter, verse + 1));
    _verses[key] = ParsedVerse(
      book: book,
      chapter: chapter,
      verse: verse,
      text: text,
      paragraphStart: paragraphStart,
    );
  }

  /// The fitted verses in canon order, titles folded in.
  List<ParsedVerse> finish() {
    // Titles ride on verse 1 of their chapter.
    _titles.forEach((k, title) {
      final book = k ~/ 1000;
      final chapter = k % 1000;
      final v1 = _verses[_key(book, chapter, 1)];
      if (v1 == null) {
        report.versesDroppedOutsideCanon++;
        return;
      }
      _verses[_key(book, chapter, 1)] = v1.copyWith(superscription: title);
      report.superscriptionsFolded++;
    });
    final keys = _verses.keys.toList()..sort();
    final out = [
      for (final k in keys)
        _opensParagraph.contains(k) && !_verses[k]!.paragraphStart
            ? _verses[k]!.copyWith(paragraphStart: true)
            : _verses[k]!,
    ];
    report.versesAccepted = out.length;
    return out;
  }
}
