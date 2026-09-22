import 'package:flutter_test/flutter_test.dart';
import 'package:yahwehs_words/services/google_fonts_reachability.dart';
import 'package:yahwehs_words/utils/font_catalog.dart';

/// `FontOption.labelFor()` had zero test coverage (`grep -rn "labelFor"
/// test/` was empty) despite being reader-visible on every row of the
/// Settings → Font Family dropdown. It's fed `settings.locale`, which is
/// assigned with no validation on three paths (`AppSettings.setLocale`,
/// `fromMap`, and the SharedPreferences load — see
/// `lib/models/app_settings.dart:1034,1537,1877`), so an unrecognised
/// `zh-*` tag is reachable. Before the fix, `label[locale] ?? label['en']
/// ?? key` exact-matched past a bare `'zh'` or any other `zh-XX` tag
/// straight to the English label — the same failure mode
/// `biblical_role.dart`'s `localizedRole()` was fixed for (queue:183,
/// commit 9add37bb) and `lib/pages/help_page.dart`'s `HelpKeyRow.label`
/// shares (fixed alongside this in the same commit). See
/// docs/autonomous-queue.md:21308.
///
/// Running this suite against the unfixed helper (`label[locale] ??
/// label['en'] ?? key`), 2 cases went red: `'zh'` and `'zh-XX'` both
/// rendered the English label instead of Simplified.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const bilingual = FontOption(
    key: 'Test Font',
    label: {
      'en': 'Test Font (serif)',
      'zh-Hans': '测试字体（衬线）',
      'zh-Hant': '測試字體（襯線）',
    },
  );
  const missing = FontOption(key: '__missing__', label: {});

  group("an unrecognised zh-* locale degrades to Simplified, not English "
      '(the fix)', () {
    test('bare "zh"', () {
      expect(bilingual.labelFor('zh'), '测试字体（衬线）');
    });

    test('arbitrary "zh-XX"', () {
      expect(bilingual.labelFor('zh-SG'), '测试字体（衬线）');
    });
  });

  test('zh-Hant / zh-Hans / en all resolve to their own entry', () {
    expect(bilingual.labelFor('zh-Hant'), '測試字體（襯線）');
    expect(bilingual.labelFor('zh-Hans'), '测试字体（衬线）');
    expect(bilingual.labelFor('en'), 'Test Font (serif)');
  });

  test('a non-zh unknown locale falls to English, unchanged behaviour', () {
    expect(bilingual.labelFor('fr'), 'Test Font (serif)');
  });

  test(
      'the __missing__ sentinel (label: {}) still returns key for every '
      'locale, including zh — resolveFontFamily/migrateLegacyFontKey '
      'depend on this terminal fallback', () {
    for (final locale in ['en', 'zh', 'zh-Hans', 'zh-Hant', 'zh-XX', 'fr']) {
      expect(missing.labelFor(locale), '__missing__', reason: locale);
    }
  });

  test(
      'coverage guard: every real catalogue entry carries zh-Hans, so a '
      'future font added with English only fails a test instead of '
      'silently rendering English to a Chinese UI', () {
    GoogleFontsReachabilityService.instance.debugReset();
    GoogleFontsReachabilityService.instance
        .debugSetVerdict(GoogleFontsReachability.reachable);
    addTearDown(GoogleFontsReachabilityService.instance.debugReset);

    final catalog = availableFontOptions();
    expect(catalog.length, greaterThan(10),
        reason: 'the reachable-verdict gate did not return the full '
            'catalogue');
    for (final f in catalog) {
      expect(f.label.containsKey('zh-Hans'), isTrue, reason: f.key);
      expect(f.label.containsKey('zh-Hant'), isTrue, reason: f.key);
      expect(f.label.containsKey('en'), isTrue, reason: f.key);
    }
  });
}
