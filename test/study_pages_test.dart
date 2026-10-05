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
import 'package:yahwehs_words/services/fetch_books.dart' show standardBookOrder;
import 'package:yahwehs_words/services/sermon_service.dart';
import 'package:yahwehs_words/utils/reference_parser.dart';
import 'package:yahwehs_words/utils/route_paths.dart';

/// The two hidden research pages (圣经原则 / 神的应许). They have no link
/// anywhere; these tests guard the DATA (every reference resolves, every verse
/// text is present in all three editions, every linked sermon exists, no
/// principle the app already had was lost) and the layout at phone width.
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
    late StudyPromises promises;
    late StudyPrinciples principles;
    late Set<String> sermonIds;
    setUpAll(() async {
      promises = await StudyData.loadPromises(loader: _file);
      principles = await StudyData.loadPrinciples(loader: _file);
      final idx = jsonDecode(File('assets/sermons/index.json').readAsStringSync())
          as List;
      sermonIds = {for (final s in idx) (s as Map)['id'] as String};
    });

    test('linked teachings: Beatitudes, fruit of the Spirit and Lord\'s Prayer', () {
      final link = principles.principles.where((p) => p.cat == 'link').toList();
      expect(link.map((p) => p.id), containsAll(['beatitudes-fruit', 'beatitudes-lords-prayer', 'daily-one-element']));
      final fruit = link.firstWhere((p) => p.id == 'beatitudes-fruit');
      expect(fruit.sermons.map((s) => s.id), contains('016'));
      expect(fruit.verses, containsAll(['Matthew 5:3-12', 'Galatians 5:22-23']));
    });
    test('sizes: 190+ principles in 13 groups, 220+ promises in 10 groups', () {
      expect(principles.principles.length, greaterThanOrEqualTo(190));
      expect(principles.categories, hasLength(13));
      expect(promises.promises.length, greaterThanOrEqualTo(220));
      expect(promises.groups, hasLength(10));
      final ids = principles.principles.map((p) => p.id).toList();
      expect(ids.toSet().length, ids.length, reason: 'duplicate principle id');
      final pids = promises.promises.map((p) => p.id).toList();
      expect(pids.toSet().length, pids.length, reason: 'duplicate promise id');
    });

    test('statuses, conditions, groups and categories are all known', () {
      for (final p in promises.promises) {
        expect(promises.status.keys, contains(p.status), reason: p.id);
        expect(promises.conds.keys, contains(p.cond), reason: p.id);
        expect(promises.groups.map((g) => g.$1), contains(p.group));
      }
      for (final p in principles.principles) {
        expect(principles.categories.map((c) => c.$1), contains(p.cat),
            reason: p.id);
      }
    });

    test('every reference parses to a real chapter', () {
      final refs = <String>{
        for (final p in promises.promises) ...p.refs,
        for (final p in promises.promises) ...p.fulfilRefs,
        for (final p in principles.principles) ...p.verses,
        for (final p in principles.principles)
          for (final v in p.verseBlocks) v.ref,
      };
      expect(refs.length, greaterThan(400));
      for (final r in refs) {
        expect(parseReference(r), isNotNull, reason: r);
      }
    });

    test('every verse block has text in all three editions', () {
      var blocks = 0;
      var differs = 0;
      final all = [
        for (final p in principles.principles) ...p.verseBlocks,
        for (final p in promises.promises) ...p.verseBlocks,
      ];
      for (final v in all) {
        blocks++;
        expect(v.text.of('zh-Hans'), isNotEmpty, reason: v.ref);
        expect(v.text.of('zh-Hant'), isNotEmpty, reason: v.ref);
        expect(v.text.of('en'), isNotEmpty, reason: v.ref);
        if (v.text.of('zh-Hant') != v.text.of('zh-Hans')) differs++;
      }
      expect(blocks, greaterThan(300));
      expect(differs, greaterThan(blocks * 0.9));
    });

    test('every verse of the app Bible that uses the word 应许 is covered', () {
      // Verses where the word is a HUMAN promise (not God's) are listed on
      // purpose; everything else must be cited by some promise entry.
      const human = {
        '005023023', // Deut 23:23 a vow
        '011001024', // 1 Kgs 1:24 Adonijah
        '015010019', // Ezra 10:19
        '016005012', // Neh 5:12
        '016005013', // Neh 5:13
        '017004007', // Esth 4:7 Haman
        '040014007', // Matt 14:7 Herod
        '041014011', // Mark 14:11 Judas' pay
        '047009005', // 2 Cor 9:5 the collection
        '061002019', // 2 Pet 2:19 false teachers
      };
      final covered = <String>{};
      for (final p in promises.promises) {
        for (final r in [...p.refs, ...p.fulfilRefs]) {
          final m = RegExp(r'^(.+?)\s+(\d+):(\d+)(?:-(\d+))?$').firstMatch(r);
          if (m == null) continue;
          final b = standardBookOrder.indexOf(m.group(1)!) + 1;
          final ch = int.parse(m.group(2)!);
          final a = int.parse(m.group(3)!);
          final z = int.parse(m.group(4) ?? m.group(3)!);
          for (var v = a; v <= z; v++) {
            covered.add(
                '${b.toString().padLeft(3, '0')}${ch.toString().padLeft(3, '0')}${v.toString().padLeft(3, '0')}');
          }
        }
      }
      final bible = jsonDecode(File('assets/cuvs-yhwh.json').readAsStringSync())
          as List;
      var withWord = 0;
      final missing = <String>[];
      for (final v in bible) {
        final text = ((v as Map)['text'] as String)
            .replaceAll(RegExp(r'<note:[^>]*>'), '');
        if (!text.contains('应许')) continue;
        withWord++;
        final id = v['id'] as String;
        if (!covered.contains(id) && !human.contains(id)) missing.add(id);
      }
      expect(withWord, greaterThan(190));
      expect(missing, isEmpty);
    });

    test('every linked sermon exists', () {
      final linked = <String>{
        for (final p in principles.principles)
          for (final s in p.sermons) s.id,
        for (final p in promises.promises)
          for (final s in p.sermons) s.id,
      };
      expect(linked.length, greaterThan(100));
      for (final id in linked) {
        expect(sermonIds, contains(id));
      }
    });

    test('no principle the app already carries was lost', () {
      final old = jsonDecode(
              File('assets/bible_principles.json').readAsStringSync())
          as Map<String, dynamic>;
      final linked = <String>{
        for (final p in principles.principles)
          for (final s in p.sermons) s.id,
      };
      for (final p in (old['principles'] as List).cast<Map>()) {
        for (final sid in (p['sermonIds'] as List).cast<String>()) {
          expect(linked, contains(sid), reason: '${p['id']} / sermon $sid');
        }
      }
      expect(
          principles.principles
              .any((p) => p.title.of('zh-Hans').contains('转脸原则')),
          isTrue);
    });

    test('contested items carry an opened source with an https URL', () {
      for (final id in [
        'measure',
        'turn-cheek',
        'honesty',
        'tithe-belongs',
        'assurance-holiness',
        'watch-prepare'
      ]) {
        final p = principles.principles.firstWhere((x) => x.id == id);
        expect(p.sources, isNotEmpty, reason: id);
      }
      for (final p in [...principles.principles]) {
        for (final s in p.sources) {
          expect(s.url, startsWith('https://'));
        }
      }
      for (final p in promises.promises) {
        for (final s in p.sources) {
          expect(s.url, startsWith('https://'));
        }
      }
    });

    test('history notes always name a source', () {
      for (final p in promises.promises) {
        if (p.history != null && p.sources.isEmpty) {
          expect(
              p.history!.of('zh-Hans'),
              anyOf(contains('无法'), contains('没有核查'), contains('没有成真'),
                  contains('按多数解释')),
              reason: p.id);
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

  Future<void> openCard(WidgetTester tester, String key) async {
    final scrollable = find
        .descendant(
            of: find.byType(ListView).first,
            matching: find.byType(Scrollable))
        .first;
    await tester.scrollUntilVisible(find.byKey(ValueKey(key)), 300,
        scrollable: scrollable);
    await tester.ensureVisible(find.byKey(ValueKey(key)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey(key)), warnIfMissed: false);
    await tester.pumpAndSettle();
  }

  for (final width in [320.0, 402.0, 1024.0]) {
    testWidgets('promises page lays out at $width with 1.6x text',
        (tester) async {
      await mount(tester, const StudyPromisesPage(loader: _file),
          width: width, scale: 1.6);
      expect(find.text('神有很多应许'), findsOneWidget);
      await openCard(tester, 'promise.abraham-land');
      expect(find.text('应验与现状'), findsWidgets);
      expect(find.byKey(const ValueKey('verse.Genesis 15:17-18')), findsWidgets);
      expect(tester.takeException(), isNull);
    });
    testWidgets('principles page lays out at $width with 1.6x text',
        (tester) async {
      await mount(tester, const StudyPrinciplesPage(loader: _file),
          width: width, scale: 1.6);
      expect(find.text('圣经里的原则'), findsOneWidget);
      await openCard(tester, 'principle.turn-cheek');
      expect(find.text('圣经怎么说'), findsWidgets);
      expect(find.byKey(const ValueKey('verse.Matthew 5:38-39')), findsWidgets);
      expect(find.byKey(const ValueKey('sermon.fy-sm17')), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('promises: filtering by status narrows the list', (tester) async {
    final d = await StudyData.loadPromises(loader: _file);
    final total = d.promises.length;
    final notYet = d.promises.where((p) => p.status == '✘').length;
    await mount(tester, const StudyPromisesPage(loader: _file));
    expect(find.textContaining('显示 $total / $total'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('status.✘')));
    await tester.pump();
    expect(find.textContaining('显示 $notYet / $total'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('status.✘')));
    await tester.pump();
    expect(find.textContaining('显示 $total / $total'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('study.search')), '洪水');
    await tester.pump();
    expect(find.byKey(const ValueKey('promise.noah-flood')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('promises: filter by book and chapter', (tester) async {
    final d = await StudyData.loadPromises(loader: _file);
    final total = d.promises.length;
    final inIsaiah =
        d.promises.where((p) => p.chapters.any((e) => e.$1 == 'Isaiah')).length;
    expect(inIsaiah, greaterThan(5));
    expect(inIsaiah, lessThan(total));
    await mount(tester, const StudyPromisesPage(loader: _file));
    // The menu is long and lazily built; drive the dropdown through its callback.
    tester
        .widget<DropdownButtonFormField<String?>>(
            find.byKey(const ValueKey('study.book')))
        .onChanged!('Isaiah');
    await tester.pumpAndSettle();
    expect(find.textContaining('显示 $inIsaiah / $total'), findsOneWidget);
    // chapter menu is now offered
    expect(find.byKey(const ValueKey('study.chapter')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('principles: filter by book', (tester) async {
    final d = await StudyData.loadPrinciples(loader: _file);
    final total = d.principles.length;
    final inRomans =
        d.principles.where((p) => p.chapters.any((e) => e.$1 == 'Romans')).length;
    expect(inRomans, greaterThan(5));
    await mount(tester, const StudyPrinciplesPage(loader: _file));
    // The menu is long and lazily built; drive the dropdown through its callback.
    tester
        .widget<DropdownButtonFormField<String?>>(
            find.byKey(const ValueKey('study.book')))
        .onChanged!('Romans');
    await tester.pumpAndSettle();
    expect(find.textContaining('显示 $inRomans / $total'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('promises: two tabs, no sermon-comparison tab', (tester) async {
    await mount(tester, const StudyPromisesPage(loader: _file));
    expect(find.text('讲道对照'), findsNothing);
    expect(find.text('应许目录'), findsOneWidget);
    expect(find.text('说明'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('principles: category filter and search', (tester) async {
    final d = await StudyData.loadPrinciples(loader: _file);
    final total = d.principles.length;
    final gospel = d.principles.where((p) => p.cat == 'gospel').length;
    await mount(tester, const StudyPrinciplesPage(loader: _file));
    expect(find.textContaining('显示 $total / $total'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('study.search')), '转脸');
    await tester.pump();
    expect(find.byKey(const ValueKey('principle.turn-cheek')), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('study.search')), '');
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey('cat.gospel')));
    await tester.tap(find.byKey(const ValueKey('cat.gospel')));
    await tester.pump();
    expect(find.textContaining('显示 $gospel / $total'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('principles: Traditional and English render', (tester) async {
    await mount(tester, const StudyPrinciplesPage(loader: _file),
        locale: 'zh-Hant');
    expect(find.text('聖經裡的原則'), findsOneWidget);
    await mount(tester, const StudyPrinciplesPage(loader: _file), locale: 'en');
    expect(find.text('Principles of the Bible'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
