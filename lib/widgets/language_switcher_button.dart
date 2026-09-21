import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:yahwehs_words/constants/ui_strings.dart';
import 'package:yahwehs_words/models/app_settings.dart';
import 'package:yahwehs_words/utils/app_bar_room.dart';

/// One-tap interface-language switcher, extracted from the version
/// that first shipped on the Home dashboard (2026-08-02 field
/// request: "a visible language switcher instead of digging into
/// Settings → App → Interface Language every time").
///
/// 2026-08-03: user asked for it on EVERY page, not just Home — the
/// Dashboard-only copy was inlined there, so this widget makes it a
/// one-line drop-in for every other page's AppBar `actions` instead
/// of duplicating the PopupMenuButton everywhere. Calls the same
/// `settings.setLocale`the Settings dropdown and the Dashboard
/// switcher already used, so all three stay in sync — none of them
/// is "the real one".
class LanguageSwitcherButton extends StatelessWidget {
  const LanguageSwitcherButton({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final locale = settings.locale;
    // On a narrow screen a SUB-page gives this room back to its own
    // title or field: the language is in Settings, and the home page's
    // bar — which is never crowded — keeps this button at every width.
    // See `kRoomyAppBarWidth`.
    if (appBarIsCramped(context) && Navigator.of(context).canPop()) {
      return const SizedBox.shrink();
    }
    return PopupMenuButton<String>(
      tooltip:
          uiStrings['interfaceLanguage']?[locale] ?? 'Interface Language',
      icon: const Icon(Icons.language_rounded),
      initialValue: locale,
      onSelected: (val) => settings.setLocale(val),
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'zh-Hans', child: Text('简体中文')),
        PopupMenuItem(value: 'zh-Hant', child: Text('繁體中文')),
        PopupMenuItem(value: 'en', child: Text('English')),
      ],
    );
  }
}
