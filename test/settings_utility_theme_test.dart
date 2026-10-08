import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahwehs_words/widgets/settings_utility_theme.dart';
import 'package:yahwehs_words/widgets/manual_update_tile.dart';
import 'package:yahwehs_words/widgets/diagnosis_tile.dart';

void main() {
  test('both app themes carry the selected font across every text role', () {
    final source = File('lib/main.dart').readAsStringSync();
    for (final brightness in ['light', 'dark']) {
      expect(
          RegExp('ThemeData\\.$brightness\\(\\)\\.textTheme\\.apply\\(\\s*fontFamily: settings.fontFamily,\\s*fontFamilyFallback: kCjkFontFallback,')
              .hasMatch(source),
          isTrue);
    }
  });
  for (final width in [320.0, 390.0, 768.0, 1280.0]) {
    for (final locale in ['en', 'zh-Hans', 'zh-Hant']) {
      testWidgets('utility typography and icons $locale at $width',
          (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = Size(width, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        for (final brightness in Brightness.values) {
          await tester.pumpWidget(MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: Scaffold(
                body: SingleChildScrollView(
                    child: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
              child: SettingsUtilityTheme(
                  fontSize: 20,
                  fontFamily: 'Roboto',
                  child: Column(children: [
                    ManualUpdateTile(
                        locale: locale,
                        checker: () async => const ManualUpdateResult(
                            ManualUpdateKind.upToDate)),
                    DiagnosisTile(locale: locale),
                  ])),
            ))),
          ));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final context = tester.element(find.byType(ManualUpdateTile));
          expect(ListTileTheme.of(context).titleTextStyle!.fontSize, 20);
          expect(IconTheme.of(context).size, 24);
          expect(Theme.of(context).textTheme.titleMedium!.fontWeight,
              FontWeight.w600);
          final tile = tester.widget<ListTile>(find.byType(ListTile));
          expect(tile.contentPadding,
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8));
          expect(find.byType(SelectableText), findsOneWidget);
        }
      });
    }
  }
}
