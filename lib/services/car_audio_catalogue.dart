import 'companion_theme.dart';
import '../constants/song_source_icons.dart';
import 'package:audio_service/audio_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/song.dart';
import '../models/song_queue.dart';
import 'song_service.dart';
import 'song_playlist_service.dart';
import 'song_player_service.dart';
import 'sermon_service.dart';
import 'sermon_audio_service.dart';

/// Both car platforms browse this bounded tree. Video-only records never
/// promise audio, and folders group by source/series rather than exposing
/// hundreds of rows on a driving screen.
class CarAudioCatalogue {
  static const root = 'car:root';
  /// The themed logo, standing in for a cover. A getter, not a constant:
  /// it follows the theme colour the reader picks.
  static Uri get artwork => CompanionTheme.artwork;
  static String _title(String locale, String en, String hans, String hant) =>
      locale == 'zh-Hant'
          ? hant
          : locale.startsWith('zh')
              ? hans
              : en;
  static MediaItem folder(String id, String title,
          {String? subtitle, Uri? art}) =>
      MediaItem(
          id: id,
          title: title,
          artist: subtitle,
          playable: false,
          artUri: art ?? artwork);

  /// A song source's own mark (FYDT, CDC, CGDC, …), served by the website
  /// from the same bundled asset the phone shows. Null when the source has
  /// none, and the folder keeps the themed logo.
  static Uri? sourceLogo(String source) {
    final asset = songSourceIcon(source);
    return asset == null
        ? null
        : Uri.parse('https://yahwehword.com/assets/$asset');
  }

  /// "Ask 祈求" -> "Ask"; "祈求之歌" -> "祈求之歌". The leading word, or the
  /// first few characters when the title opens in Chinese — enough to tell
  /// pages apart at a glance.
  static String shortTitle(String title) {
    final t = title.trim();
    if (t.isEmpty) return '';
    final first = t.split(RegExp(r'\s+')).first;
    final runes = first.runes.toList();
    return runes.length > 8 ? String.fromCharCodes(runes.take(8)) : first;
  }

  /// A page label a person can read: where the page starts and ends, in the
  /// songs themselves ("Ask – Sail"), not in counting numbers ("1–60").
  static String pageLabel(List<String> titles) {
    if (titles.isEmpty) return '';
    final a = shortTitle(titles.first), b = shortTitle(titles.last);
    return a == b ? a : '$a – $b';
  }

  static Future<List<Song>> _songs() async => (await SongService.load())
      .where((s) =>
          SongQueue.resolveTrack(
              s, TrackPreference.vocal, TrackFallback.useVocal) !=
          null)
      .toList();

  static Future<List<MediaItem>> children(String id) async {
    if (id == root || id == AudioService.browsableRootId) {
      final locale =
          (await SharedPreferences.getInstance()).getString('locale') ?? 'en';
      return [
        folder('car:queue', _title(locale, 'Playing queue', '播放队列', '播放佇列')),
        folder('car:playlists', _title(locale, 'Playlists', '播放列表', '播放清單')),
        folder('car:songs', _title(locale, 'Hymns', '诗歌', '詩歌')),
        folder('car:instrumental', _title(locale, 'Instrumental', '伴奏', '伴奏')),
        folder('car:sermons', _title(locale, 'Sermons', '讲道', '講道'))
      ];
    }
    final locale =
        (await SharedPreferences.getInstance()).getString('locale') ?? 'en';
    if (id == 'car:queue' || id.startsWith('car:queue-page/')) {
      final queue = SongPlayerService.instance.queue;
      final offset =
          id == 'car:queue' ? 0 : int.tryParse(id.split('/').last) ?? -1;
      if (offset < 0) return const [];
      final rows = <MediaItem>[
        for (final entry in queue.items.skip(offset).take(40))
          MediaItem(
              id: 'car:queued/${Uri.encodeComponent(entry.url)}',
              title: entry.song.title,
              artist: entry.song.creditLine ?? entry.song.sourceLabel,
              album: queue.sourceLabel,
              artUri: Uri.tryParse(entry.song.artworkUrl ?? '') ?? artwork),
      ];
      if (offset + 40 < queue.length) {
        rows.add(folder('car:queue-page/${offset + 40}',
            _title(locale, 'More', '更多', '更多')));
      }
      return rows;
    }
    if (id == 'car:playlists' || id.startsWith('car:playlist/')) {
      final service = SongPlaylistService.instance;
      await service.load();
      if (id == 'car:playlists') {
        return [
          for (final playlist in service.ordered)
            folder(
                'car:playlist/${Uri.encodeComponent(playlist.id)}/0',
                playlist.isFavourites
                    ? _title(locale, 'Favourites', '收藏', '收藏')
                    : playlist.name)
        ];
      }
      final parts = id.split('/');
      if (parts.length != 3) return const [];
      final offset = int.tryParse(parts[2]) ?? -1;
      if (offset < 0) return const [];
      final matches =
          service.playlists.where((p) => p.id == Uri.decodeComponent(parts[1]));
      if (matches.isEmpty) return const [];
      final playlist = matches.first;
      final queue = SongQueue.fromSongs(playlist.resolve(await _songs()),
          preference: playlist.preference, fallback: playlist.fallback);
      return [
        for (final entry in queue.items.skip(offset).take(40))
          MediaItem(
              id: 'car:playlist-song/${parts[1]}/${Uri.encodeComponent(entry.song.id)}',
              title: entry.song.title,
              album: playlist.name,
              artUri: Uri.tryParse(entry.song.artworkUrl ?? '') ?? artwork),
        if (offset + 40 < queue.length)
          folder('car:playlist/${parts[1]}/${offset + 40}',
              _title(locale, 'More', '更多', '更多'))
      ];
    }
    if (id == 'car:songs' || id == 'car:instrumental') {
      final songs = await _songs();
      final instrumental = id == 'car:instrumental';
      final sources = songs
          .where((s) =>
              !instrumental ||
              SongQueue.resolveTrack(
                      s, TrackPreference.instrumental, TrackFallback.skip) !=
                  null)
          .map((s) => s.source)
          .toSet();
      int count(String source) => songs
          .where((s) =>
              s.source == source &&
              (!instrumental ||
                  SongQueue.resolveTrack(s, TrackPreference.instrumental,
                          TrackFallback.skip) !=
                      null))
          .length;
      return [
        for (final source in sources)
          folder('$id/$source',
              songs.firstWhere((s) => s.source == source).sourceLabel,
              subtitle: _title(locale, '${count(source)} songs',
                  '${count(source)} 首', '${count(source)} 首'),
              art: sourceLogo(source))
      ];
    }
    if (id.startsWith('car:songs/') || id.startsWith('car:instrumental/')) {
      final instrumental = id.startsWith('car:instrumental/');
      final source = id.split('/').last;
      final items = (await _songs()).where((s) => s.source == source);
      // Page larger libraries so a car never receives a thousand siblings.
      return _songPages(id, items.toList(), instrumental, locale);
    }
    if (id.startsWith('car:page/')) {
      final parts = id.split('/');
      if (parts.length != 4 ||
          !const ['vocal', 'instrumental'].contains(parts[1])) {
        return const [];
      }
      final offset = int.tryParse(parts[3]);
      if (offset == null || offset < 0) return const [];
      final instrumental = parts[1] == 'instrumental';
      final songs =
          (await _songs()).where((s) => s.source == parts[2]).toList();
      return _songItems(songs, instrumental).skip(offset).take(60).toList();
    }
    final audio = SermonAudioService.instance;
    await audio.load();
    final sermons = (await SermonService.instance.loadIndex())
        .where((s) => audio.hasAudio(s.id))
        .toList();
    if (id == 'car:sermons') {
      final locale =
          (await SharedPreferences.getInstance()).getString('locale') ?? 'en';
      int count(String topic) => sermons.where((s) => s.topic == topic).length;
      return [
        for (final topic in sermons.map((s) => s.topic).toSet())
          folder('car:topic/${Uri.encodeComponent(topic)}', topic,
              subtitle: _title(locale, '${count(topic)} sermons',
                  '${count(topic)} 篇', '${count(topic)} 篇'))
      ];
    }
    if (id.startsWith('car:topic/')) {
      final topic = Uri.decodeComponent(id.substring('car:topic/'.length));
      return [
        for (final s in sermons.where((s) => s.topic == topic))
          MediaItem(
              id: 'car:sermon/${s.id}',
              title: s.title,
              artist: 'Eric H. H. Chang',
              album: s.topic,
              artUri: artwork)
      ];
    }
    return const [];
  }

  static List<MediaItem> _songItems(List<Song> songs, bool instrumental) => [
        for (final s in songs)
          if (!instrumental ||
              SongQueue.resolveTrack(
                      s, TrackPreference.instrumental, TrackFallback.skip) !=
                  null)
            MediaItem(
                id:
                    'car:song/${instrumental ? "instrumental" : "vocal"}/${s.id}',
                title: s.title,
                artist: s.creditLine ?? s.sourceLabel,
                album: s.album ?? s.sourceLabel,
                artUri: s.artworkUrl == null
                    ? artwork
                    : Uri.tryParse(s.artworkUrl!) ?? artwork)
      ];

  static List<MediaItem> _songPages(
      String parent, List<Song> songs, bool instrumental, String locale) {
    final items = _songItems(songs, instrumental);
    if (items.length <= 60) return items;
    final source = parent.split('/').last;
    final logo = sourceLogo(source);
    return [
      for (var i = 0; i < items.length; i += 60)
        folder(
            'car:page/${instrumental ? "instrumental" : "vocal"}/$source/$i',
            pageLabel([
              for (final m in items.skip(i).take(60)) m.title,
            ]),
            subtitle: _title(
                locale,
                '${items.skip(i).take(60).length} songs',
                '${items.skip(i).take(60).length} 首',
                '${items.skip(i).take(60).length} 首'),
            art: logo)
    ];
  }

  static Future<List<MediaItem>> search(String query) async {
    final term = query.trim().toLowerCase();
    if (term.isEmpty) return const [];
    final songs = (await _songs()).where((s) =>
        s.title.toLowerCase().contains(term) ||
        s.sourceLabel.toLowerCase().contains(term));
    final audio = SermonAudioService.instance;
    await audio.load();
    final sermons = (await SermonService.instance.loadIndex()).where((s) =>
        audio.hasAudio(s.id) &&
        (s.title.toLowerCase().contains(term) ||
            s.titles.values.any((t) => t.toLowerCase().contains(term))));
    return [
      ..._songItems(songs.toList(), false),
      for (final s in sermons)
        MediaItem(
            id: 'car:sermon/${s.id}',
            title: s.title,
            artist: 'Eric H. H. Chang',
            album: s.topic,
            artUri: artwork)
    ].take(30).toList();
  }

  static Future<MediaItem?> item(String id) async {
    if (id.startsWith('car:song/')) {
      final parts = id.split('/');
      if (parts.length != 3) return null;
      final songs = (await _songs()).where((s) => s.id == parts[2]).toList();
      final items = _songItems(songs, parts[1] == 'instrumental');
      return items.isEmpty ? null : items.first;
    }
    if (id.startsWith('car:sermon/')) {
      final matches = (await SermonService.instance.loadIndex())
          .where((s) => 'car:sermon/${s.id}' == id);
      if (matches.isNotEmpty) {
        return MediaItem(
            id: id,
            title: matches.first.title,
            artist: 'Eric H. H. Chang',
            album: matches.first.topic,
            artUri: artwork);
      }
    }
    return null;
  }

  static Future<void> play(String id) async {
    if (id.startsWith('car:queued/')) {
      final url = Uri.decodeComponent(id.substring('car:queued/'.length));
      final player = SongPlayerService.instance;
      final index = player.queue.items.indexWhere((entry) => entry.url == url);
      if (index < 0) {
        final locale =
            (await SharedPreferences.getInstance()).getString('locale') ?? 'en';
        throw StateError(_title(
            locale,
            'Queue changed. Refresh and select again.',
            '队列已更新，请刷新后重新选择。',
            '佇列已更新，請重新整理後再選擇。'));
      }
      if (index == player.queue.index) {
        await player.resumeCurrent();
      } else {
        await player.playAt(index);
      }
      return;
    }
    if (id.startsWith('car:playlist-song/')) {
      final parts = id.split('/');
      if (parts.length != 3) return;
      final service = SongPlaylistService.instance;
      await service.load();
      final matches =
          service.playlists.where((p) => p.id == Uri.decodeComponent(parts[1]));
      if (matches.isEmpty) return;
      final playlist = matches.first;
      final songs = playlist.resolve(await _songs());
      final songId = Uri.decodeComponent(parts[2]);
      if (!songs.any((song) => song.id == songId)) return;
      final player = SongPlayerService.instance;
      if (player.queue.sourceLabel == playlist.name &&
          player.queue.current?.song.id == songId) {
        await player.resumeCurrent();
        return;
      }
      await player.playQueue(songs,
          startSongId: songId,
          preference: playlist.preference,
          fallback: playlist.fallback,
          label: playlist.name);
      return;
    }

    if (id.startsWith('car:sermon/')) {
      final audio = SermonAudioService.instance;
      final sermonId = id.substring('car:sermon/'.length);
      // Selection is idempotent; choosing the currently playing sermon
      // from the car must not toggle it to paused.
      if (audio.isCurrent(sermonId)) {
        await audio.remotePlay();
      } else {
        await audio.play(sermonId);
      }
    } else if (id.startsWith('car:song/')) {
      final parts = id.split('/');
      if (parts.length != 3 ||
          !const ['vocal', 'instrumental'].contains(parts[1])) {
        return;
      }
      final songs = await _songs();
      final matches = songs.where((s) => s.id == parts[2]).toList();
      if (matches.isEmpty) return;
      final song = matches.first;
      final player = SongPlayerService.instance;
      final mix =
          parts[1] == 'instrumental' ? SongTrack.instrumental : SongTrack.vocal;
      if (player.isCurrent(song, mix)) {
        await player.resumeCurrent();
        return;
      }
      await SongPlayerService.instance.playQueue(
          songs.where((s) => s.source == song.source).toList(),
          startSongId: song.id,
          preference: parts[1] == 'instrumental'
              ? TrackPreference.instrumental
              : TrackPreference.vocal,
          fallback: TrackFallback.skip,
          label: song.sourceLabel);
    }
  }
}
