// The import flow and the Add-ons page, as a reader meets them.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahwehs_words/models/app_settings.dart';
import 'package:yahwehs_words/pages/addons_page.dart';
import 'package:yahwehs_words/providers/main_provider.dart';
import 'package:yahwehs_words/services/addons/addon_import_service.dart';
import 'package:yahwehs_words/services/addons/addon_registry.dart';
import 'package:yahwehs_words/services/addons/addon_store.dart';
import 'package:yahwehs_words/widgets/addon_import_sheet.dart';

Uint8List _fx(String name) =>
    Uint8List.fromList(File('test/fixtures/addons/$name').readAsBytesSync());

Future<AppSettings> _settings(String locale) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final s = AppSettings();
  await s.setLocale(locale);
  return s;
}

Widget _app(AppSettings settings, Widget home) => MultiProvider(
      providers: [
        ChangeNotifierProvider<AppSettings>.value(value: settings),
        ChangeNotifierProvider(create: (_) => MainProvider()),
      ],
      child: MaterialApp(home: home),
    );

/// A page with one button that opens the import sheet for [file].
Widget _sheetHost(AppSettings s, String name, Uint8List bytes,
    {void Function(AddonImportSheetResult?)? onResult}) {
  return _app(
    s,
    Builder(
      builder: (c) => Scaffold(
        body: TextButton(
          onPressed: () async {
            final r = await showAddonImportSheet(c,
                fileName: name, bytes: bytes, locale: s.locale);
            onResult?.call(r);
          },
          child: const Text('open'),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late InMemoryAddonBackend backend;
  setUp(() {
    backend = InMemoryAddonBackend();
    AddonStore.backend = backend;
    AddonRegistry.resetForTest();
  });
  tearDown(() {
    AddonStore.backend = null;
    AddonRegistry.resetForTest();
  });

  Future<void> openSheet(WidgetTester tester) async {
    // A tall surface: the sheet is a scrolling column and these tests tap
    // its lower controls.
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(800, 1600);
    addTearDown(tester.view.reset);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('Import stays disabled until the licence box is ticked', (tester) async {
    final s = await _settings('en');
    await tester.pumpWidget(_sheetHost(s, 'x.SQLite3', _fx('mybible_min.SQLite3')));
    await openSheet(tester);
    expect(find.byKey(const ValueKey('addon.stage.found')), findsOneWidget);

    FilledButton button() =>
        tester.widget<FilledButton>(find.byKey(const ValueKey('addon.import')));
    expect(button().onPressed, isNull, reason: 'not ticked: disabled');
    // The box is NOT pre-ticked.
    expect(tester.widget<CheckboxListTile>(find.byKey(const ValueKey('addon.attest'))).value,
        isFalse);

    await tester.tap(find.byKey(const ValueKey('addon.attest')));
    await tester.pump();
    expect(button().onPressed, isNotNull);

    // Untick again: disabled again.
    await tester.tap(find.byKey(const ValueKey('addon.attest')));
    await tester.pump();
    expect(button().onPressed, isNull);
  });

  testWidgets('an empty name or a taken name disables Import and says why', (tester) async {
    final s = await _settings('en');
    await tester.pumpWidget(_sheetHost(s, 'x.SQLite3', _fx('mybible_min.SQLite3')));
    await openSheet(tester);
    await tester.tap(find.byKey(const ValueKey('addon.attest')));
    await tester.enterText(find.byKey(const ValueKey('addon.name')), '   ');
    await tester.pump();
    expect(tester.widget<FilledButton>(find.byKey(const ValueKey('addon.import'))).onPressed,
        isNull);
    expect(find.text('Please give it a name.'), findsOneWidget);
  });

  testWidgets('what was found is stated, then imported, then reported', (tester) async {
    final s = await _settings('en');
    AddonImportSheetResult? result;
    await tester.pumpWidget(_sheetHost(s, 'x.SQLite3', _fx('mybible_min.SQLite3'),
        onResult: (r) => result = r));
    await openSheet(tester);
    expect(find.text('MyBible.zone · 8 verses · 3 books'), findsOneWidget);
    // Named from the module's own description.
    expect(tester.widget<TextField>(find.byKey(const ValueKey('addon.name'))).controller!.text,
        'Synthetic Test Bible');

    await tester.tap(find.byKey(const ValueKey('addon.attest')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('addon.import')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('addon.stage.done')), findsOneWidget);
    expect(find.text('Imported 8 verses in 3 books.'), findsOneWidget);
    // Not silent about what it did not show.
    expect(find.text('The Strong’s numbers in the file are not shown.'), findsOneWidget);
    expect(AddonRegistry.all.single.licenceAttestation, 'addonLicenceAttest');

    await tester.tap(find.byKey(const ValueKey('addon.readNow')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(result!.readNow, isTrue);
    expect(result!.entry.id, 'user-synthetic-test-bible');
  });

  testWidgets('a refused file is a plain sentence, and nothing is stored', (tester) async {
    final s = await _settings('en');
    await tester.pumpWidget(_sheetHost(
        s, 'kjv.zip', Uint8List.fromList([0x50, 0x4B, 0x03, 0x04, 0, 0, 0, 0])));
    await openSheet(tester);
    expect(find.byKey(const ValueKey('addon.stage.refused')), findsOneWidget);
    expect(find.text('That’s a zip file. Unzip it first, then pick the module file inside.'),
        findsOneWidget);
    expect(AddonRegistry.all, isEmpty);
    expect(backend.payloads, isEmpty);
  });

  testWidgets('a locked module and a commentary each say their own thing', (tester) async {
    final s = await _settings('en');
    await tester.pumpWidget(_sheetHost(s, 'x', _fx('mysword_encrypted.bbl.mybible')));
    await openSheet(tester);
    expect(find.text('This module is locked by its publisher. The app can’t open it.'),
        findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());

    await tester.pumpWidget(_sheetHost(s, 'x', _fx('mybible_commentary.SQLite3')));
    await openSheet(tester);
    expect(find.textContaining('commentary module'), findsOneWidget);
  });

  testWidgets('the same refusal in 简体 and 繁體', (tester) async {
    for (final (locale, want) in [
      ('zh-Hans', '这个模块被出版方加了锁，本应用打不开。'),
      ('zh-Hant', '這個模組被出版方加了鎖，本應用打不開。'),
    ]) {
      final s = await _settings(locale);
      await tester.pumpWidget(_sheetHost(s, 'x', _fx('mysword_encrypted.bbl.mybible')));
      await openSheet(tester);
      expect(find.text(want), findsOneWidget, reason: locale);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('a store that refuses says so, and it is the device not the file',
      (tester) async {
    backend.failWrites = true;
    final s = await _settings('en');
    await tester.pumpWidget(_sheetHost(s, 'x.SQLite3', _fx('mybible_min.SQLite3')));
    await openSheet(tester);
    await tester.tap(find.byKey(const ValueKey('addon.attest')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('addon.import')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Your file is fine'), findsOneWidget);
    expect(AddonRegistry.all, isEmpty);
  });

  testWidgets('the page: empty state, then a card, then switch and remove', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(800, 1600);
    addTearDown(tester.view.reset);
    final s = await _settings('en');
    await tester.pumpWidget(_app(s, const AddonsPage()));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Nothing imported yet'), findsOneWidget);
    expect(find.byKey(const ValueKey('addons.choose')), findsOneWidget);

    // Install one directly (the picker is a platform dialog).
    final bytes = _fx('mybible_min.SQLite3');
    final parsed = await tester.runAsync(() async {
      return (await _commit(bytes));
    });
    expect(parsed, isNotNull);
    await tester.pump(const Duration(milliseconds: 300));
    final card = find.byKey(const ValueKey('addon.card.user-card-test'));
    expect(card, findsOneWidget);
    expect(find.textContaining('8 verses · 3 books'), findsOneWidget);

    // Off: it leaves the catalog but stays on the device.
    await tester.tap(find.byKey(const ValueKey('addon.switch.user-card-test')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(AddonRegistry.byId('user-card-test')!.enabled, isFalse);
    expect(backend.payloads, contains('user-card-test'));

    // Remove asks first.
    await tester.tap(card);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('addon.details.remove')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('addon.details.remove')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Remove “Card Test”?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('addon.remove.confirm')));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
    expect(AddonRegistry.all, isEmpty);
    expect(backend.payloads, isEmpty);
  });
}

Future<bool> _commit(Uint8List bytes) async {
  final parsed = await AddonImportService.analyse(bytes, 'x.SQLite3');
  final r = await AddonImportService.commit(
      parsed: parsed,
      sourceBytes: bytes,
      fileName: 'x.SQLite3',
      label: 'Card Test',
      attested: true);
  return r.ok;
}
