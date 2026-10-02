import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_icon_service.dart';

/// What the phone's chosen theme looks like to the devices that mirror it:
/// Apple Watch, Wear OS and the car.
///
/// The owner asked (2026-10-03) for the watch and the car to carry the app's
/// logo and to follow the theme colour like the phone does. They cannot read
/// the phone's settings, so the phone tells them: [accent] is the theme colour
/// as an ARGB integer, [logo] names the matching logo variant (the same
/// buckets the home-screen icon uses, see `AppIconService.variantForColor`).
///
/// The car's own screen colours and fonts belong to CarPlay / Android Auto and
/// cannot be restyled by an app; what an app does control there is the
/// artwork, so [artwork] is the themed logo that stands in for a cover.
class CompanionTheme {
  const CompanionTheme._();

  static const _prefsKey = 'primaryColor';
  static int _argb = Colors.lightBlue.toARGB32();

  /// The theme colour, as stored (`Color.toARGB32`).
  static int get accent => _argb;

  /// `Default` (the blue mark) or one of `Red`, `Orange`, `Green`, `Purple`,
  /// `Pink`, `Dark`.
  static String get logo =>
      AppIconService.variantForColor(Color(_argb)) ?? 'Default';

  /// The themed logo as a 512 px image on the website, used wherever a song or
  /// sermon has no cover of its own.
  static Uri get artwork => Uri.parse(
      'https://yahwehword.com/icons/Icon-${logo == 'Default' ? '' : '$logo-'}512.png');

  /// Records the colour. Returns true when it changed.
  static bool update(Color color) {
    final next = color.toARGB32();
    if (next == _argb) return false;
    _argb = next;
    return true;
  }

  /// Reads the saved colour when settings have not loaded yet (the engine can
  /// start for CarPlay or the watch before any screen exists).
  static Future<bool> loadSaved() async {
    final saved = (await SharedPreferences.getInstance()).getInt(_prefsKey);
    return saved == null ? false : update(Color(saved));
  }

  @visibleForTesting
  static void reset() => _argb = Colors.lightBlue.toARGB32();
}
