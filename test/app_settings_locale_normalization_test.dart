import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yahwehs_words/models/app_settings.dart';

/// `AppSettings._locale` had three ingress points that stored whatever
/// tag arrived unvalidated — `setLocale()`, the SharedPreferences load,
/// and `_applyUserPrefsBlob` (cross-device sync). A bare `'zh'` or an
/// unrecognised `'zh-XX'` tag was reachable through any of them, and
/// every `uiStrings[k]?[locale]` lookup app-wide (~1,200 sites,
/// including `lib/widgets/bible_reading_pane.dart:9118`,
/// `lib/utils/font_catalog.dart`, `lib/pages/help_page.dart`) keys that
/// map by exact match, so the unrecognised tag fell through to English
/// instead of Simplified — the same failure mode already fixed for
/// `localizedRole()` (commit 9add37bb), `FontOption.labelFor` and
/// `HelpKeyRow.label` (commit 924890df). See docs/autonomous-queue.md,
/// queue item at (roughly) line 21310.
///
/// Fixed at the source this time: `AppSettings.normalizeLocale()` is
/// now applied at all three ingress points, so every downstream lookup
/// is covered without touching each call site individually.
///
/// Run against the unfixed code (`_locale = langCode` / `= persistedLocale
/// ?? …` / `_locale = m['locale'] as String`, no normalisation): 4 cases
/// went red — `setLocale('zh')`, the SharedPreferences-load `'zh'` case,
/// the `_applyUserPrefsBlob` `'zh'` case, and `normalizeLocale('zh-XX')`
/// itself. All four green after the fix.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppSettings.normalizeLocale (the normaliser)', () {
    test('bare "zh" becomes Simplified', () {
      expect(AppSettings.normalizeLocale('zh'), 'zh-Hans');
    });

    test('an arbitrary "zh-XX" becomes Simplified', () {
      expect(AppSettings.normalizeLocale('zh-SG'), 'zh-Hans');
    });

    test('"zh-Hant" is unchanged', () {
      expect(AppSettings.normalizeLocale('zh-Hant'), 'zh-Hant');
    });

    test('"zh-Hans" is unchanged', () {
      expect(AppSettings.normalizeLocale('zh-Hans'), 'zh-Hans');
    });

    test('"en" is unchanged', () {
      expect(AppSettings.normalizeLocale('en'), 'en');
    });

    test('a non-zh unknown tag is returned unchanged, not rewritten', () {
      expect(AppSettings.normalizeLocale('fr'), 'fr');
      expect(AppSettings.normalizeLocale(''), '');
    });
  });

  group('setLocale() persists the normalised value', () {
    test('a bare "zh" is stored and read back as zh-Hans', () async {
      SharedPreferences.setMockInitialValues({});
      final s = AppSettings();
      // AppSettings' in-memory default is already 'zh-Hans' — start
      // from 'en' so setLocale('zh') is a real transition, not a
      // same-value early return that would never touch the persist path.
      await s.setLocale('en');
      await s.setLocale('zh');
      expect(s.locale, 'zh-Hans');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('locale'), 'zh-Hans',
          reason: 'the persisted tag must be normalised too, or a '
              'restart reloads the raw one');
    });

    test('calling setLocale("zh") twice does not wedge on the raw value',
        () async {
      // Regression for normalising AFTER the early-return check instead
      // of before it — a caller passing the same raw tag twice must
      // still settle on the normalised one, not bail out comparing
      // normalised-against-raw forever.
      SharedPreferences.setMockInitialValues({});
      final s = AppSettings();
      await s.setLocale('en');
      await s.setLocale('zh');
      await s.setLocale('zh');
      expect(s.locale, 'zh-Hans');
    });

    test('zh-Hant / zh-Hans / en round-trip unchanged', () async {
      SharedPreferences.setMockInitialValues({});
      final s = AppSettings();
      await s.setLocale('zh-Hant');
      expect(s.locale, 'zh-Hant');
      await s.setLocale('en');
      expect(s.locale, 'en');
      await s.setLocale('zh-Hans');
      expect(s.locale, 'zh-Hans');
    });
  });

  group('the SharedPreferences load path normalises a legacy stored tag',
      () {
    test('a legacy raw "zh" on disk loads as zh-Hans and is re-persisted',
        () async {
      SharedPreferences.setMockInitialValues({'locale': 'zh'});
      final s = AppSettings();
      await s.loadSettings();
      expect(s.locale, 'zh-Hans');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('locale'), 'zh-Hans',
          reason: 'MainProvider.restoreState reads the raw "locale" key '
              'directly, not through AppSettings, so the legacy tag must '
              'be corrected on disk or a fresh boot keeps hitting the '
              "switch's default: branch");
    });

    test('an already-normalised stored tag is left as-is (no spurious '
        're-persist of an unrelated value)', () async {
      SharedPreferences.setMockInitialValues({'locale': 'zh-Hant'});
      final s = AppSettings();
      await s.loadSettings();
      expect(s.locale, 'zh-Hant');
    });
  });

  group('_applyUserPrefsBlob (cross-device sync) normalises too', () {
    test('a synced blob carrying a raw "zh" resolves to Simplified',
        () async {
      SharedPreferences.setMockInitialValues({
        'profile.guest.userPrefs': jsonEncode({'locale': 'zh'}),
      });
      final s = AppSettings();
      await s.loadSettings();
      expect(s.locale, 'zh-Hans',
          reason: 'the blob is the newest-device snapshot and takes '
              'precedence over the legacy per-key read; it must not '
              'reintroduce the unnormalised tag it fixed above');
    });
  });
}
