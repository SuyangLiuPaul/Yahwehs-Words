import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahwehs_words/services/remote_audio_source.dart';
import 'package:yahwehs_words/services/song_audio_handler.dart';
import 'package:yahwehs_words/services/car_audio_catalogue.dart';
import 'support/fake_song_playback_engine.dart';

class FakeRemoteAudio extends ChangeNotifier implements RemoteAudioSource {
  final calls = <String>[];
  void emit() => notifyListeners();
  bool get listening => hasListeners;
  @override
  MediaItem? get remoteItem =>
      const MediaItem(id: 'car:sermon/001', title: 'Sermon');
  @override
  PlaybackState get remoteState => PlaybackState(controls: [
        MediaControl.rewind,
        MediaControl.play,
        MediaControl.fastForward
      ], processingState: AudioProcessingState.ready, playing: false);
  @override
  Future<void> remotePlay() async {
    calls.add('play');
  }

  @override
  Future<void> remotePause() async {
    calls.add('pause');
  }

  @override
  Future<void> remoteStop() async {
    calls.add('stop');
  }

  @override
  Future<void> remoteSeek(Duration p) async {
    calls.add('seek:${p.inSeconds}');
  }

  @override
  Future<void> remoteForward() async {
    calls.add('forward');
  }

  @override
  Future<void> remoteBackward() async {
    calls.add('backward');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('the active sermon owns system controls, including skip and seek',
      () async {
    final h = SongAudioHandler(engine: FakeSongPlaybackEngine());
    final remote = FakeRemoteAudio();
    h.attachRemote(remote);
    expect(h.mediaItem.value?.id, 'car:sermon/001');
    await h.play();
    await h.pause();
    await h.seek(const Duration(seconds: 90));
    await h.skipToNext();
    await h.skipToPrevious();
    await h.fastForward();
    await h.rewind();
    await h.stop();
    expect(remote.calls, [
      'play',
      'pause',
      'seek:90',
      'forward',
      'backward',
      'forward',
      'backward',
      'stop'
    ]);
    await h.dispose();
    remote.dispose();
  });
  test('returning to hymns removes the sermon listener and stale metadata',
      () async {
    final h = SongAudioHandler(engine: FakeSongPlaybackEngine());
    final first = FakeRemoteAudio();
    final second = FakeRemoteAudio();
    h.attachRemote(first);
    h.attachRemote(first);
    h.attachRemote(second);
    expect(first.listening, isFalse);
    expect(second.listening, isTrue);
    h.useSongs();
    expect(second.listening, isFalse);
    expect(h.mediaItem.value, isNull);
    second.emit();
    expect(h.mediaItem.value, isNull);
    await h.dispose();
    first.dispose();
    second.dispose();
  });
  test('malformed car pages return no children instead of throwing', () async {
    for (final id in [
      'car:page/',
      'car:page/vocal/source/nope',
      'car:page/vocal/source/-1',
      'car:page/other/source/0'
    ]) {
      expect(await CarAudioCatalogue.children(id), isEmpty);
    }
    await CarAudioCatalogue.play('car:song/');
  });
}
