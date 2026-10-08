import 'package:flutter_test/flutter_test.dart';
import 'package:yahwehs_words/utils/search_testament_scope.dart';
import 'package:yahwehs_words/constants/book_groups.dart';

void main() {
  test('testaments partition all 66 canonical books', () {
    for (final book in [...canonicalOtBooks, ...canonicalNtBooks]) {
      expect(matchesSearchBookScope(book, hebrewBibleScope),
          canonicalOtBooks.contains(book));
      expect(matchesSearchBookScope(book, greekBibleScope),
          canonicalNtBooks.contains(book));
    }
  });
  test('localized books and ordinary book scopes remain supported', () {
    expect(matchesSearchBookScope('创世记', hebrewBibleScope), isTrue);
    expect(matchesSearchBookScope('約翰福音', greekBibleScope), isTrue);
    expect(matchesSearchBookScope('希伯来书', hebrewBibleScope), isFalse);
    expect(matchesSearchBookScope('Genesis', '创世记'), isTrue);
    expect(matchesSearchBookScope('John', 'Genesis'), isFalse);
    expect(matchesSearchBookScope('John', null), isTrue);
  });
}
