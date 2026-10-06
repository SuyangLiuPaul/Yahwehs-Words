import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahwehs_words/constants/app_version.dart';
import 'package:yahwehs_words/services/release_registry.dart';
import 'package:yahwehs_words/widgets/manual_update_tile.dart';

/// The manual "Check for updates" for web and store builds, which had no
/// manual check at all before 2026-10-06.
void main() {
  group('parseVersions', () {
    final node = {
      'platforms': {
        'android': {'latest': '1.7.10', 'min': '1.7.0', 'url': 'https://x.test/a'},
        'web': {'latest': '', 'min': '', 'url': ''},
      },
      'notes': {'zh-Hans': '简体说明', 'en': 'English notes', 'zh-Hant': ''},
    };
    test('reads the platform entry and notes', () {
      final e = ReleaseRegistry.parseVersions(node, 'android')!;
      expect(e.latest, '1.7.10');
      expect(e.min, '1.7.0');
      expect(e.url, 'https://x.test/a');
      expect(e.notesFor('en'), 'English notes');
      expect(e.notesFor('zh-Hant'), '简体说明'); // empty Hant falls back
    });
    test('an all-empty or missing platform is null, junk is null', () {
      expect(ReleaseRegistry.parseVersions(node, 'web'), isNull);
      expect(ReleaseRegistry.parseVersions(node, 'ios'), isNull);
      expect(ReleaseRegistry.parseVersions(null, 'android'), isNull);
      expect(ReleaseRegistry.parseVersions('x', 'android'), isNull);
    });
  });

  group('decideUpdate', () {
    const cur = '1.7.10';
    test('the channel wins when it answered', () {
      expect(decideUpdate(channelNewer: true, registry: null, current: cur),
          ManualUpdateKind.available);
      expect(
          decideUpdate(
              channelNewer: false,
              registry: const ReleaseEntry(latest: '9.9.9'),
              current: cur),
          ManualUpdateKind.upToDate);
    });
    test('without a channel answer the portal number decides', () {
      expect(
          decideUpdate(
              channelNewer: null,
              registry: const ReleaseEntry(latest: '1.7.11'),
              current: cur),
          ManualUpdateKind.available);
      expect(
          decideUpdate(
              channelNewer: null,
              registry: const ReleaseEntry(latest: '1.7.10'),
              current: cur),
          ManualUpdateKind.upToDate);
      expect(decideUpdate(channelNewer: null, registry: null, current: cur),
          ManualUpdateKind.failed);
    });
    test('a minimum above the installed version forces an update', () {
      expect(
          decideUpdate(
              channelNewer: false,
              registry: const ReleaseEntry(min: '1.8.0'),
              current: cur),
          ManualUpdateKind.required);
    });
  });

  Future<void> mount(WidgetTester t, ManualUpdateResult r,
      {String locale = 'en'}) async {
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ManualUpdateTile(locale: locale, checker: () async => r))));
    await t.tap(find.byKey(const ValueKey('manual-update.tile')));
    await t.pumpAndSettle();
  }

  testWidgets('up to date: dialog, no action button', (t) async {
    await mount(t, const ManualUpdateResult(ManualUpdateKind.upToDate));
    expect(find.text('You’re up to date'), findsOneWidget);
    expect(find.text('Installed: v$kAppVersion'), findsOneWidget);
    expect(find.byKey(const ValueKey('manual-update.act')), findsNothing);
  });

  testWidgets('available: shows version, notes and the action', (t) async {
    var acted = false;
    await mount(
        t,
        ManualUpdateResult(ManualUpdateKind.available,
            version: '9.9.9',
            notes: 'Faster search',
            actLabelEn: 'Update on Google Play',
            act: () async => acted = true));
    expect(find.text('A new version is available'), findsOneWidget);
    expect(find.text('Latest: v9.9.9'), findsOneWidget);
    expect(find.text('Faster search'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('manual-update.act')));
    await t.pumpAndSettle();
    expect(acted, isTrue);
  });

  testWidgets('failed offers a retry hint, Chinese renders', (t) async {
    await mount(t, const ManualUpdateResult(ManualUpdateKind.failed),
        locale: 'zh-Hant');
    expect(find.text('暫時無法檢查更新'), findsOneWidget);
    expect(find.text('請檢查網路後重試。'), findsOneWidget);
  });

  test('both doors carry the tile', () {
    for (final f in ['lib/pages/about_page.dart', 'lib/pages/settings_page.dart']) {
      expect(File(f).readAsStringSync(), contains('ManualUpdateTile('), reason: f);
    }
  });
}
