import 'package:flutter_test/flutter_test.dart';
import 'package:yahwehs_words/constants/ui_strings.dart';

/// 2026-10-16: the app does not credit a person by name anywhere the
/// reader can see it ("Made by …" was on the contact line). Who to write
/// to is the support address; who wrote the app is not on screen.
void main() {
  test('no interface string names its author', () {
    final hits = <String>[];
    uiStrings.forEach((key, byLocale) {
      byLocale.forEach((locale, text) {
        if (RegExp(r'Paul Liu|Suyang|作者\s*Paul', caseSensitive: false)
            .hasMatch(text)) {
          hits.add('$key [$locale]');
        }
      });
    });
    expect(hits, isEmpty);
    expect(uiStrings.containsKey('contactIntro'), isFalse);
  });
}
