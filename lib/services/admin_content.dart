// Applying the admin portal's overlays to videos, sermons and links.
// Pure functions over already-parsed lists, so each is tested without a
// network; the fetching lives in [AdminOverlay]. With no overlay every
// function returns its input unchanged.

import 'package:yahwehs_words/models/sermon.dart';
import 'package:yahwehs_words/models/video_series.dart';

String? _clean(Object? v) {
  if (v == null) return null;
  final t = v.toString().trim();
  return t.isEmpty ? null : t;
}

const _trackLabelKey = {
  'en': 'oneGodLangEn',
  'yue': 'oneGodLangYue',
  'cmn': 'oneGodLangCmn',
};

/// Videos: the portal lists one row per episode, id `<series>-<episode>`.
/// Hidden removes the episode (and a series left empty); a patch can
/// retitle it and change its three YouTube ids; custom rows are gathered
/// into one extra series so a video added in the portal is playable.
List<VideoSeries> applyVideoOverlay(
    List<VideoSeries> base, Map<String, Map<String, dynamic>> overlay) {
  if (overlay.isEmpty) return base;
  final out = <VideoSeries>[];
  for (final s in base) {
    final eps = <VideoEpisode>[];
    for (final e in s.episodes) {
      final o = overlay['${s.id}-${e.id}'];
      if (o == null) {
        eps.add(e);
        continue;
      }
      if (o['hidden'] == true) continue;
      final p = o['patch'];
      eps.add(p is Map ? _patchEpisode(e, Map<String, dynamic>.from(p)) : e);
    }
    if (eps.isEmpty && s.episodes.isNotEmpty) continue;
    out.add(eps.length == s.episodes.length &&
            List.generate(eps.length, (i) => identical(eps[i], s.episodes[i]))
                .every((x) => x)
        ? s
        : VideoSeries(
            id: s.id,
            titles: s.titles,
            taglines: s.taglines,
            creditKey: s.creditKey,
            episodes: eps,
            compilations: s.compilations));
  }
  final custom = <VideoEpisode>[];
  var n = 0;
  final keys = overlay.keys.toList()..sort();
  for (final id in keys) {
    final o = overlay[id]!;
    if (o['custom'] != true || o['hidden'] == true) continue;
    final d = o['data'];
    if (d is! Map) continue;
    final data = Map<String, dynamic>.from(d);
    final hans = _clean(data['titleHans']);
    final hant = _clean(data['titleHant']);
    final en = _clean(data['titleEn']);
    if (hans == null && hant == null && en == null) continue;
    final tracks = <VideoTrack>[
      for (final lang in const ['en', 'cmn', 'yue'])
        if (_clean(data['yt${lang == 'en' ? 'En' : lang == 'cmn' ? 'Cmn' : 'Yue'}']) !=
            null)
          VideoTrack(
              lang: lang,
              labelKey: _trackLabelKey[lang]!,
              youtubeId: _clean(data[
                  'yt${lang == 'en' ? 'En' : lang == 'cmn' ? 'Cmn' : 'Yue'}'])!),
    ];
    if (tracks.isEmpty) continue;
    custom.add(VideoEpisode(
        id: id,
        number: ++n,
        titles: {
          'zh-Hans': hans ?? hant ?? en!,
          'zh-Hant': hant ?? hans ?? en!,
          'en': en ?? hans ?? hant!,
        },
        tracks: tracks));
  }
  if (custom.isNotEmpty) {
    out.add(VideoSeries(
        id: 'more',
        titles: const {
          'en': 'More videos',
          'zh-Hans': '更多视频',
          'zh-Hant': '更多影片'
        },
        taglines: const {},
        creditKey: 'oneGodCredit',
        episodes: custom));
  }
  return out;
}

VideoEpisode _patchEpisode(VideoEpisode e, Map<String, dynamic> p) {
  final titles = Map<String, String>.of(e.titles);
  void title(String key, String locale) {
    if (!p.containsKey(key)) return;
    final v = _clean(p[key]);
    if (v == null) {
      titles.remove(locale);
    } else {
      titles[locale] = v;
    }
  }

  title('titleHans', 'zh-Hans');
  title('titleHant', 'zh-Hant');
  title('titleEn', 'en');
  var tracks = List<VideoTrack>.of(e.tracks);
  void yt(String key, String lang) {
    if (!p.containsKey(key)) return;
    final v = _clean(p[key]);
    final i = tracks.indexWhere((t) => t.lang == lang);
    if (v == null) {
      if (i >= 0) tracks.removeAt(i);
    } else if (i >= 0) {
      final t = tracks[i];
      tracks[i] = VideoTrack(
          lang: t.lang, labelKey: t.labelKey, youtubeId: v); // a new id: not "unavailable"
    } else {
      tracks.add(VideoTrack(
          lang: lang, labelKey: _trackLabelKey[lang]!, youtubeId: v));
    }
  }

  yt('ytEn', 'en');
  yt('ytCmn', 'cmn');
  yt('ytYue', 'yue');
  if (tracks.isEmpty) tracks = List<VideoTrack>.of(e.tracks);
  return VideoEpisode(
      id: e.id, number: e.number, titles: titles, tracks: tracks, refs: e.refs);
}

/// Sermons: hide, and retitle / re-date / re-topic. (Adding a sermon in
/// the portal is not offered: a sermon needs a body text the portal
/// cannot hold.) The Chinese title edit applies to the Simplified title
/// only — there is no automatic Traditional conversion.
List<Sermon> applySermonOverlay(
    List<Sermon> base, Map<String, Map<String, dynamic>> overlay) {
  if (overlay.isEmpty) return base;
  final out = <Sermon>[];
  for (final s in base) {
    final o = overlay[s.id];
    if (o == null) {
      out.add(s);
      continue;
    }
    if (o['hidden'] == true) continue;
    final p = o['patch'];
    if (p is! Map) {
      out.add(s);
      continue;
    }
    String field(String k, String cur) =>
        p.containsKey(k) ? (_clean(p[k]) ?? cur) : cur;
    final titles = Map<String, String>.of(s.titles);
    final zh = p.containsKey('title') ? _clean(p['title']) : null;
    if (zh != null) titles['zh-CN'] = zh;
    final en = p.containsKey('titleEn') ? _clean(p['titleEn']) : null;
    if (en != null) titles['en'] = en;
    out.add(Sermon(
        id: s.id,
        topic: field('topic', s.topic),
        topicSlug: s.topicSlug,
        date: field('date', s.date),
        parts: s.parts,
        passage: field('passage', s.passage),
        title: zh ?? s.title,
        titles: titles,
        hasEn: s.hasEn,
        hasZhCn: s.hasZhCn,
        hasZhTw: s.hasZhTw));
  }
  return out;
}

/// A link added in the portal (`adm_links`).
class AdminLink {
  final String id;
  final String title;
  final String url;
  final String group; // raw text the admin typed
  final int order;
  const AdminLink(
      {required this.id,
      required this.title,
      required this.url,
      this.group = '',
      this.order = 0});

  /// The home page group this link belongs to: 'frequent' | 'study' |
  /// 'reference' | 'help'. Unrecognised text goes to 'reference'.
  String get slot {
    final g = group.toLowerCase();
    if (g.contains('常用') || g.contains('frequent') || g.contains('common')) {
      return 'frequent';
    }
    if (g.contains('研读') || g.contains('研讀') || g.contains('study')) {
      return 'study';
    }
    if (g.contains('帮助') ||
        g.contains('幫助') ||
        g.contains('反馈') ||
        g.contains('help')) {
      return 'help';
    }
    return 'reference';
  }
}

/// The portal's links for [app] ('words' | 'sword'), hidden and invalid
/// (non-https, untitled) rows removed, in order.
List<AdminLink> parseAdminLinks(
    Map<String, Map<String, dynamic>> overlay, String app) {
  final out = <AdminLink>[];
  overlay.forEach((id, o) {
    if (o['custom'] != true || o['hidden'] == true) return;
    final d = o['data'];
    if (d is! Map) return;
    final title = _clean(d['title']);
    final url = _clean(d['url']);
    if (title == null || url == null || !url.startsWith('https://')) return;
    final target = _clean(d['app']) ?? 'both';
    if (target != 'both' && target != app) return;
    out.add(AdminLink(
        id: id,
        title: title,
        url: url,
        group: _clean(d['group']) ?? '',
        order: int.tryParse('${d['order'] ?? ''}') ?? 0));
  });
  out.sort((a, b) {
    final c = a.order.compareTo(b.order);
    return c != 0 ? c : a.title.compareTo(b.title);
  });
  return out;
}
