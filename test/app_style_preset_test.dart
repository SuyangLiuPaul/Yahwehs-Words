import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
// `google_fonts_base.dart` is `lib/src/`, not re-exported by the public
// `google_fonts.dart` barrel — but its `httpClient` field is explicitly
// `@visibleForTesting` and this is the seam the package's own test suite
// uses (see google_fonts' `load_font_if_necessary_test.dart`).
// ignore: implementation_imports
import 'package:google_fonts/src/google_fonts_base.dart' as gfb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yahwehs_words/constants/ui_strings.dart';
import 'package:yahwehs_words/models/app_settings.dart';
import 'package:yahwehs_words/models/app_style_preset.dart';
import 'package:yahwehs_words/utils/font_catalog.dart';

/// `resolveFontFamily` (font_catalog.dart:508) calls `GoogleFonts.getFont`
/// synchronously and returns a fallback-family TextStyle immediately —
/// the actual bytes fetch runs detached in the background, which is fine
/// in a real app (the font just swaps in once it arrives) but is fatal
/// inside `flutter test`: the harness's mocked HttpClient always answers
/// 400, so that detached fetch always rejects, and the rejection surfaces
/// on some *later*, unrelated test ("test failed after it had already
/// completed"). A client whose `get` never resolves means the fetch never
/// rejects either — it just never finishes, which is invisible and
/// harmless for a short-lived test process.
class _HangingHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return Completer<http.StreamedResponse>().future;
  }
}

/// Round-56 shipped two bugs in this file that neither `flutter analyze`
/// nor any existing test would have caught:
///   1. `detectActivePreset` compared the wrong settings field
///      (`fontFamily` vs `fontSelection`), so tapping Modern / Reverent /
///      Reader applied the settings correctly but never showed the card
///      as selected ("why clicked modern or jingqian not showing
///      selected").
///   2. Presets shipped CSS-only font keys (`system-ui`, `Garamond`,
///      `Georgia`) that CanvasKit can't load, so choosing those presets
///      silently rendered everything in Roboto.
/// This file pins the invariants both bugs broke, plus the localization
/// completeness the Settings UI depends on to render a card at all.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  gfb.httpClient = _HangingHttpClient();

  Future<AppSettings> freshSettings() async {
    SharedPreferences.setMockInitialValues({});
    final s = AppSettings();
    await s.loadSettings();
    return s;
  }

  group('presetDefinitions', () {
    test('covers every AppStylePreset value', () {
      for (final preset in AppStylePreset.values) {
        expect(presetDefinitions.containsKey(preset), isTrue,
            reason: '$preset has no entry in presetDefinitions, so '
                'apply() would silently no-op for it');
      }
    });

    test('every fontFamily is a real catalogue key', () {
      for (final entry in presetDefinitions.entries) {
        expect(isValidFontKey(entry.value.fontFamily), isTrue,
            reason: '${entry.key} uses fontFamily '
                '"${entry.value.fontFamily}", which is not in '
                'font_catalog.dart — CanvasKit would silently fall back '
                'to Roboto for this preset (the original Round-56 bug)');
      }
    });

    test('every definition is pairwise distinct', () {
      final defs = presetDefinitions.entries.toList();
      for (var i = 0; i < defs.length; i++) {
        for (var j = i + 1; j < defs.length; j++) {
          final a = defs[i].value;
          final b = defs[j].value;
          final identical = a.fontFamily == b.fontFamily &&
              (a.fontSize - b.fontSize).abs() < 0.01 &&
              (a.lineSpacing - b.lineSpacing).abs() < 0.01 &&
              (a.menuScale - b.menuScale).abs() < 0.01 &&
              a.paragraphMode == b.paragraphMode &&
              a.cardMaterial == b.cardMaterial;
          expect(identical, isFalse,
              reason: '${defs[i].key} and ${defs[j].key} compare equal '
                  'on every field detectActivePreset checks, so applying '
                  'either would make both cards light up (or neither, '
                  'depending on map order)');
        }
      }
    });

    test('every preset has non-empty label + description in all three '
        'locales', () {
      const locales = ['zh-Hans', 'zh-Hant', 'en'];
      for (final preset in AppStylePreset.values) {
        for (final suffix in ['label', 'description']) {
          final key = 'stylePreset_${preset.name}_$suffix';
          final entry = uiStrings[key];
          expect(entry, isNotNull,
              reason: 'uiStrings is missing "$key" — the Settings UI '
                  'would show a blank card for $preset');
          for (final locale in locales) {
            final value = entry![locale];
            expect(value, isNotNull,
                reason: '"$key" has no "$locale" entry');
            expect(value!.trim(), isNotEmpty,
                reason: '"$key" has an empty "$locale" entry');
          }
        }
      }
    });
  });

  group('apply() / detectActivePreset() round-trip', () {
    for (final preset in AppStylePreset.values) {
      test('applying ${preset.name} makes it detected as active', () async {
        final s = await freshSettings();
        await preset.apply(s);
        expect(detectActivePreset(s), preset,
            reason: 'apply() wrote settings that detectActivePreset() '
                'does not recognise as ${preset.name} — this is exactly '
                'the Round-56 "card not showing selected" bug');
      });
    }
  });

  test('a fresh AppSettings (no prior preferences) detects as '
      'systemDefault', () async {
    final s = await freshSettings();
    expect(detectActivePreset(s), AppStylePreset.systemDefault,
        reason: 'AppSettings field defaults (fontSelection="system", '
            'fontSize=20.0, lineSpacing=1.5, menuScale=1.0, '
            'paragraphMode=true, cardMaterial=classic) are expected to '
            'match the systemDefault preset definition exactly');
  });

  test('resetAllSettings() detects as systemDefault', () async {
    final s = await freshSettings();
    // Move every field the reset touches away from its default first,
    // so this proves the reset — not merely the untouched default.
    await AppStylePreset.carbon.apply(s);
    expect(detectActivePreset(s), AppStylePreset.carbon);

    await s.resetAllSettings();
    expect(detectActivePreset(s), AppStylePreset.systemDefault,
        reason: 'resetAllSettings() is supposed to return the user to '
            'the system-default look');
  });
}
