import 'package:audio_service/audio_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/song.dart';
import '../models/song_queue.dart';
import 'song_service.dart';
import 'song_player_service.dart';
import 'sermon_service.dart';
import 'sermon_audio_service.dart';

/// Both car platforms browse this bounded tree. Video-only records never
/// promise audio, and folders group by source/series rather than exposing
/// hundreds of rows on a driving screen.
class CarAudioCatalogue {
  static const root = 'car:root';
  static final artwork = Uri.parse('https://yahwehword.com/icons/Icon-512.png');
  static String _title(String locale, String en, String hans, String hant) =>
      locale == 'zh-Hant'
          ? hant
          : locale.startsWith('zh')
              ? hans
              : en;
  static MediaItem folder(String id, String title) =>
      MediaItem(id: id, title: title, playable: false, artUri: artwork);

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
        folder('car:songs', _title(locale, 'Hymns', '诗歌', '詩歌')),
        folder('car:instrumental', _title(locale, 'Instrumental', '伴奏', '伴奏')),
        folder('car:sermons', _title(locale, 'Sermons', '讲道', '講道'))
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
      return [
        for (final source in sources)
          folder('$id/$source',
              songs.firstWhere((s) => s.source == source).sourceLabel)
      ];
    }
    if (id.startsWith('car:songs/') || id.startsWith('car:instrumental/')) {
      final instrumental = id.startsWith('car:instrumental/');
      final source = id.split('/').last;
      final items = (await _songs()).where((s) => s.source == source);
      // Page larger libraries so a car never receives a thousand siblings.
      return _songPages(id, items.toList(), instrumental);
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
      return [
        for (final topic in sermons.map((s) => s.topic).toSet())
          folder('car:topic/${Uri.encodeComponent(topic)}', topic)
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
      String parent, List<Song> songs, bool instrumental) {
    final items = _songItems(songs, instrumental);
    if (items.length <= 60) return items;
    final source = parent.split('/').last;
    return [
      for (var i = 0; i < items.length; i += 60)
        folder('car:page/${instrumental ? "instrumental" : "vocal"}/$source/$i',
            '${i + 1}–${(i + 60).clamp(0, items.length)}')
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
