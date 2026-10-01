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
import 'package:yahwehs_words/models/learning_data.dart';
import 'package:yahwehs_words/pages/passion_wheel_page.dart';
import 'package:yahwehs_words/pages/bible_principles_page.dart';
import 'package:yahwehs_words/services/sermon_service.dart';
import 'package:yahwehs_words/utils/reference_parser.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;
  setUpAll(() {
    LearningData.setTestLoader((path) async => File(path).readAsStringSync());
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
      final name = utf8.decode(message!.buffer
          .asUint8List(message.offsetInBytes, message.lengthInBytes));
      if (name == 'AssetManifest.bin') {
        return const StandardMessageCodec().encodeMessage(<String, Object?>{});
      }
      final file = File(name);
      if (!file.existsSync()) return null;
      final bytes = file.readAsBytesSync();
      return ByteData.sublistView(bytes);
    });
  });
  tearDownAll(() => LearningData.setTestLoader(null));
  final passionJson =
      jsonDecode(File('assets/passion_wheel.json').readAsStringSync())
          as Map<String, dynamic>;
  final events = (passionJson['events'] as List)
      .map((j) => PassionEvent.fromJson(j as Map<String, dynamic>))
      .toList();
  final principlesJson =
      jsonDecode(File('assets/bible_principles.json').readAsStringSync())
          as Map<String, dynamic>;
  test('all Gospel references resolve to existing canonical passages', () {
    final verses =
        jsonDecode(File('assets/kjv.json').readAsStringSync()) as List;
    final keys = {
      for (final v in verses) '${v['book']} ${v['chapter']}:${v['verse']}'
    };
    expect(events.length, 20);
    expect(events.map((e) => e.id).toSet().length, events.length);
    for (final e in events) {
      expect(e.refs, isNotEmpty);
      for (final locale in ['en', 'zh-Hans', 'zh-Hant']) {
        expect(e.title[locale], isNotEmpty);
        expect(e.place[locale], isNotEmpty);
        expect(e.period[locale], isNotEmpty);
        expect(e.summary[locale], isNotEmpty);
      }
      for (final r in {...e.refs, ...e.diagramRefs}) {
        final ref = parseReference(r);
        expect(ref, isNotNull, reason: r);
        for (var v = ref!.verseStart!; v <= ref.verseEnd!; v++) {
          expect(keys, contains('${ref.englishBook} ${ref.chapter}:$v'),
              reason: r);
        }
      }
    }
  });
  test('untimed scenes never acquire invented clock positions', () {
    expect(events.where((e) => e.clockHour != null).map((e) => e.id),
        ['cross', 'darkness', 'death']);
    expect(events.firstWhere((e) => e.id == 'sentence').clockHour, isNull);
    expect(events.firstWhere((e) => e.id == 'peter').clockHour, isNull);
  });
  test('Gospel filters do not borrow another Gospel’s clock', () {
    expect(events.firstWhere((e) => e.id == 'cross').hourFor('John'), isNull);
    expect(
        events.firstWhere((e) => e.id == 'cross').hourFor('Matthew'), isNull);
    expect(events.firstWhere((e) => e.id == 'cross').hourFor('Mark'), 9);
    expect(events.firstWhere((e) => e.id == 'death').hourFor('Luke'), isNull);
    expect(
        events.where((e) => e.hasGospel('John')).every(
            (e) => e.refsFor('John').every((r) => r.startsWith('John '))),
        isTrue);
  });
  test('day and night clocks use distinct rings with shared angles', () {
    expect(passionClockAngle(0), passionClockAngle(12));
    expect(passionClockDay(0), isFalse);
    expect(passionClockDay(12), isTrue);
    expect(passionClockAngle(9), closeTo(math.pi, 1e-12));
    expect(passionClockDay(6), isTrue);
    expect(passionClockDay(18), isFalse);
  });
  test('reference diagram estimates are separate from Scripture hours', () {
    final expected = {
      'supper': 20,
      'garden': 0,
      'arrest': 1,
      'annas': 2,
      'caiaphas': 3,
      'council': 5,
      'pilate': 6,
      'herod': 7,
      'sentence': 8,
      'mockery': 8,
      'cross': 9,
      'darkness': 12,
      'death': 15,
      'burial': 17
    };
    expect({
      for (final e in events.where((e) => e.diagramHour != null))
        e.id: e.diagramHour
    }, expected);
    expect(events.firstWhere((e) => e.id == 'garden').clockHour, isNull);
    expect(events.firstWhere((e) => e.id == 'burial').clockHour, isNull);
    expect(events.firstWhere((e) => e.id == 'supper').refsFor('John'),
        contains('John 13:21-30'));
  });
  test('attached diagram bytes match the original source checksum', () {
    final meta = passionJson['_meta']['referenceDiagram'];
    expect(meta['asset'], kPassionReferenceImage);
    expect(
        sha256
            .convert(File(kPassionReferenceImage).readAsBytesSync())
            .toString(),
        meta['sha256']);
    expect(meta['sha256'],
        '80df6472ead28e4a85fb78b5df860ceecd046f7a6adb801d6ddf0c073c682804');
  });
  test(
      'every editorial principle has a literal source anchor and unchanged source hash',
      () {
    final index =
        jsonDecode(File('assets/sermons/index.json').readAsStringSync())
            as List;
    final ids = {for (final s in index) s['id']};
    final records = principlesJson['principles'] as List;
    expect(records.length, 18);
    expect(records.map((e) => e['id']).toSet().length, records.length);
    for (final p in records) {
      for (final id in p['sermonIds'] as List) {
        expect(ids, contains(id));
      }
      for (final anchor in p['sourceAnchors'] as List) {
        final bytes =
            File('assets/sermons/${anchor['locale']}/${anchor['sermonId']}.txt')
                .readAsBytesSync();
        expect(utf8.decode(bytes), contains(anchor['text']));
        expect(sha256.convert(bytes).toString(), anchor['sha256']);
      }
    }
  });
  test('principle searches include title, explanation and source number', () {
    final p = BiblePrinciple.fromJson(
        (principlesJson['principles'] as List).first as Map<String, dynamic>);
    expect(p.matches('转脸', 'zh-Hans'), isTrue);
    expect(p.matches('010', 'en'), isTrue);
    expect(p.matches('nothing-matches-this', 'en'), isFalse);
  });
  Future<void> mount(WidgetTester tester, Widget page,
      {double width = 402, double scale = 1, String locale = 'en'}) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = Size(width, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final settings = AppSettings();
    await settings.setLocale(locale);
    await tester.runAsync(() async {
      await SermonService.instance.loadIndex();
      await SermonService.instance.loadRefs();
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
    testWidgets('Passion wheel is usable at $width with 1.8x text',
        (tester) async {
      await mount(tester, const PassionWheelPage(), width: width, scale: 1.8);
      await tester.scrollUntilVisible(
          find.byKey(const ValueKey('passion.marker.cross')), 100);
      expect(
          find.byKey(const ValueKey('passion.marker.cross')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester
          .ensureVisible(find.byKey(const ValueKey('passion.marker.darkness')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('passion.marker.darkness')));
      await tester.pump();
      await tester.scrollUntilVisible(
          find.byKey(const ValueKey('passion.selected.title')), 100);
      expect(
          tester
              .widget<Text>(
                  find.byKey(const ValueKey('passion.selected.title')))
              .data,
          'Darkness over the land');
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('midnight, estimates and overlapping scenes remain interactive',
      (tester) async {
    await mount(tester, const PassionWheelPage(), width: 320, scale: 1.8);
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('passion.marker.garden')).hitTestable(), 100);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('passion.marker.garden')));
    await tester.pump();
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('passion.selected.diagram-time')), 100);
    expect(
        tester
            .widget<Text>(
                find.byKey(const ValueKey('passion.selected.diagram-time')))
            .data,
        'Reference diagram: ≈ 00:00');
    await tester
        .ensureVisible(find.byKey(const ValueKey('passion.marker.sentence')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('passion.marker.sentence')));
    await tester.pump();
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('passion.detail.mockery.title')), 100);
    expect(find.byKey(const ValueKey('passion.detail.mockery.title')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('hour selector covers empty hours and follows wheel selection',
      (tester) async {
    await mount(tester, const PassionWheelPage(), width: 320);
    final selector = find.byType(DropdownButtonFormField<int>);
    await tester.scrollUntilVisible(selector.hitTestable(), 100);
    await tester.pumpAndSettle();
    await tester.tap(selector);
    await tester.pumpAndSettle();
    await tester.tap(find.text('10:00').last);
    await tester.pumpAndSettle();
    expect(tester.state<FormFieldState<int>>(selector).value, 10);
    final darkness = find.byKey(const ValueKey('passion.marker.darkness'));
    await tester.ensureVisible(darkness);
    await tester.pumpAndSettle();
    await tester.tap(darkness);
    await tester.pumpAndSettle();
    expect(tester.state<FormFieldState<int>>(selector).value, 12);
    expect(tester.takeException(), isNull);
  });
  testWidgets('former adjacent rectangular corners do not select wrong hours',
      (tester) async {
    await mount(tester, const PassionWheelPage(), width: 320);
    final one = find.byKey(const ValueKey('passion.marker.arrest'));
    final two = find.byKey(const ValueKey('passion.marker.annas'));
    await tester.scrollUntilVisible(one.hitTestable(), 100);
    await tester.pumpAndSettle();
    final midpoint = (tester.getCenter(one) + tester.getCenter(two)) / 2;
    expect(tester.getRect(one).contains(midpoint), isTrue);
    expect(tester.getRect(two).contains(midpoint), isTrue);
    await tester.tapAt(midpoint);
    await tester.pumpAndSettle();
    expect(
        tester
            .state<FormFieldState<int>>(
                find.byType(DropdownButtonFormField<int>))
            .value,
        9);
    expect(tester.takeException(), isNull);
  });
  testWidgets('unassigned clock hours do not invent an event', (tester) async {
    await mount(tester, const PassionWheelPage());
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('passion.hour.4')).hitTestable(), 100);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('passion.hour.4')));
    await tester.pump();
    await tester.scrollUntilVisible(
        find.text(
            '04:00 · No scene is assigned to this hour in the selected view.'),
        100);
    expect(find.byKey(const ValueKey('passion.selected.title')), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('original diagram opens in a zoomable attachment viewer',
      (tester) async {
    await mount(tester, const PassionWheelPage(), width: 320, scale: 1.8);
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('passion.attachment.open')).hitTestable(),
        100);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('passion.attachment.open')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('passion.attachment.viewer')),
        findsOneWidget);
    expect(
        find.byWidgetPredicate((w) =>
            w is Image &&
            w.image is AssetImage &&
            (w.image as AssetImage).assetName == kPassionReferenceImage),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('John filter offers no borrowed hour markers', (tester) async {
    await mount(tester, const PassionWheelPage());
    await tester.tap(find.byKey(const ValueKey('passion.mode.gospel')));
    await tester.pump();
    await tester.tap(find.widgetWithText(ChoiceChip, 'John'));
    await tester.pump();
    expect(find.byKey(const ValueKey('passion.marker.cross')), findsNothing);
    expect(find.byKey(const ValueKey('passion.marker.death')), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('principles expand to real sermon links and cited passages',
      (tester) async {
    await mount(tester, const BiblePrinciplesPage(),
        width: 320, scale: 1.8, locale: 'zh-Hans');
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('principle.turn-other-cheek')), 120,
        scrollable: find
            .descendant(
                of: find.byType(ListView), matching: find.byType(Scrollable))
            .first);
    await tester.tap(find.byKey(const ValueKey('principle.turn-other-cheek')));
    await tester.pumpAndSettle();
    expect(find.text('出处讲道'), findsOneWidget);
    expect(find.text('本讲道引用的经文'), findsOneWidget);
    expect(find.byType(ActionChip), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
