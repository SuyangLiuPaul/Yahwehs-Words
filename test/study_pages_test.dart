import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahwehs_words/models/app_settings.dart';
import 'package:yahwehs_words/models/study_data.dart';
import 'package:yahwehs_words/pages/study_principles_page.dart';
import 'package:yahwehs_words/pages/study_promises_page.dart';
import 'package:yahwehs_words/services/sermon_service.dart';
import 'package:yahwehs_words/utils/reference_parser.dart';
import 'package:yahwehs_words/utils/route_paths.dart';

/// The two hidden research pages (圣经原则 / 神的应许). They have no link
/// anywhere; these tests guard the DATA (every sermon quote is verbatim in the
/// sermon text, every reference resolves) and the layout at phone width.
Future<String> _file(String path) async => File(path).readAsStringSync();

String _flat(String s) => s.replaceAll(RegExp(r'\s+'), '');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
      final name = utf8.decode(message!.buffer
          .asUint8List(message.offsetInBytes, message.lengthInBytes));
      if (name == 'AssetManifest.bin') {
        return const StandardMessageCodec().encodeMessage(<String, Object?>{});
      }
      final f = File(name);
      if (!f.existsSync()) return null;
      return ByteData.sublistView(f.readAsBytesSync());
    });
  });

  group('data', () {
    late StudyPromises promises;
    late StudyPrinciples principles;
    setUpAll(() async {
      promises = await StudyData.loadPromises(loader: _file);
      principles = await StudyData.loadPrinciples(loader: _file);
    });

    test('sizes: 47 promises in 10 groups, 9 propositions, 9 principles', () {
      expect(promises.promises, hasLength(47));
      expect(promises.groups, hasLength(10));
      expect(promises.propositions, hasLength(9));
      expect(principles.principles, hasLength(9));
    });

    test('statuses, conditions and verdicts are all known', () {
      for (final p in promises.promises) {
        expect(promises.status.keys, contains(p.status), reason: p.id);
        expect(promises.conds.keys, contains(p.cond), reason: p.id);
        expect(promises.groups.map((g) => g.$1), contains(p.group));
      }
      for (final c in [...promises.propositions, ...principles.principles]) {
        expect(principles.verdicts.keys, contains(c.verdict), reason: c.id);
      }
    });

    test('every reference parses to a real chapter', () {
      final refs = <String>{
        for (final p in promises.promises) ...p.refs,
        for (final p in promises.promises) ...p.fulfilRefs,
        for (final c in promises.propositions) ...c.verses,
        for (final c in principles.principles) ...c.verses,
      };
      expect(refs.length, greaterThan(150));
      for (final r in refs) {
        expect(parseReference(r), isNotNull, reason: r);
      }
    });

    test('every sermon quote is verbatim in that sermon (zh-CN)', () {
      final quotes = <(String, String)>[
        for (final p in promises.promises)
          for (final q in p.sermons) (q.sermonId, q.quote.of('zh-Hans')),
        for (final c in promises.propositions)
          for (final q in c.quotes) (q.sermonId, q.quote.of('zh-Hans')),
        for (final c in principles.principles)
          for (final q in c.quotes) (q.sermonId, q.quote.of('zh-Hans')),
      ];
      expect(quotes.length, greaterThan(50));
      for (final (id, text) in quotes) {
        final f = File('assets/sermons/zh-CN/$id.txt');
        expect(f.existsSync(), isTrue, reason: id);
        expect(_flat(f.readAsStringSync()), contains(_flat(text)),
            reason: '$id: $text');
      }
    });

    test(
        'Traditional Chinese exists for every text and differs from Simplified',
        () {
      var differs = 0;
      for (final p in promises.promises) {
        expect(p.title.of('zh-Hant'), isNotEmpty);
        if (p.fulfil.of('zh-Hant') != p.fulfil.of('zh-Hans')) differs++;
        expect(p.title.of('en'), isNotEmpty);
      }
      expect(differs, greaterThan(30));
    });

    test('history notes always name a source, and sources have URLs', () {
      for (final p in promises.promises) {
        if (p.history != null && p.sources.isEmpty) {
          // Notes that make a claim about history must be sourced; the few
          // that only say "this cannot be tested" are allowed.
          expect(
              p.history!.of('zh-Hans'),
              anyOf(contains('无法'), contains('没有核查'), contains('没有成真'),
                  contains('按多数解释')),
              reason: p.id);
        }
        for (final s in p.sources) {
          expect(s.url, startsWith('https://'));
        }
      }
    });

    test('the pages are registered and linked from nowhere', () {
      expect(kRegisteredRoutePaths, contains('/study/principles'));
      expect(kRegisteredRoutePaths, contains('/study/promises'));
      for (final f in Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        final src = f.readAsStringSync();
        final defines = f.path.endsWith('study_principles_page.dart') ||
            f.path.endsWith('study_promises_page.dart') ||
            f.path.endsWith('route_paths.dart') ||
            f.path.endsWith('main.dart');
        if (defines) continue;
        expect(src, isNot(contains('StudyPromisesPage')), reason: f.path);
        expect(src, isNot(contains('StudyPrinciplesPage')), reason: f.path);
        expect(src, isNot(contains('kStudyPromisesPath')), reason: f.path);
        expect(src, isNot(contains('kStudyPrinciplesPath')), reason: f.path);
      }
    });
  });

  Future<void> mount(WidgetTester tester, Widget page,
      {double width = 402, double scale = 1, String locale = 'zh-Hans'}) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = Size(width, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final settings = AppSettings();
    await settings.setLocale(locale);
    await tester.runAsync(() async {
      await SermonService.instance.loadIndex();
    });
    await tester.pumpWidget(ChangeNotifierProvider<AppSettings>.value(
        value: settings,
        child: MaterialApp(
            builder: (c, child) => MediaQuery(
                data: MediaQuery.of(c)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!),
            home: page)));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  for (final width in [320.0, 402.0, 1024.0]) {
    testWidgets('promises page lays out at $width with 1.6x text',
        (tester) async {
      await mount(tester, const StudyPromisesPage(loader: _file),
          width: width, scale: 1.6);
      expect(find.text('神有很多应许'), findsOneWidget);
      await tester.scrollUntilVisible(
          find.byKey(const ValueKey('promise.abraham-land')), 200,
          scrollable: find
              .descendant(
                  of: find.byType(ListView).first,
                  matching: find.byType(Scrollable))
              .first);
      await tester
          .ensureVisible(find.byKey(const ValueKey('promise.abraham-land')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('promise.abraham-land')),
          warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('应验与现状'), findsWidgets);
      expect(find.byType(ActionChip), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('promises: filtering by status narrows the list', (tester) async {
    await mount(tester, const StudyPromisesPage(loader: _file));
    expect(find.textContaining('显示 47 / 47'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('status.✘')));
    await tester.pump();
    expect(find.textContaining('显示 7 / 47'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('status.✘')));
    await tester.pump();
    expect(find.textContaining('显示 47 / 47'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('study.search')), '洪水');
    await tester.pump();
    expect(find.byKey(const ValueKey('promise.noah-flood')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('promises: the sermon-comparison tab shows nine claims',
      (tester) async {
    await mount(tester, const StudyPromisesPage(loader: _file));
    await tester.tap(find.text('讲道对照'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('proposition.no-unconditional')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('quote.070')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 402.0, 1024.0]) {
    testWidgets('principles page lays out at $width with 1.6x text',
        (tester) async {
      await mount(tester, const StudyPrinciplesPage(loader: _file),
          width: width, scale: 1.6);
      expect(find.text('讲道自己说出来的原则'), findsOneWidget);
      await tester.scrollUntilVisible(
          find.byKey(const ValueKey('principle.gospel-three')), 200,
          scrollable: find.byType(Scrollable).first);
      expect(
          find.byKey(const ValueKey('principle.gospel-three')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('principle.gospel-three')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('quote.203')), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('principles: Traditional and English render', (tester) async {
    await mount(tester, const StudyPrinciplesPage(loader: _file),
        locale: 'zh-Hant');
    expect(find.text('講道自己說出來的原則'), findsOneWidget);
    await mount(tester, const StudyPrinciplesPage(loader: _file), locale: 'en');
    expect(find.text('Principles the sermons name'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
