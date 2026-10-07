import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahwehs_words/widgets/diagnosis_tile.dart';
import 'package:yahwehs_words/services/installation_diagnostics.dart';

void main() {
  testWidgets('narrow layout supports all locales and readable scaled text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    InstallationDiagnostics.clearMemoryForTest();
    for (final locale in ['en', 'zh-Hans', 'zh-Hant']) {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: SingleChildScrollView(
                  child: MediaQuery(
                      data: const MediaQueryData(
                          textScaler: TextScaler.linear(1.5)),
                      child: DiagnosisTile(
                          key: ValueKey(locale), locale: locale))))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(SelectableText), findsOneWidget);
      expect(find.byType(TextButton), findsNWidgets(3));
    }
  });
}
