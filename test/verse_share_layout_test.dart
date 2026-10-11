import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahwehs_words/models/app_settings.dart';
import 'package:yahwehs_words/models/verse_share_layout.dart';
import 'package:yahwehs_words/widgets/verse_card.dart';
import 'package:yahwehs_words/widgets/verse_card_sheet.dart';
import 'package:yahwehs_words/services/verse_card_service.dart';
import 'package:yahwehs_words/constants/text_patterns.dart';
import 'package:yahwehs_words/constants/bible_versions.dart';
import 'package:yahwehs_words/widgets/verse_share_layout_controls.dart';

void main() {
  test('invalid stored options are bounded and cannot rename a translation',
      () {
    final value = VerseShareLayout.fromJson({
      'position': 'invalid',
      'fontScale': double.nan,
      'padding': 999,
      'lineHeight': -5,
      'versionLabel': 'False name'
    });
    expect(value.position, VerseSharePosition.center);
    expect(value.fontScale, 1);
    expect(value.padding, 40);
    expect(value.lineHeight, 1.2);
    expect(value.toJson().containsKey('versionLabel'), isFalse);
  });
  test('layout persists, reloads and restores defaults', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettings();
    await settings.setVerseShareLayout(const VerseShareLayout(
        position: VerseSharePosition.bottom,
        alignment: VerseShareAlignment.center,
        fontScale: 1.3,
        padding: 20,
        showVersion: false));
    final next = AppSettings();
    await next.loadSettings();
    expect(next.verseShareLayout.toJson(), settings.verseShareLayout.toJson());
    await next.setVerseShareLayout(const VerseShareLayout());
    final reloaded = AppSettings();
    await reloaded.loadSettings();
    expect(
        reloaded.verseShareLayout.toJson(), const VerseShareLayout().toJson());
    settings.dispose();
    next.dispose();
    reloaded.dispose();
  });
  testWidgets('short passage follows top middle bottom without hiding credits',
      (tester) async {
    final centres = <double>[];
    for (final position in VerseSharePosition.values) {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: Center(
                  child: VerseCard(
                      reference: 'John 11:35',
                      body: 'Jesus wept.',
                      versionLabel: 'KJV',
                      appName: 'Words',
                      licence: 'Required source credit',
                      scheme: ColorScheme.fromSeed(seedColor: Colors.blue),
                      layout: VerseShareLayout(
                          position: position,
                          showReference: false,
                          showVersion: false))))));
      await tester.pumpAndSettle();
      expect(find.text('John 11:35'), findsNothing);
      expect(find.text('KJV'), findsNothing);
      expect(find.text('Required source credit'), findsOneWidget);
      centres.add(tester.getCenter(find.text('Jesus wept.')).dy);
      expect(tester.takeException(), isNull);
    }
    expect(centres[0], lessThan(centres[1]));
    expect(centres[1], lessThan(centres[2]));
  });
  testWidgets(
      'same renderer exports all alignments, CJK, photos and long passages',
      (tester) async {
    await (FontLoader('Roboto')
          ..addFont(rootBundle
              .load('assets/fonts/Roboto-VariableFont_wdth,wght.ttf')))
        .load();
    await (FontLoader('NotoSansSC-YahwehsWords')
          ..addFont(
              rootBundle.load('assets/fonts/NotoSansSC-YahwehsWords.otf')))
        .load();
    const proof = String.fromEnvironment('UI_PROOF_DIR');
    final imageBytes = await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawColor(Colors.blue, BlendMode.src);
      final image = await recorder.endRecording().toImage(30, 20);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return bytes!.buffer.asUint8List();
    });
    for (final alignment in VerseShareAlignment.values) {
      for (final body in [
        'Jesus wept.',
        '我们将这些话写给你们，使你们的喜乐充足。',
        List.filled(20, 'Blessed are the peacemakers.').join(' ')
      ]) {
        final key = GlobalKey();
        await tester.pumpWidget(MaterialApp(
            home: Scaffold(
                body: SingleChildScrollView(
                    child: Center(
                        child: RepaintBoundary(
                            key: key,
                            child: VerseCard(
                                reference: body.startsWith('我们')
                                    ? '约翰一书 1:4'
                                    : 'John 11:35',
                                body: body,
                                versionLabel:
                                    body.startsWith('我们') ? '和合本雅伟版' : 'KJV',
                                licence: body.startsWith('我们')
                                    ? '和合本雅伟版 · 来源保留'
                                    : 'KJV · Public domain',
                                appName: 'Words',
                                fontFamily: 'Roboto',
                                scheme: ColorScheme.fromSeed(
                                    seedColor: Colors.blue),
                                style: VerseCardStyle.photo,
                                photo: MemoryImage(imageBytes!),
                                layout: VerseShareLayout(
                                    alignment: alignment,
                                    fontScale: 1.4,
                                    lineHeight: 2,
                                    padding: 40))))))));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
            tester.widget<Text>(find.text(body)).textAlign,
            switch (alignment) {
              VerseShareAlignment.left => TextAlign.left,
              VerseShareAlignment.center => TextAlign.center,
              VerseShareAlignment.right => TextAlign.right
            });
        final boundary =
            key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          expect(image.width, 720);
          expect(data!.lengthInBytes, greaterThan(0));
          if (proof.isNotEmpty && body.startsWith('我们')) {
            await File('$proof/share-${alignment.name}.png')
                .writeAsBytes(data.buffer.asUint8List());
          }
          image.dispose();
        });
      }
    }
  });
  testWidgets(
      'controls fit phone and landscape with large English and Chinese text',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    for (final locale in ['en', 'zh-Hans']) {
      final settings = AppSettings();
      await tester.runAsync(() => settings.setLocale(locale));
      for (final size in [const Size(320, 900), const Size(900, 400)]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(ChangeNotifierProvider.value(
            value: settings,
            child: MaterialApp(
                home: Scaffold(
                    body: MediaQuery(
                        data: const MediaQueryData(
                            textScaler: TextScaler.linear(1.5)),
                        child: const SingleChildScrollView(
                            child: VerseShareLayoutControls()))))));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
      settings.dispose();
    }
    await tester.pump(const Duration(seconds: 2));
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  testWidgets(
      'production share sheet preserves actual translation and credit in export',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettings();
    await tester.runAsync(() => settings.setLocale('zh-Hans'));
    final corpus = await tester.runAsync(() async =>
        jsonDecode(await rootBundle.loadString('assets/cuvs-yhwh.json'))
            as List);
    final verse = corpus!.cast<Map>().firstWhere((v) => v['id'] == '062001004');
    final body = sanitizeForCopy(verse['text'] as String,
        stripParentheticals: settings.copyStripParentheticals);
    final label = shortBibleVersionLabel('cuvs-yhwh');
    await tester.runAsync(() => settings.setFontFamily('Roboto'));
    final reference = '${verse['book']} 1:4';
    // Each export test loads the production fonts itself, including when
    // selected alone with --plain-name.
    await (FontLoader('Roboto')
          ..addFont(rootBundle
              .load('assets/fonts/Roboto-VariableFont_wdth,wght.ttf')))
        .load();
    await (FontLoader('NotoSansSC-YahwehsWords')
          ..addFont(
              rootBundle.load('assets/fonts/NotoSansSC-YahwehsWords.otf')))
        .load();
    await (FontLoader('NotoSansExt-Sub')
          ..addFont(rootBundle.load('assets/fonts/NotoSansExt-Sub.ttf')))
        .load();
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: settings,
        child: MaterialApp(
            home: Scaffold(
                body: VerseCardSheet(
                    reference: reference,
                    body: body,
                    version: 'cuvs-yhwh',
                    versionLabel: label,
                    shareText: body)))));
    await tester.pumpAndSettle();
    final card = tester.widget<VerseCard>(find.byType(VerseCard).first);
    expect(card.body, body);
    expect(card.reference, reference);
    expect(card.versionLabel, label);
    expect(card.licence, verseCardLicence('cuvs-yhwh', 'zh-Hans'));
    final finder = find
        .ancestor(
            of: find.byType(VerseCard).first,
            matching: find.byType(RepaintBoundary))
        .first;
    final boundary = tester.renderObject<RenderRepaintBoundary>(finder);
    await tester.runAsync(() async {
      final exported = await boundary.toImage(pixelRatio: 2);
      final png = await exported.toByteData(format: ui.ImageByteFormat.png);
      expect(png!.lengthInBytes, greaterThan(0));
      const proof = String.fromEnvironment('UI_PROOF_DIR');
      if (proof.isNotEmpty) {
        await File('$proof/share-production-cuvs.png')
            .writeAsBytes(png.buffer.asUint8List());
      }
      exported.dispose();
    });
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
    settings.dispose();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
