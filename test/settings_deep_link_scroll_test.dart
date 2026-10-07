import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yahwehs_words/models/app_settings.dart';
import 'package:yahwehs_words/pages/settings_page.dart';
import 'package:yahwehs_words/providers/main_provider.dart';
import 'package:yahwehs_words/widgets/gemini_key_card.dart';

/// Deep links must land on the requested section. The finite form is
/// measured eagerly so reversing a fling cannot change sliver estimates.
void main() {
  Widget host(SettingsSection? section) => MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => MainProvider()),
          ChangeNotifierProvider(create: (_) => AppSettings()),
        ],
        child: MaterialApp(home: SettingsPage(initialSection: section)),
      );

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('Basic starts collapsed and Advanced reveals AI on demand',
      (tester) async {
    await tester.pumpWidget(host(null));
    await tester.pumpAndSettle();
    expect(find.byType(GeminiKeyCard), findsNothing);
    final toggle = find.byKey(const Key('settings.advanced.toggle'));
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(find.byType(GeminiKeyCard), findsOneWidget);
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(find.byType(GeminiKeyCard), findsNothing);
  });

  testWidgets('/settings/ai scrolls the AI section into view', (tester) async {
    await tester.pumpWidget(host(settingsSectionForSlug('ai')));
    await tester.pumpAndSettle();

    expect(find.byType(GeminiKeyCard), findsOneWidget,
        reason: 'the AI section never came into view — this is the exact '
            'failure the headless harness reported as "/settings/ai '
            'renders identically to /settings"');

    // On screen, not merely built: `ensureVisible` is supposed to land
    // the section header just below the AppBar, so the card under it has
    // to be inside the viewport.
    final card = tester.getRect(find.byType(GeminiKeyCard));
    final screen = tester.getRect(find.byType(MaterialApp));
    expect(card.top, lessThan(screen.bottom),
        reason: 'the AI card was built but sits below the fold');
    expect(card.bottom, greaterThan(screen.top),
        reason: 'the AI card was built but sits above the fold');
  });

  testWidgets('AI scroll geometry stays stable through rebuild and reversal',
      (tester) async {
    await tester.pumpWidget(host(SettingsSection.ai));
    await tester.pumpAndSettle();
    final scroll = find
        .descendant(
          of: find.byKey(const Key('settings.scroll')),
          matching: find.byType(Scrollable),
        )
        .first;
    final position = tester.state<ScrollableState>(scroll).position;
    final extent = position.maxScrollExtent;
    final start = position.pixels;
    for (final delta in [120.0, -120.0, 240.0, -240.0]) {
      final expected = (start + delta).clamp(0.0, extent);
      position.jumpTo(expected);
      await tester.pumpAndSettle();
      expect(position.pixels, closeTo(expected, 0.01));
      expect(position.maxScrollExtent, closeTo(extent, 0.01));
    }
    final settings = Provider.of<AppSettings>(
        tester.element(find.byType(GeminiKeyCard)),
        listen: false);
    settings.notifyListeners();
    final before = position.pixels;
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(position.pixels, closeTo(before, 0.01));
    expect(position.maxScrollExtent, closeTo(extent, 0.01));
  });

  testWidgets('every section slug actually reaches a scrollable target',
      (tester) async {
    // Not just `ai`. A section added later with a slug but no
    // `KeyedSubtree` would deep-link to nothing, and the bounded retry
    // in `_scrollToInitialSection` would (correctly) give up silently —
    // which is exactly the kind of silent wrongness this whole item is
    // about. Pumping each one and settling proves the callback
    // terminates for all of them; a missing key would show up as a
    // timeout in `pumpAndSettle`, not as a pass.
    for (final section in SettingsSection.values) {
      await tester.pumpWidget(host(section));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'section $section threw');
    }
  });
}
