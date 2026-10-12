import 'package:flutter_test/flutter_test.dart';
import 'package:yahwehs_words/utils/version_mapper.dart';

void main() {
  test('Genesis presentation uses the formal localized spelling', () {
    expect(bookNameForDisplay('创世纪', 'zh-Hans', 'cuvs-yhwh'), '创世记');
    expect(bookNameForDisplay('創世紀', 'zh-Hant', 'cuvs-yhwh-tr'), '創世記');
    expect(bookNameForDisplay('Genesis', 'en', 'cuvs-yhwh'), 'Genesis');
    // Keep the frozen corpus key unchanged for data lookup.
    expect(translateBookName('Genesis', 'cuvs-yhwh'), '创世纪');
  });
  test('context-free references retain source edition script', () {
    expect(bookNameForDisplay('创世纪'), '创世记');
    expect(bookNameForDisplay('創世紀'), '創世記');
    expect(bookNameForDisplay('Genesis'), 'Genesis');
    expect(bookNameForDisplay('出埃及记'), '出埃及记');
    expect(bookNameForDisplay('創世記'), '創世記');
    // A matching spelling is presentation only; the old saved/key identity
    // must still resolve to the same canonical book.
    expect(sameBookName('创世记', '创世纪'), isTrue);
    expect(sameBookName('創世記', '創世紀'), isTrue);
  });

  test('reading edition controls script when the UI locale differs', () {
    expect(bookNameForDisplay('创世纪', 'en', 'cuvs-yhwh'), '创世记');
    expect(bookNameForDisplay('創世紀', 'en', 'cuvs-yhwh-tr'), '創世記');
    expect(bookNameForDisplay('创世纪', 'zh-Hant', 'kjv'), 'Genesis');
    expect(bookNameForDisplay('创世纪', 'zh-Hant'), '創世記');
  });

}
