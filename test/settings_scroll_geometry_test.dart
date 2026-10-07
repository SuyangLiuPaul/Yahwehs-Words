import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahwehs_words/models/app_settings.dart';
import 'package:yahwehs_words/pages/settings_page.dart';
import 'package:yahwehs_words/providers/main_provider.dart';

void main() {
  for (final platform in [
    TargetPlatform.iOS,
    TargetPlatform.android,
    TargetPlatform.macOS,
    TargetPlatform.windows
  ]) {
    for (final locale in ['en', 'zh-Hans', 'zh-Hant']) {
      for (final width in [390.0, 1024.0]) {
        testWidgets('$platform $locale $width: exact settings scroll geometry',
            (tester) async {
          SharedPreferences.setMockInitialValues({});
          debugDefaultTargetPlatformOverride = platform;
          addTearDown(() => debugDefaultTargetPlatformOverride = null);
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => MainProvider()),
              ChangeNotifierProvider(create: (_) => AppSettings()),
            ],
            child: MaterialApp(
                builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: const TextScaler.linear(1.3)),
                    child: child!),
                home:
                    const SettingsPage(initialSection: SettingsSection.about)),
          ));
          await tester.pumpAndSettle();
          final settings = Provider.of<AppSettings>(
              tester.element(find.byType(SettingsPage)),
              listen: false);
          await settings.setLocale(locale);
          await tester.pump(const Duration(seconds: 1));
          await tester.pumpAndSettle();
          final scroll = find
              .descendant(
                  of: find.byKey(const Key('settings.scroll')),
                  matching: find.byType(Scrollable))
              .first;
          final position = tester.state<ScrollableState>(scroll).position;
          final extent = position.maxScrollExtent;
          expect(extent, greaterThan(0));
          for (final fraction in [0.9, 0.5, 0.95, 0.2, 0.8]) {
            final expected = extent * fraction;
            position.jumpTo(expected);
            await tester.pumpAndSettle();
            expect(position.pixels, closeTo(expected, 0.01));
            expect(position.maxScrollExtent, closeTo(extent, 0.01));
            expect(tester.takeException(), isNull);
          }
          debugDefaultTargetPlatformOverride = null;
        });
      }
    }
  }
}
