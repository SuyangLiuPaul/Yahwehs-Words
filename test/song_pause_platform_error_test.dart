// 2026-10-03: Android's MediaPlayer reports `MEDIA_ERROR_UNKNOWN {what:-38}`
// when pause() lands on a player that has left the started state. For songs
// that escaped as an uncaught PlatformException; a pause that cannot reach
// the player must read as paused, not crash.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:yahwehs_words/models/song.dart';
import 'package:yahwehs_words/models/song_queue.dart';
import 'package:yahwehs_words/services/song_audio_handler.dart';

import 'support/fake_song_playback_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Song song(String id) => Song(
        id: id,
        title: id,
        language: 'zh',
        source: 'cgdc',
        sourceLabel: 'CGDC',
        url: 'https://example.test/$id',
        audioUrl: 'https://example.test/$id.mp3',
        audioTracks: [
          SongTrackInfo(url: 'https://example.test/$id.mp3', kind: 'vocal'),
        ],
        themes: const [],
      );

  testWidgets('pause hitting Android -38 does not throw', (tester) async {
    final engine = FakeSongPlaybackEngine();
    final handler = SongAudioHandler(engine: engine);
    await handler.setQueue(SongQueue.fromSongs([song('s0')]), autoPlay: false);
    unawaited(handler.playAt(0));
    for (var i = 0; i < 10; i++) {
      await tester.pump();
    }
    engine.throwPlatformOnPause = true;
    await handler.pause();
  });
}
