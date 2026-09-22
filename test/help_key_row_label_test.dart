import 'package:flutter_test/flutter_test.dart';
import 'package:yahwehs_words/pages/help_page.dart';

/// `HelpKeyRow.label()` had zero direct test coverage (`grep -rn
/// "HelpKeyRow(" test/` was empty) despite being reader-visible on every
/// row of the Help page's key tables. It's fed `settings.locale`, which
/// is assigned with no validation on three paths (`AppSettings.setLocale`,
/// `fromMap`, and the SharedPreferences load — see
/// `lib/models/app_settings.dart:1034,1537,1877`), so an unrecognised
/// `zh-*` tag is reachable. Before the fix, `uiStrings[labelKey]?[locale]
/// ?? uiStrings[labelKey]?['en'] ?? labelKey` exact-matched past a bare
/// `'zh'` or any other `zh-XX` tag straight to the English string — the
/// same failure mode `lib/utils/font_catalog.dart`'s `FontOption.labelFor`
/// shares (fixed alongside this in the same commit) and
/// `biblical_role.dart`'s `localizedRole()` was fixed for (queue:183,
/// commit 9add37bb). `lib/widgets/bible_reading_pane.dart:9118` has the
/// same shape, still unfixed — see docs/autonomous-queue.md:21308.
///
/// Running this suite against the unfixed helper, 2 cases went red: `'zh'`
/// and `'zh-XX'` both rendered the English string instead of Simplified.
///
/// A coverage guard that every `labelKey` the key tables actually use
/// resolves in `uiStrings` for all three locales already exists —
/// `test/help_catalog_test.dart`'s "every label the key tables name
/// exists in all locales" walks `kReaderShortcuts` and `kProjectionKeymap`,
/// which is exactly the set `helpKeyGroups()` turns into `HelpKeyRow`s.
void main() {
  // A real entry from ui_strings.dart whose zh-Hans and zh-Hant values
  // differ (设置 vs 設定) — 'previousChapter' shares one string across
  // both scripts and couldn't prove zh-Hant stays on its own branch.
  const realRow = HelpKeyRow('⌘,', 'settings');

  group("an unrecognised zh-* locale degrades to Simplified, not English "
      '(the fix)', () {
    test('bare "zh"', () {
      expect(realRow.label('zh'), realRow.label('zh-Hans'));
      expect(realRow.label('zh'), isNot(realRow.label('en')));
    });

    test('arbitrary "zh-XX"', () {
      expect(realRow.label('zh-SG'), realRow.label('zh-Hans'));
      expect(realRow.label('zh-SG'), isNot(realRow.label('en')));
    });
  });

  test('zh-Hant stays on its own entry, not Simplified', () {
    expect(realRow.label('zh-Hant'), isNot(realRow.label('zh-Hans')));
  });

  test('a non-zh unknown locale falls to English, unchanged behaviour', () {
    expect(realRow.label('fr'), realRow.label('en'));
  });

  test(
      'an unknown labelKey still returns the key itself for every locale — '
      'HelpKeyRow rows built from a table typo must not blank the row',
      () {
    const missing = HelpKeyRow('X', 'thisKeyDoesNotExist');
    for (final locale in ['en', 'zh', 'zh-Hans', 'zh-Hant', 'zh-XX', 'fr']) {
      expect(missing.label(locale), 'thisKeyDoesNotExist', reason: locale);
    }
  });
}
