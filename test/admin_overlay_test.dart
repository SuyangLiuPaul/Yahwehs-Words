import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahwehs_words/models/song.dart';
import 'package:yahwehs_words/services/admin_overlay.dart';
import 'package:yahwehs_words/services/song_service.dart';
import 'package:yahwehs_words/widgets/admin_announcement_banner.dart';

Song _song(String id, {String title = 'T', String? audio, List<String>? themes}) =>
    Song(
        id: id,
        title: title,
        language: 'en',
        source: 'cdc',
        sourceLabel: 'CDC',
        url: 'https://x.test/$id',
        audioUrl: audio,
        themes: themes ?? const ['a']);

void main() {
  group('songs overlay', () {
    final base = [_song('a', title: 'Alpha', audio: 'https://m/a.mp3'), _song('b'), _song('c')];

    test('no overlay leaves the list untouched', () {
      expect(SongService.applyAdminOverlay(base, const {}).map((s) => s.id), ['a', 'b', 'c']);
    });
    test('hidden removes, patch edits, empty string clears', () {
      final out = SongService.applyAdminOverlay(base, {
        'b': {'hidden': true},
        'a': {'patch': {'title': 'Alpha 2', 'audioUrl': '', 'themes': ['x', 'y']}},
      });
      expect(out.map((s) => s.id), ['a', 'c']);
      expect(out.first.title, 'Alpha 2');
      expect(out.first.audioUrl, isNull);
      expect(out.first.themes, ['x', 'y']);
      expect(out.first.url, 'https://x.test/a'); // untouched fields survive
    });
    test('custom songs are added; blank titles and hidden customs are not', () {
      final out = SongService.applyAdminOverlay(base, {
        'c_1': {'custom': true, 'data': {'title': 'New song', 'audioUrl': 'https://m/n.mp3'}},
        'c_2': {'custom': true, 'data': {'title': '  '}},
        'c_3': {'custom': true, 'hidden': true, 'data': {'title': 'Hidden'}},
      });
      expect(out.map((s) => s.id), ['a', 'b', 'c', 'c_1']);
      expect(out.last.title, 'New song');
      expect(out.last.audioUrl, 'https://m/n.mp3');
    });
  });

  group('site', () {
    final now = DateTime.utc(2026, 10, 6, 12);
    test('featured order and off list', () {
      final s = AdminOverlay.parseSite({
        'featured': {'order': ['songs', 'videos', 'sermons'], 'off': ['videos']}
      }, now: now);
      expect(s.featuredOrder, ['songs', 'videos', 'sermons']);
      expect(s.featuredOff, {'videos'});
    });
    test('announcement: enabled, this app, within its window', () {
      Object ann({bool on = true, Map? apps, String? start, String? end}) => {
            'announcement': {
              'enabled': on,
              if (apps != null) 'apps': apps,
              'text': {'zh-Hans': '维护通知', 'en': 'Maintenance'},
              if (start != null) 'startsAt': start,
              if (end != null) 'endsAt': end,
            }
          };
      expect(AdminOverlay.parseSite(ann(), now: now).announcement!.textFor('en'), 'Maintenance');
      expect(AdminOverlay.parseSite(ann(on: false), now: now).announcement, isNull);
      expect(AdminOverlay.parseSite(ann(apps: {'words': false, 'sword': true}), now: now).announcement, isNull);
      expect(AdminOverlay.parseSite(ann(start: '2026-10-07T00:00'), now: now).announcement, isNull);
      expect(AdminOverlay.parseSite(ann(end: '2026-10-05T00:00'), now: now).announcement, isNull);
      expect(AdminOverlay.parseSite(ann(start: '2026-10-01T00:00', end: '2026-10-09T00:00'), now: now).announcement, isNotNull);
      // locale falls back to Simplified
      expect(AdminOverlay.parseSite(ann(), now: now).announcement!.textFor('zh-Hant'), '维护通知');
    });
    test('junk is "nothing set"', () {
      expect(AdminOverlay.parseSite(null, now: now).announcement, isNull);
      expect(AdminOverlay.parseSite('x', now: now).featuredOrder, isNull);
    });
  });

  group('fetching', () {
    tearDown(() {
      AdminOverlay.fetcher = null;
      AdminOverlay.clearCache();
    });
    test('a failing fetch means no overlay, not an error, and is retried', () async {
      var calls = 0;
      AdminOverlay.fetcher = (p) async {
        calls++;
        throw Exception('offline');
      };
      expect(await AdminOverlay.collection('adm_songs'), isEmpty);
      expect(await AdminOverlay.collection('adm_songs'), isEmpty);
      expect(calls, 2);
    });
    test('a good fetch is cached', () async {
      var calls = 0;
      AdminOverlay.fetcher = (p) async {
        calls++;
        return {'a': {'hidden': true}};
      };
      expect((await AdminOverlay.collection('adm_songs')).keys, ['a']);
      await AdminOverlay.collection('adm_songs');
      expect(calls, 1);
    });
  });

  group('banner', () {
    Future<void> mount(WidgetTester t, AdminAnnouncement? a) async {
      SharedPreferences.setMockInitialValues({});
      await t.pumpWidget(MaterialApp(
          home: Scaffold(body: AdminAnnouncementBanner(locale: 'zh-Hans', announcement: a))));
      await t.pumpAndSettle();
    }

    testWidgets('shows, dismisses, and stays dismissed for the same text', (t) async {
      const a = AdminAnnouncement(id: 'v1', text: {'zh-Hans': '周六维护'});
      await mount(t, a);
      expect(find.text('周六维护'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('admin.announcement.close')));
      await t.pumpAndSettle();
      expect(find.text('周六维护'), findsNothing);
      // remount: still dismissed (prefs persisted), a new id shows again
      await t.pumpWidget(const MaterialApp(
          home: Scaffold(body: AdminAnnouncementBanner(locale: 'zh-Hans', announcement: a))));
      await t.pumpAndSettle();
      expect(find.text('周六维护'), findsNothing);
      await t.pumpWidget(const MaterialApp(
          home: Scaffold(body: AdminAnnouncementBanner(locale: 'zh-Hans', announcement: AdminAnnouncement(id: 'v2', text: {'zh-Hans': '周六维护'})))));
      await t.pumpAndSettle();
      expect(find.text('周六维护'), findsOneWidget);
    });
    testWidgets('nothing when there is no announcement', (t) async {
      await mount(t, null);
      expect(find.byKey(const ValueKey('admin.announcement')), findsNothing);
    });
  });

  test('the home page wires the banner and the featured order', () {
    final d = File('lib/pages/dashboard_page.dart').readAsStringSync();
    expect(d, contains('AdminAnnouncementBanner('));
    expect(d, contains('_adminSite.featuredOrder'));
    expect(File('lib/services/song_service.dart').readAsStringSync(), contains("AdminOverlay.collection('adm_songs')"));
  });
}
