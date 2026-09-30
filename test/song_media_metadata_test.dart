import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahwehs_words/models/song.dart';
import 'package:yahwehs_words/models/song_queue.dart';
import 'package:yahwehs_words/services/media_companion_service.dart';
import 'package:yahwehs_words/services/remote_audio_source.dart';
import 'package:yahwehs_words/services/song_audio_handler.dart';

import 'support/fake_song_playback_engine.dart';

Song song(String id, {int? seconds}) => Song(
      id: id,
      title: id,
      language: 'en',
      source: 'cdc',
      sourceLabel: 'CDC',
      url: 'https://example.test/$id',
      audioUrl: 'https://example.test/$id.mp3',
      durationSec: seconds,
      audioTracks: [
        SongTrackInfo(url: 'https://example.test/$id.mp3', kind: 'vocal'),
        SongTrackInfo(
            url: 'https://example.test/$id-instrumental.mp3',
            kind: 'instrumental'),
      ],
      themes: const [],
    );

class SermonSource extends ChangeNotifier implements RemoteAudioSource {
  @override
  MediaItem get remoteItem => const MediaItem(
      id: 'car:sermon/004', title: 'Sermon', duration: Duration(seconds: 3600));
  @override
  PlaybackState get remoteState => PlaybackState(
      processingState: AudioProcessingState.ready,
      updatePosition: const Duration(seconds: 300));
  @override
  Future<void> remotePlay() async {}
  @override
  Future<void> remotePause() async {}
  @override
  Future<void> remoteStop() async {}
  @override
  Future<void> remoteSeek(Duration position) async {}
  @override
  Future<void> remoteForward() async {}
  @override
  Future<void> remoteBackward() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> close(SongAudioHandler handler, WidgetTester tester) async {
    // BaseAudioHandler.stop waits for the real OS bridge in widget tests.
    // Its synchronous first line still cancels our stall watchdog.
    unawaited(handler.stop());
    await tester.pump();
    await handler.dispose();
  }

  testWidgets(
      'decoded active duration reaches OS queue and watch snapshot without leaking to siblings',
      (tester) async {
    final engine = FakeSongPlaybackEngine();
    final handler = SongAudioHandler(engine: engine);
    await handler.setQueue(SongQueue.fromSongs([
      song('current'),
      song('unknown'),
      song('known', seconds: 240),
    ]));
    expect(handler.mediaItem.value?.duration, isNull);

    engine.emitDuration(const Duration(seconds: 123));
    engine.emitPosition(const Duration(seconds: 17));
    await tester.pump();

    expect(handler.duration, const Duration(seconds: 123));
    expect(handler.mediaItem.value?.duration, handler.duration);
    expect(handler.queue.value.map((item) => item.duration).toList(), [
      const Duration(seconds: 123),
      null,
      const Duration(seconds: 240),
    ]);
    final snapshot = MediaCompanionService.snapshotFor(handler);
    expect(snapshot['duration'], 123);
    expect(snapshot['position'], 17);
    expect(snapshot['syncedAt'], greaterThan(0));
    await close(handler, tester);
  });

  testWidgets(
      'decoded duration overrides catalog estimate and resets on next track, mix and stop',
      (tester) async {
    final engine = FakeSongPlaybackEngine();
    final handler = SongAudioHandler(engine: engine);
    await handler.setQueue(
        SongQueue.fromSongs([song('estimated', seconds: 180), song('next')]));
    engine.emitDuration(const Duration(seconds: 201));
    await tester.pump();
    expect(handler.mediaItem.value?.duration, const Duration(seconds: 201));

    await handler.playAt(1);
    expect(handler.duration, Duration.zero);
    expect(handler.mediaItem.value?.duration, isNull);
    expect(handler.queue.value.first.duration, const Duration(seconds: 180));
    engine.emitDuration(const Duration(seconds: 130));
    await tester.pump();
    expect(handler.mediaItem.value?.duration, const Duration(seconds: 130));

    await handler.setTrackPreference(
        TrackPreference.instrumental, TrackFallback.skip);
    expect(handler.mediaItem.value?.id, contains('instrumental'));
    expect(handler.mediaItem.value?.duration, isNull);
    engine.emitDuration(const Duration(seconds: 110));
    await tester.pump();
    expect(handler.mediaItem.value?.duration, const Duration(seconds: 110));
    unawaited(handler.stop());
    await tester.pump();
    expect(handler.duration, Duration.zero);
    expect(handler.mediaItem.value?.duration, isNull);
    await handler.dispose();
  });

  testWidgets('an unplayed replacement queue cannot inherit a decoded length',
      (tester) async {
    final engine = FakeSongPlaybackEngine();
    final handler = SongAudioHandler(engine: engine);
    await handler.setQueue(SongQueue.fromSongs([song('old')]));
    engine.emitDuration(const Duration(seconds: 123));
    await tester.pump();
    await handler.setQueue(SongQueue.fromSongs([song('replacement')]),
        autoPlay: false);
    expect(handler.duration, Duration.zero);
    expect(handler.mediaItem.value?.duration, isNull);
    expect(handler.queue.value.single.duration, isNull);
    await close(handler, tester);
  });

  testWidgets(
      'companion samples projected live position and leaves paused position fixed',
      (tester) async {
    final handler = SongAudioHandler(engine: FakeSongPlaybackEngine());
    final sampleTime =
        PlaybackState().updateTime.subtract(const Duration(seconds: 3));
    handler.playbackState.add(PlaybackState(
      processingState: AudioProcessingState.ready,
      playing: true,
      updatePosition: const Duration(seconds: 17),
      updateTime: sampleTime,
    ));
    expect(MediaCompanionService.snapshotFor(handler)['position'], 20);
    handler.playbackState.add(PlaybackState(
      processingState: AudioProcessingState.ready,
      updatePosition: const Duration(seconds: 17),
      updateTime: sampleTime,
    ));
    expect(MediaCompanionService.snapshotFor(handler)['position'], 17);
    await handler.dispose();
  });

  testWidgets('sermon metadata retains its own overall duration after songs',
      (tester) async {
    final engine = FakeSongPlaybackEngine();
    final handler = SongAudioHandler(engine: engine);
    await handler.setQueue(SongQueue.fromSongs([song('old')]));
    engine.emitDuration(const Duration(seconds: 123));
    await tester.pump();
    final sermon = SermonSource();
    handler.attachRemote(sermon);
    engine.emitDuration(const Duration(seconds: 124));
    await tester.pump();
    final snapshot = MediaCompanionService.snapshotFor(handler);
    expect(snapshot['duration'], 3600);
    expect(snapshot['position'], 300);
    expect(snapshot['sermon'], true);
    await handler.dispose();
    sermon.dispose();
  });
}
