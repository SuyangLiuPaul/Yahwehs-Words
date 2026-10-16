// MyBible.zone's book numbers, pinned against its published "Books reference".
import 'package:flutter_test/flutter_test.dart';
import 'package:yahwehs_words/utils/addons/addon_canon.dart';
import 'package:yahwehs_words/utils/addons/mybible_book_numbers.dart';

void main() {
  test('spot checks straight from the specification', () {
    expect(kMyBibleCanonIndex[10], 1); // Genesis
    expect(kMyBibleCanonIndex[190], 17); // Esther (180 is Judith, not a gap)
    expect(kMyBibleCanonIndex[230], 19); // Psalms
    expect(kMyBibleCanonIndex[470], 40); // Matthew
    expect(kMyBibleCanonIndex[500], 43); // John
    expect(kMyBibleCanonIndex[510], 44); // Acts
    expect(kMyBibleCanonIndex[520], 45); // Romans
    expect(kMyBibleCanonIndex[650], 58); // Hebrews
    expect(kMyBibleCanonIndex[660], 59); // James comes AFTER Hebrews
    expect(kMyBibleCanonIndex[730], 66); // Revelation
  });

  test('exactly the 66 canonical books, each once, in canon order', () {
    expect(kMyBibleCanonIndex.length, 66);
    expect(kMyBibleCanonIndex.values.toSet(), {for (var i = 1; i <= 66; i++) i});
    final byNumber = kMyBibleCanonIndex.keys.toList()..sort();
    // The numbers rise through the whole canon in the app's own order.
    expect([for (final n in byNumber) kMyBibleCanonIndex[n]!],
        [for (var i = 1; i <= 66; i++) i]);
  });

  test('the books we do not carry never collide with the ones we do', () {
    expect(kMyBibleOtherBooks.keys.toSet().intersection(kMyBibleCanonIndex.keys.toSet()),
        isEmpty);
    expect(kMyBibleOtherBooks.length, 19);
    expect(kMyBibleOtherBooks[170], 'Tobit');
    expect(kMyBibleOtherBooks[462], '1 Maccabees');
  });

  test('every canonical number is a multiple of 10', () {
    for (final n in kMyBibleCanonIndex.keys) {
      expect(n % 10, 0, reason: '$n');
    }
    expect(kCanonBooks[kMyBibleCanonIndex[10]! - 1], 'Genesis');
  });
}
