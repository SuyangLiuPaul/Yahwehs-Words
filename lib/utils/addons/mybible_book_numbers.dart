/// MyBible.zone's `book_number` scheme.
///
/// A fixed legacy numbering inherited from PalmBible+, published as the
/// "Books reference" table of the MyBible module specification
/// (https://mybible.zone/?p=1626 → "MyBible modules format"). The 66 books of
/// the canon sit at 10…730 with gaps, and the books other traditions add sit
/// in the gaps. This file is that table, transcribed once and pinned by
/// `test/addons/mybible_book_numbers_test.dart`.
///
/// Three outcomes for any number, and no fourth:
///   1. in [kMyBibleCanonIndex] → one of our 66 books;
///   2. in [kMyBibleOtherBooks] → a real book the app does not carry
///      (dropped, and NAMED in the import report);
///   3. neither → dropped, counted, the raw number quoted. Never guessed: a
///      wrong book number puts a verse under the wrong heading for good and
///      nothing downstream would notice.
library;

/// MyBible `book_number` → 1-based canon index (`kCanonBooks[i - 1]`).
const Map<int, int> kMyBibleCanonIndex = {
  10: 1, // Genesis
  20: 2,
  30: 3,
  40: 4,
  50: 5,
  60: 6,
  70: 7,
  80: 8,
  90: 9, // 1 Samuel
  100: 10,
  110: 11,
  120: 12,
  130: 13, // 1 Chronicles
  140: 14,
  150: 15, // Ezra
  160: 16, // Nehemiah
  190: 17, // Esther
  220: 18, // Job
  230: 19, // Psalms
  240: 20, // Proverbs
  250: 21, // Ecclesiastes
  260: 22, // Song of Solomon
  290: 23, // Isaiah
  300: 24, // Jeremiah
  310: 25, // Lamentations
  330: 26, // Ezekiel
  340: 27, // Daniel
  350: 28, // Hosea
  360: 29,
  370: 30,
  380: 31,
  390: 32,
  400: 33,
  410: 34,
  420: 35,
  430: 36,
  440: 37,
  450: 38,
  460: 39, // Malachi
  470: 40, // Matthew
  480: 41,
  490: 42,
  500: 43, // John
  510: 44, // Acts
  520: 45, // Romans
  530: 46,
  540: 47,
  550: 48,
  560: 49,
  570: 50,
  580: 51,
  590: 52,
  600: 53,
  610: 54,
  620: 55,
  630: 56,
  640: 57, // Philemon
  650: 58, // Hebrews
  660: 59, // James
  670: 60,
  680: 61,
  690: 62,
  700: 63,
  710: 64,
  720: 65, // Jude
  730: 66, // Revelation
};

/// Books MyBible numbers that this app does not carry.
const Map<int, String> kMyBibleOtherBooks = {
  145: 'Prayer of Manasseh',
  165: 'Esdras (Russian canon)',
  170: 'Tobit',
  180: 'Judith',
  192: 'Additions to Esther',
  270: 'Wisdom of Solomon',
  280: 'Sirach',
  305: 'Prayer of Azariah',
  315: 'Letter of Jeremiah',
  320: 'Baruch',
  323: 'Song of the Three Young Men',
  325: 'Susanna',
  345: 'Bel and the Dragon',
  462: '1 Maccabees',
  464: '2 Maccabees',
  466: '3 Maccabees',
  467: '4 Maccabees',
  468: '2 Esdras',
  780: 'To the Laodiceans',
};
