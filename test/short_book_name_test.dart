import 'package:flutter_test/flutter_test.dart';
import 'package:yahwehs_words/constants/book_name_mapping.dart' show toLocale;
import 'package:yahwehs_words/constants/canon_chapters.dart'
    show canonLastChapter;
import 'package:yahwehs_words/utils/short_book_name.dart';

/// `shortBookName()` renders the compact book label on two real reader
/// surfaces (`dashboard_page.dart`, `bible_reading_pane.dart`'s floating
/// header) and had zero test coverage before this file. It reverse-maps
/// a *localized* book name back to English via `toEnglish`, then looks
/// up one of three abbreviation maps — a defect here silently mislabels
/// scripture on the narrow-width fallback surface.
///
/// Every invariant below was measured true against the current file
/// before being written down here; `shortBooksEn`/`Hans`/`Hant` were
/// made `@visibleForTesting` (visibility only, no behaviour change) so
/// this file can assert against the real maps instead of hand-typing a
/// second copy that could drift from them.
void main() {
  final books = canonLastChapter.keys.toList();

  test('canonLastChapter has the 66 canonical books', () {
    expect(books.length, 66);
    expect(books.toSet().length, 66, reason: 'canonLastChapter has a duplicate key');
  });

  group('each abbreviation map covers exactly the 66-book canon', () {
    test('shortBooksEn', () {
      expect(shortBooksEn.length, 66);
      expect(shortBooksEn.keys.toSet(), books.toSet());
    });
    test('shortBooksHans', () {
      expect(shortBooksHans.length, 66);
      expect(shortBooksHans.keys.toSet(), books.toSet());
    });
    test('shortBooksHant', () {
      expect(shortBooksHant.length, 66);
      expect(shortBooksHant.keys.toSet(), books.toSet());
    });
  });

  group('abbreviations are unique within each locale', () {
    test('en', () {
      expect(shortBooksEn.values.toSet().length, shortBooksEn.length);
    });
    test('zh-Hans', () {
      expect(shortBooksHans.values.toSet().length, shortBooksHans.length);
    });
    test('zh-Hant', () {
      expect(shortBooksHant.values.toSet().length, shortBooksHant.length);
    });
  });

  group('round trip through the localized name every caller actually '
      'passes resolves to the map, not the fallback branch', () {
    // Because the maps above are already proven to cover all 66 books,
    // a match against shortBooksXxx[book] here can only happen via the
    // map lookup — the fallback branch is structurally unreachable for
    // any of these inputs, so this is a strict equality, not a
    // "different from the fallback pattern" heuristic (which breaks for
    // books like Job, whose abbreviation coincidentally equals its own
    // 3-letter substring fallback).
    test('en: shortBookName(book, "en")', () {
      for (final book in books) {
        expect(shortBookName(book, 'en'), shortBooksEn[book], reason: book);
      }
    });

    test('zh-Hans: shortBookName(toLocale(book, "cuvs-yhwh"), "zh-Hans")', () {
      for (final book in books) {
        final localized = toLocale(book, 'cuvs-yhwh');
        expect(shortBookName(localized, 'zh-Hans'), shortBooksHans[book],
            reason: '$book -> $localized');
      }
    });

    test('zh-Hant: shortBookName(toLocale(book, "cuvs-tr"), "zh-Hant")', () {
      for (final book in books) {
        final localized = toLocale(book, 'cuvs-tr');
        expect(shortBookName(localized, 'zh-Hant'), shortBooksHant[book],
            reason: '$book -> $localized');
      }
    });
  });

  test('an already-English name still resolves under a zh locale, since '
      'toEnglish returns English input unchanged', () {
    expect(shortBookName('Genesis', 'zh-Hans'), '创');
    expect(shortBookName('Genesis', 'zh-Hant'), '創');
  });

  test('empty input returns empty', () {
    expect(shortBookName('', 'en'), '');
    expect(shortBookName('', 'zh-Hans'), '');
    expect(shortBookName('', 'zh-Hant'), '');
  });

  test('an unknown book name degrades via the fallback branch without '
      'throwing — current behaviour, see queue item (shortBookName '
      'takes the UI locale, not the reading version; a Traditional '
      'reader with a Simplified UI can see a mismatched abbreviation)', () {
    // "Barnabas" / "巴拿巴" have no entry in any of the three maps
    // (checked: absent from englishToChinese, englishToChineseTraditional
    // and the _zhAliasToEn alias table), so these exercise the fallback
    // branches on purpose rather than by accident.
    expect(shortBookName('Barnabas', 'en'), 'Bar'); // substring(0, 3)
    expect(shortBookName('巴拿巴', 'zh-Hans'), '巴'); // last character
    expect(shortBookName('巴拿巴', 'zh-Hant'), '巴');
    expect(() => shortBookName('X', 'zh-Hant'), returnsNormally);
  });
}
