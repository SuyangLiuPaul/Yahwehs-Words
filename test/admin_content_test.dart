import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yahwehs_words/models/sermon.dart';
import 'package:yahwehs_words/models/video_series.dart';
import 'package:yahwehs_words/services/admin_content.dart';

VideoTrack _t(String lang, String id, {String? bad}) => VideoTrack(
    lang: lang,
    labelKey: 'k',
    youtubeId: id,
    unavailableSince: bad);
VideoEpisode _e(String id, {List<VideoTrack>? tracks}) => VideoEpisode(
    id: id,
    number: 1,
    titles: const {'en': 'One', 'zh-Hans': '一'},
    tracks: tracks ?? [_t('en', 'AAA'), _t('cmn', 'BBB')]);
VideoSeries _s(String id, List<VideoEpisode> eps) => VideoSeries(
    id: id, titles: const {'en': 'S'}, taglines: const {}, creditKey: 'c', episodes: eps);

Sermon _sermon(String id) => Sermon(
    id: id,
    topic: 'Baptism',
    topicSlug: 'Baptism',
    date: '1979-04-08',
    parts: '',
    passage: 'Luke 4:5',
    title: '旧标题',
    titles: const {'zh-CN': '旧标题', 'zh-TW': '舊標題', 'en': 'Old'},
    hasEn: true,
    hasZhCn: true,
    hasZhTw: true);

void main() {
  group('videos', () {
    final base = [
      _s('cross', [_e('01'), _e('02')]),
      _s('solo', [_e('01')]),
    ];
    test('no overlay: same list', () {
      expect(identical(applyVideoOverlay(base, const {}), base), isTrue);
    });
    test('hide an episode; a series left empty disappears', () {
      final out = applyVideoOverlay(base, {
        'cross-02': {'hidden': true},
        'solo-01': {'hidden': true},
      });
      expect(out.map((s) => s.id), ['cross']);
      expect(out.single.episodes.map((e) => e.id), ['01']);
    });
    test('patch retitles and swaps a YouTube id; untouched episodes survive', () {
      final out = applyVideoOverlay(base, {
        'cross-01': {
          'patch': {'titleEn': 'Renamed', 'ytEn': 'NEWID', 'ytCmn': ''}
        },
      });
      final e = out.first.episodes.first;
      expect(e.titles['en'], 'Renamed');
      expect(e.titles['zh-Hans'], '一'); // not in the patch
      expect(e.tracks.map((t) => '${t.lang}:${t.youtubeId}'), ['en:NEWID']);
      expect(out.first.episodes[1].tracks.length, 2);
    });
    test('clearing every id keeps the originals rather than an unplayable row', () {
      final out = applyVideoOverlay(base, {
        'cross-01': {'patch': {'ytEn': '', 'ytCmn': ''}},
      });
      expect(out.first.episodes.first.tracks.length, 2);
    });
    test('a replaced id is not inherited as "unavailable"', () {
      final b = [
        _s('x', [_e('01', tracks: [_t('en', 'OLD', bad: '2026-09-05')])])
      ];
      final out = applyVideoOverlay(b, {
        'x-01': {'patch': {'ytEn': 'FRESH'}},
      });
      expect(out.first.episodes.first.tracks.first.isUnavailable, isFalse);
    });
    test('custom videos gather into one extra series; ones with nothing to play are skipped', () {
      final out = applyVideoOverlay(base, {
        'c_1': {'custom': true, 'data': {'titleHans': '新视频', 'ytEn': 'ZZZ'}},
        'c_2': {'custom': true, 'data': {'titleHans': '无链接'}},
        'c_3': {'custom': true, 'hidden': true, 'data': {'titleEn': 'H', 'ytEn': 'Q'}},
      });
      expect(out.last.id, 'more');
      expect(out.last.episodes.length, 1);
      expect(out.last.episodes.single.titles['zh-Hans'], '新视频');
      expect(out.last.episodes.single.tracks.single.youtubeId, 'ZZZ');
    });
  });

  group('sermons', () {
    final base = [_sermon('004'), _sermon('005')];
    test('hide and patch', () {
      final out = applySermonOverlay(base, {
        '004': {'hidden': true},
        '005': {'patch': {'title': '新标题', 'passage': 'John 1:1', 'titleEn': 'New'}},
      });
      expect(out.map((s) => s.id), ['005']);
      expect(out.single.title, '新标题');
      expect(out.single.titles['zh-CN'], '新标题');
      expect(out.single.titles['zh-TW'], '舊標題'); // no auto-conversion
      expect(out.single.titles['en'], 'New');
      expect(out.single.passage, 'John 1:1');
      expect(out.single.date, '1979-04-08');
    });
    test('an empty patch value keeps the original', () {
      final out = applySermonOverlay(base, {
        '004': {'patch': {'passage': ''}},
      });
      expect(out.first.passage, 'Luke 4:5');
    });
  });

  group('links', () {
    test('valid https rows for this app, ordered, hidden/invalid dropped', () {
      final l = parseAdminLinks({
        'a': {'custom': true, 'data': {'title': 'B', 'url': 'https://b.test', 'order': '2', 'group': '参考资料'}},
        'b': {'custom': true, 'data': {'title': 'A', 'url': 'https://a.test', 'order': '1', 'app': 'words', 'group': 'Study'}},
        'c': {'custom': true, 'data': {'title': 'Sword only', 'url': 'https://s.test', 'app': 'sword'}},
        'd': {'custom': true, 'hidden': true, 'data': {'title': 'H', 'url': 'https://h.test'}},
        'e': {'custom': true, 'data': {'title': 'Bad', 'url': 'http://insecure.test'}},
        'f': {'custom': true, 'data': {'title': '', 'url': 'https://x.test'}},
        'g': {'patch': {}},
      }, 'words');
      expect(l.map((x) => x.title), ['A', 'B']);
      expect(l.map((x) => x.slot), ['study', 'reference']);
      expect(parseAdminLinks({'c': {'custom': true, 'data': {'title': 'S', 'url': 'https://s.test', 'app': 'sword'}}}, 'sword').length, 1);
    });
    test('group text maps to the four home groups', () {
      AdminLink g(String t) => AdminLink(id: 'x', title: 't', url: 'https://x', group: t);
      expect(g('常用').slot, 'frequent');
      expect(g('Frequent').slot, 'frequent');
      expect(g('研讀').slot, 'study');
      expect(g('帮助与反馈').slot, 'help');
      expect(g('whatever').slot, 'reference');
      expect(g('').slot, 'reference');
    });
  });

  test('the app applies each overlay where the data is loaded', () {
    expect(File('lib/pages/videos_page.dart').readAsStringSync(), contains("AdminOverlay.collection('adm_videos'"));
    expect(File('lib/services/sermon_service.dart').readAsStringSync(), contains("AdminOverlay.collection('adm_sermons'"));
    expect(File('lib/pages/dashboard_page.dart').readAsStringSync(), contains("AdminOverlay.collection('adm_links')"));
    expect(File('lib/pages/dashboard_page.dart').readAsStringSync(), contains("_adminLinkTiles('help')"));
  });
}
