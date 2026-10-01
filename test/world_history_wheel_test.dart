import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahwehs_words/models/app_settings.dart';
import 'package:yahwehs_words/pages/world_history_wheel_page.dart';
import 'package:yahwehs_words/utils/world_wheel_geometry.dart';
import 'package:yahwehs_words/world_history/models/wheel_history.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
      final name = utf8.decode(message!.buffer
          .asUint8List(message.offsetInBytes, message.lengthInBytes));
      final file = File(name);
      return file.existsSync()
          ? ByteData.sublistView(file.readAsBytesSync())
          : null;
    });
  });
  test('ported data matches the audited Sword source snapshot', () {
    final manifest = jsonDecode(
        File('docs/world-wheel-port-20261001.json').readAsStringSync()) as Map;
    for (final item in (manifest['sha256'] as Map).entries) {
      if (!item.key.startsWith('assets/')) continue;
      final file =
          File(item.key.replaceFirst('assets/', 'assets/world_chart/'));
      expect(sha256.convert(file.readAsBytesSync()).toString(), item.value);
    }
    final j = jsonDecode(
            File('assets/world_chart/wheel_history.json').readAsStringSync())
        as Map;
    expect((j['streams'] as List).length, 22);
    expect((j['nations'] as List).length, 82);
    expect((j['powers'] as List).length, 305);
    expect((j['events'] as List).length, 783);
  });
  test('world canvas labels explicitly carry the bundled CJK fallback', () {
    final source =
        File('lib/pages/world_history_wheel_page.dart').readAsStringSync();
    expect('TextPainter('.allMatches(source).length, 2);
    expect('fontFamilyFallback: kCjkFontFallback'.allMatches(source).length, 2);
  });
  testWidgets('event passages and chronology evidence stay separate',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.runAsync(() => WheelHistoryService.instance.load());
    final data = WheelHistoryService.instance.cached!;
    final event = data.events
        .firstWhere((e) => e.refs.isNotEmpty && e.datingRefs.isNotEmpty);
    final settings = AppSettings();
    await settings.setLocale('en');
    await tester.pumpWidget(ChangeNotifierProvider<AppSettings>.value(
        value: settings,
        child: MaterialApp(home: const WorldHistoryWheelPage())));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), event.titleFor('en'));
    await tester.pumpAndSettle();
    final eventRow = find.byKey(ValueKey('world.event.${event.id}'));
    await tester.scrollUntilVisible(eventRow, 200,
        scrollable: find
            .descendant(
                of: find.byType(ListView), matching: find.byType(Scrollable))
            .first);
    await tester.ensureVisible(eventRow);
    await tester.pumpAndSettle();
    await tester.tap(eventRow);
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('Narrative passages'), findsOneWidget);
    expect(find.text('Dating evidence'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  test('geometry and hit detection share the painted event point', () {
    final a = worldEventPoint(-1000, 2, 22, 2026);
    final b = worldEventPoint(1000, 2, 22, 2026);
    expect(closestWorldEvent(a, [a, b]), 0);
    expect(closestWorldEvent(b, [a, b]), 1);
    expect(closestWorldEvent(Offset.zero, [a, b]), isNull);
    expect(worldYearAngle(worldWheelStart, 2026), closeTo(-math.pi / 2, 1e-12));
    expect(worldYearLabel(-1, 'en'), 'BC 1');
    expect(worldYearLabel(1, 'en'), 'AD 1');
  });
  for (final width in [320.0, 402.0, 1024.0]) {
    testWidgets(
        'world wheel data and navigation work at $width with large text',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = Size(width, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() => WheelHistoryService.instance.load());
      final data = WheelHistoryService.instance.cached!;
      expect(data.events.length, greaterThan(783));
      expect(
          data.events.every((e) => data.streams.any((s) => s.id == e.stream)),
          isTrue);
      final settings = AppSettings();
      await settings.setLocale('en');
      await tester.pumpWidget(ChangeNotifierProvider<AppSettings>.value(
          value: settings,
          child: MaterialApp(
              builder: (c, child) => MediaQuery(
                  data: MediaQuery.of(c)
                      .copyWith(textScaler: TextScaler.linear(1.8)),
                  child: child!),
              home: const WorldHistoryWheelPage())));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('World history wheel'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Reset view'), 150,
          scrollable: find
              .descendant(
                  of: find.byType(ListView), matching: find.byType(Scrollable))
              .first);
      await tester.ensureVisible(find.text('Reset view'));
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Reset view'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
}
