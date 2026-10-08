import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahwehs_words/models/app_settings.dart';
import 'package:yahwehs_words/utils/fuzzy_search.dart' as fuzzy;
import 'package:yahwehs_words/utils/pinyin_search.dart' as pinyin;
import 'package:yahwehs_words/widgets/search_options_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    fuzzy.setFuzzySearchEnabled(false);
    pinyin.setPinyinSearchEnabled(false);
  });
  tearDown(() {
    fuzzy.setFuzzySearchEnabled(false);
    pinyin.resetPinyinSearchForTest();
  });

  void expectMode(AppSettings settings, bool f, bool p) {
    expect(settings.fuzzySearch, f);
    expect(settings.pinyinSearch, p);
    expect(fuzzy.fuzzySearchEnabled, f);
    expect(pinyin.pinyinSearchEnabled, p);
  }

  test('retired pinyin cannot be enabled by a legacy caller', () async {
    final s = AppSettings();
    await s.loadSettings();
    await s.setFuzzySearch(true);
    await s.setPinyinSearch(true);
    expectMode(s, true, false);
    await s.setFuzzySearch(false);
    expectMode(s, false, false);
    s.dispose();
  });

  for (final f in [false, true]) {
    for (final p in [false, true]) {
      test('loads and normalizes stored fuzzy=$f pinyin=$p', () async {
        SharedPreferences.setMockInitialValues(
            {'fuzzySearch': f, 'pinyinSearch': p});
        final s = AppSettings();
        await s.loadSettings();
        expectMode(s, f, false);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('pinyinSearch'), false);
        s.dispose();
      });
    }
  }

  test('legacy fuzzy-only preference never implicitly enables pinyin',
      () async {
    SharedPreferences.setMockInitialValues({'fuzzySearch': true});
    final s = AppSettings();
    await s.loadSettings();
    expectMode(s, true, false);
    s.dispose();
  });

  for (final finalFuzzy in [true, false]) {
    test('rapid fuzzy changes persist across restart', () async {
      final s = AppSettings();
      await s.loadSettings();
      await Future.wait([
        s.setFuzzySearch(true),
        s.setFuzzySearch(false),
        s.setFuzzySearch(finalFuzzy)
      ]);
      final next = AppSettings();
      await next.loadSettings();
      expectMode(next, finalFuzzy, false);
      s.dispose();
      next.dispose();
    });
  }

  test('reset while a write is queued preserves exact mode', () async {
    final s = AppSettings();
    await s.loadSettings();
    final write = s.setFuzzySearch(true);
    await s.resetAllSettings();
    await write;
    expectMode(s, false, false);
    final next = AppSettings();
    await next.loadSettings();
    expectMode(next, false, false);
    s.dispose();
    next.dispose();
  });

  for (final width in [320.0, 402.0, 1024.0]) {
    testWidgets('search chips switch or clear the mode at $width',
        (tester) async {
      final s = AppSettings();
      await s.loadSettings();
      await tester.binding.setSurfaceSize(Size(width, 874));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: AnimatedBuilder(
        animation: s,
        builder: (context, _) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(1.8)),
          child: SearchOptionsBar(
              locale: 'en',
              fuzzy: s.fuzzySearch,
              onFuzzyChanged: s.setFuzzySearch),
        ),
      ))));
      await tester.tap(find.widgetWithText(FilterChip, 'Fuzzy search'));
      await tester.pumpAndSettle();
      expectMode(s, true, false);
      expect(find.text('Pinyin search'), findsNothing);
      await tester.tap(find.widgetWithText(FilterChip, 'Fuzzy search'));
      await tester.pumpAndSettle();
      expectMode(s, false, false);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      s.dispose();
    });
  }
}
