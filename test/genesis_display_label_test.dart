import 'package:flutter_test/flutter_test.dart';
import 'package:yahwehs_words/utils/version_mapper.dart';

void main() {
  test('Genesis presentation uses the formal localized spelling', () {
    expect(bookNameForDisplay('创世纪', 'zh-Hans', 'cuvs-yhwh'), '创世记');
    expect(bookNameForDisplay('創世紀', 'zh-Hant', 'cuvs-yhwh-tr'), '創世記');
    expect(bookNameForDisplay('Exodus', 'zh-Hans', 'cuvs-yhwh'), 'Exodus');
    // Keep the frozen bundle/search key unchanged for data lookup.
    expect(translateBookName('Genesis', 'cuvs-yhwh'), '创世纪');
  });
}
