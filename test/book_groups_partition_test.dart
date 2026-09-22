import 'package:flutter_test/flutter_test.dart';
import 'package:yahwehs_words/constants/book_groups.dart';
import 'package:yahwehs_words/constants/book_name_mapping.dart'
    show englishToChinese, englishToChineseTraditional;
import 'package:yahwehs_words/constants/ui_strings.dart' show uiStrings;

/// `book_groups.dart` is pure `const` data plus one lookup function, and
/// as of this test it was imported by no test file at all: nothing
/// caught a group losing or gaining a book, or drifting from the
/// canonical 39/27 split. This is that drift detector, modelled on
/// `book_name_table_parity_test.dart`.
///
/// Every invariant below was measured true against the current file
/// before being written down here.
void main() {
  group('canonical lists', () {
    test('canonicalOtBooks has 39 unique entries, canonicalNtBooks 27, '
        'and the two are disjoint', () {
      expect(canonicalOtBooks.length, 39);
      expect(canonicalNtBooks.length, 27);
      expect(canonicalOtBooks.toSet().length, canonicalOtBooks.length,
          reason: 'canonicalOtBooks has a duplicate');
      expect(canonicalNtBooks.toSet().length, canonicalNtBooks.length,
          reason: 'canonicalNtBooks has a duplicate');
      expect(
        canonicalOtBooks.toSet().intersection(canonicalNtBooks.toSet()),
        isEmpty,
        reason: 'a book title is claimed by both testaments',
      );
    });
  });

  group('OT analytical lists partition canonicalOtBooks', () {
    const otGroups = <String, List<String>>{
      'otPentateuch': otPentateuch,
      'otHistory': otHistory,
      'otWisdom': otWisdom,
      'otMajorProphets': otMajorProphets,
      'otMinorProphets': otMinorProphets,
    };

    test('group sizes are 5/12/5/5/12 and sum to 39', () {
      expect(otPentateuch.length, 5);
      expect(otHistory.length, 12);
      expect(otWisdom.length, 5);
      expect(otMajorProphets.length, 5);
      expect(otMinorProphets.length, 12);
      final total = otGroups.values.fold<int>(0, (n, g) => n + g.length);
      expect(total, 39);
    });

    test('groups are pairwise disjoint', () {
      final names = otGroups.keys.toList();
      for (var i = 0; i < names.length; i++) {
        for (var j = i + 1; j < names.length; j++) {
          final overlap = otGroups[names[i]]!
              .toSet()
              .intersection(otGroups[names[j]]!.toSet());
          expect(overlap, isEmpty,
              reason: '${names[i]} and ${names[j]} both claim $overlap');
        }
      }
    });

    test('union of the five groups equals canonicalOtBooks', () {
      final union = otGroups.values.expand((g) => g).toSet();
      expect(union, canonicalOtBooks.toSet());
    });
  });

  group('NT analytical lists partition canonicalNtBooks', () {
    const ntGroups = <String, List<String>>{
      'ntGospelsActs': ntGospelsActs,
      'ntPauline': ntPauline,
      'ntJohannine': ntJohannine,
      'ntOtherApostolic': ntOtherApostolic,
    };

    test('group sizes are 5/13/4/5 and sum to 27', () {
      expect(ntGospelsActs.length, 5);
      expect(ntPauline.length, 13);
      expect(ntJohannine.length, 4);
      expect(ntOtherApostolic.length, 5);
      final total = ntGroups.values.fold<int>(0, (n, g) => n + g.length);
      expect(total, 27);
    });

    test('groups are pairwise disjoint', () {
      final names = ntGroups.keys.toList();
      for (var i = 0; i < names.length; i++) {
        for (var j = i + 1; j < names.length; j++) {
          final overlap = ntGroups[names[i]]!
              .toSet()
              .intersection(ntGroups[names[j]]!.toSet());
          expect(overlap, isEmpty,
              reason: '${names[i]} and ${names[j]} both claim $overlap');
        }
      }
    });

    test('union of the four groups equals canonicalNtBooks', () {
      final union = ntGroups.values.expand((g) => g).toSet();
      expect(union, canonicalNtBooks.toSet());
    });

    test('ntJohannine deliberately excludes the Gospel of John', () {
      expect(ntJohannine.contains('John'), isFalse);
      // It belongs to ntGospelsActs instead, so it is not simply absent.
      expect(ntGospelsActs.contains('John'), isTrue);
    });
  });

  group('kBibleDivisions', () {
    test('has exactly 10 entries', () {
      expect(kBibleDivisions.length, 10);
    });

    test('books partition all 66 canonical titles', () {
      final allBooks = kBibleDivisions.expand((d) => d.books).toList();
      expect(allBooks.length, 66,
          reason: 'divisions overlap or omit a book (sum of sizes != 66)');
      expect(allBooks.toSet().length, 66,
          reason: 'a book appears in more than one division');
      expect(
        allBooks.toSet(),
        <String>{...canonicalOtBooks, ...canonicalNtBooks},
      );
    });

    test('each division\'s oldTestament flag matches its books\' '
        'testament', () {
      for (final d in kBibleDivisions) {
        for (final book in d.books) {
          final isOt = canonicalOtBooks.contains(book);
          final isNt = canonicalNtBooks.contains(book);
          expect(isOt || isNt, isTrue,
              reason: '${d.id} lists "$book" which is in neither '
                  'canonical list');
          expect(d.oldTestament, isOt,
              reason: '${d.id}.oldTestament=${d.oldTestament} but '
                  '"$book" is ${isOt ? "OT" : "NT"}');
        }
      }
    });

    test('book order inside each division matches canonical order', () {
      for (final d in kBibleDivisions) {
        final canonical = d.oldTestament ? canonicalOtBooks : canonicalNtBooks;
        final indices = d.books.map(canonical.indexOf).toList();
        for (var i = 1; i < indices.length; i++) {
          expect(indices[i] > indices[i - 1], isTrue,
              reason: '${d.id} lists "${d.books[i]}" before '
                  '"${d.books[i - 1]}" but canonical order says otherwise');
        }
      }
    });

    test('every division id is a real uiStrings key', () {
      for (final d in kBibleDivisions) {
        expect(uiStrings.containsKey(d.id), isTrue,
            reason: '${d.id} has no entry in uiStrings — the book '
                'picker would show a blank label');
      }
    });
  });

  group('divisionIdForEnglishBook', () {
    test('resolves all 66 canonical titles to a real division id', () {
      final validIds = kBibleDivisions.map((d) => d.id).toSet();
      for (final book in <String>[...canonicalOtBooks, ...canonicalNtBooks]) {
        final id = divisionIdForEnglishBook(book);
        expect(id, isNotNull, reason: '"$book" has no division');
        expect(validIds.contains(id), isTrue,
            reason: '"$book" resolved to unknown division id "$id"');
      }
    });
  });

  group('cross-table parity with book_name_mapping.dart', () {
    // Ground truth for which testament an English title belongs to comes
    // from the canonical lists in this file, not from book_name_mapping.
    bool isOtTitle(String english) => canonicalOtBooks.contains(english);
    bool isNtTitle(String english) => canonicalNtBooks.contains(english);

    void checkMap(String label, Map<String, String> map) {
      final missing = <String>[];
      map.forEach((english, display) {
        final testamentSet =
            isOtTitle(english) ? oldTestamentBooks : newTestamentBooks;
        if (!testamentSet.contains(display)) {
          missing.add('$english -> "$display"');
        }
      });
      expect(missing, isEmpty,
          reason: '$label: display name(s) missing from their testament '
              'set: $missing');
    }

    test('every englishToChinese value is in its own testament set', () {
      expect(englishToChinese.keys.every((k) => isOtTitle(k) || isNtTitle(k)),
          isTrue,
          reason: 'englishToChinese has a key outside the canonical 66');
      checkMap('englishToChinese', englishToChinese);
    });

    test('every englishToChineseTraditional value is in its own '
        'testament set', () {
      expect(
        englishToChineseTraditional.keys
            .every((k) => isOtTitle(k) || isNtTitle(k)),
        isTrue,
        reason:
            'englishToChineseTraditional has a key outside the canonical 66',
      );
      checkMap('englishToChineseTraditional', englishToChineseTraditional);
    });
  });
}
