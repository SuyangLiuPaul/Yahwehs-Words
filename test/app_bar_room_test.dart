// Home and the language menu step aside on a cramped sub-page — and
// only there. 2026-09-21; the reasoning is on `kRoomyAppBarWidth`.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahwehs_words/models/app_settings.dart';
import 'package:yahwehs_words/widgets/home_icon_button.dart';
import 'package:yahwehs_words/widgets/language_switcher_button.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget bar() => Scaffold(
        appBar: AppBar(
          title: const Text('page'),
          actions: const [LanguageSwitcherButton(), HomeIconButton()],
        ),
      );

  Future<void> pump(WidgetTester tester, double width,
      {required bool pushed}) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = Size(width, 700);
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => AppSettings(),
      child: MaterialApp(
        home: pushed
            ? Builder(
                builder: (ctx) => Scaffold(
                  body: TextButton(
                    onPressed: () => Navigator.of(ctx)
                        .push(MaterialPageRoute<void>(builder: (_) => bar())),
                    child: const Text('go'),
                  ),
                ),
              )
            : bar(),
      ),
    ));
    if (pushed) {
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
    }
  }

  testWidgets('a cramped sub-page drops both', (tester) async {
    await pump(tester, 320, pushed: true);
    expect(find.byIcon(Icons.home_rounded), findsNothing);
    expect(find.byIcon(Icons.language_rounded), findsNothing);
  });

  testWidgets('a roomy sub-page keeps both', (tester) async {
    await pump(tester, 390, pushed: true);
    expect(find.byIcon(Icons.home_rounded), findsOneWidget);
    expect(find.byIcon(Icons.language_rounded), findsOneWidget);
  });

  testWidgets('the home page keeps its language menu at any width',
      (tester) async {
    // The root page's bar is never the crowded one, and it is where a
    // reader looks for the language before they know Settings has it.
    await pump(tester, 320, pushed: false);
    expect(find.byIcon(Icons.language_rounded), findsOneWidget);
  });
}
