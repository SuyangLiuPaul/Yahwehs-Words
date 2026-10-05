import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahwehs_words/models/app_settings.dart';
import 'package:yahwehs_words/models/study_data.dart';
import 'package:yahwehs_words/pages/study_testaments_page.dart';
import 'package:yahwehs_words/services/sermon_service.dart';
import 'package:yahwehs_words/utils/reference_parser.dart';
import 'package:yahwehs_words/utils/route_paths.dart';

/// The hidden New Testament ↔ Old Testament page. Guards the DATA (known
/// correspondences are present, every reference resolves, every verse text is
/// there in all three editions) and the layout at phone width.
Future<String> _file(String path) async => File(path).readAsStringSync();

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
    late StudyTestaments d;
    setUpAll(() async {
      d = await StudyData.loadTestaments(loader: _file);
    });

    test('sizes', () {
      expect(d.entries.length, greaterThanOrEqualTo(400));
      expect(d.typology.length, greaterThanOrEqualTo(20));
      expect(d.related.length, greaterThanOrEqualTo(2000));
      final ids = d.entries.map((e) => e.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('well-known correspondences are present', () {
      bool has(String nt, String ot) => d.entries.any((e) =>
          e.nt.startsWith(nt) && e.ot.any((o) => o.ref.startsWith(ot)));
      expect(has('Matthew 1:23', 'Isaiah 7:14'), isTrue);
      expect(has('Matthew 4:4', 'Deuteronomy 8:3'), isTrue);
      expect(has('Matthew 2:15', 'Hosea 11:1'), isTrue);
      expect(has('Romans 3:10', 'Psalms 14:1'), isTrue);
      expect(has('Romans 4:3', 'Genesis 15:6'), isTrue);
      expect(has('Hebrews 1:5', 'Psalms 2:7'), isTrue);
      expect(has('Galatians 3:11', 'Habakkuk 2:4'), isTrue);
      expect(has('Acts 2:21', 'Joel 2:28'), isTrue);
      expect(has('John 19:37', 'Zechariah 12:10'), isTrue);
    });

    test('every reference parses and every verse block has text', () {
      for (final e in d.entries) {
        expect(parseReference(e.nt), isNotNull, reason: e.nt);
        expect(e.ot, isNotEmpty, reason: e.id);
        for (final t in [e.ntBlock, ...e.ot.map((o) => o.block)]) {
          expect(parseReference(t.ref), isNotNull, reason: t.ref);
          for (final l in ['zh-Hans', 'zh-Hant', 'en']) {
            expect(t.text.of(l), isNotEmpty, reason: '${t.ref} $l');
          }
        }
        for (final o in e.ot) {
          expect(['quote', 'paraphrase', 'allusion'], contains(o.type));
          expect(o.srcs, isNotEmpty);
        }
        // the New Testament side is a New Testament book, the other side Old
        final ntBook = studyParseRef(e.nt)!.book;
        for (final o in e.ot) {
          expect(studyParseRef(o.ref)!.book, isNot(ntBook), reason: e.id);
        }
      }
      for (final t in d.typology) {
        for (final r in [...t.ot, ...t.nt]) {
          expect(parseReference(r), isNotNull, reason: '${t.id} $r');
        }
        expect(t.says.of('zh-Hans'), isNotEmpty);
        expect(t.word.of('zh-Hans'), isNotEmpty);
        expect(t.otBlocks, isNotEmpty);
        expect(t.ntBlocks, isNotEmpty);
      }
      for (final r in d.related) {
        expect(parseReference(r.nt), isNotNull, reason: r.nt);
        for (final o in r.ot) {
          expect(parseReference(o), isNotNull, reason: o);
        }
      }
    });

    test('the page is registered and linked from nowhere', () {
      expect(kRegisteredRoutePaths, contains('/study/testaments'));
      for (final f in Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        final defines = f.path.endsWith('study_testaments_page.dart') ||
            f.path.endsWith('route_paths.dart') ||
            f.path.endsWith('main.dart');
        if (defines) continue;
        final src = f.readAsStringSync();
        expect(src, isNot(contains('StudyTestamentsPage')), reason: f.path);
        expect(src, isNot(contains('kStudyTestamentsPath')), reason: f.path);
      }
    });
  });

  Future<void> mount(WidgetTester tester,
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
            home: const StudyTestamentsPage(loader: _file))));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  for (final width in [320.0, 402.0, 1024.0]) {
    testWidgets('lays out at $width with 1.6x text', (tester) async {
      await mount(tester, width: width, scale: 1.6);
      expect(find.text('新约与旧约的对应'), findsOneWidget);
      final key = const ValueKey('ct.nt040001023');
      final scrollable = find
          .descendant(
              of: find.byType(ListView).first,
              matching: find.byType(Scrollable))
          .first;
      await tester.scrollUntilVisible(find.byKey(key), 300,
          scrollable: scrollable);
      await tester.ensureVisible(find.byKey(key));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(key), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('verse.Isaiah 7:14')), findsWidgets);
      expect(find.byKey(const ValueKey('verse.Matthew 1:23')), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('filters by New Testament book, Old Testament book and type',
      (tester) async {
    final d = await StudyData.loadTestaments(loader: _file);
    final total = d.entries.length;
    final inRomans = d.entries
        .where((e) => e.ntChapters.any((c) => c.$1 == 'Romans'))
        .length;
    final fromIsaiah = d.entries
        .where((e) => e.otChapters.any((c) => c.$1 == 'Isaiah'))
        .length;
    expect(inRomans, greaterThan(30));
    expect(fromIsaiah, greaterThan(30));
    await mount(tester);
    expect(find.textContaining('显示 $total / $total'), findsOneWidget);
    tester
        .widget<DropdownButtonFormField<String?>>(
            find.byKey(const ValueKey('nt.book')))
        .onChanged!('Romans');
    await tester.pumpAndSettle();
    expect(find.textContaining('显示 $inRomans / $total'), findsOneWidget);
    tester
        .widget<DropdownButtonFormField<String?>>(
            find.byKey(const ValueKey('nt.book')))
        .onChanged!(null);
    await tester.pumpAndSettle();
    tester
        .widget<DropdownButtonFormField<String?>>(
            find.byKey(const ValueKey('ot.book')))
        .onChanged!('Isaiah');
    await tester.pumpAndSettle();
    expect(find.textContaining('显示 $fromIsaiah / $total'), findsOneWidget);
    // sort by Old Testament: the Isaiah group heads the list
    await tester.ensureVisible(find.byKey(const ValueKey('sort.ot')));
    await tester.tap(find.byKey(const ValueKey('sort.ot')));
    await tester.pumpAndSettle();
    expect(find.textContaining('以赛亚书 ·'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the types tab shows the typology entries', (tester) async {
    await mount(tester);
    await tester.tap(find.text('预表'));
    await tester.pumpAndSettle();
    expect(find.text('新约自己指明的预表'), findsOneWidget);
    expect(find.byKey(const ValueKey('typology.adam-christ')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the related tab lists cross-references and filters',
      (tester) async {
    final d = await StudyData.loadTestaments(loader: _file);
    await mount(tester);
    await tester.tap(find.text('相关经文'));
    await tester.pumpAndSettle();
    expect(find.text('更多相关经文'), findsOneWidget);
    expect(find.textContaining('显示 ${d.related.length} / ${d.related.length}'),
        findsOneWidget);
    tester
        .widget<DropdownButtonFormField<String?>>(
            find.byKey(const ValueKey('rnt.book')))
        .onChanged!('Hebrews');
    await tester.pumpAndSettle();
    final inHeb = d.related
        .where((r) => r.nt.startsWith('Hebrews '))
        .length;
    expect(inHeb, greaterThan(20));
    expect(find.textContaining('显示 $inHeb / ${d.related.length}'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Traditional and English render', (tester) async {
    await mount(tester, locale: 'zh-Hant');
    expect(find.text('新約與舊約的對應'), findsOneWidget);
    await mount(tester, locale: 'en');
    expect(find.text('New Testament ↔ Old Testament'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
