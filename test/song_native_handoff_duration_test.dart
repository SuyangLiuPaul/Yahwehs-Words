import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahwehs_words/services/playback/song_playback_engine_native.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const codec = StandardMethodCodec();
  const players = MethodChannel('xyz.luan/audioplayers');
  const global = MethodChannel('xyz.luan/audioplayers.global');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Map<String, int> durations;
  Completer<int?>? heldDuration;
  Completer<void>? nextResume;
  var failResume = false;
  final stopped = <String>[];
  final created = <String>[];

  Future<void> event(String id, String event, Object value) async {
    await messenger.handlePlatformMessage('xyz.luan/audioplayers/events/$id',
        codec.encodeSuccessEnvelope({'event': event, 'value': value}), (_) {});
  }

  setUp(() {
    durations = {};
    heldDuration = null;
    nextResume = null;
    failResume = false;
    stopped.clear();
    created.clear();
    messenger.setMockMethodCallHandler(global, (_) async => null);
    messenger.setMockMethodCallHandler(players, (call) async {
      final args = call.arguments as Map;
      final id = args['playerId'] as String;
      if (call.method == 'create') {
        created.add(id);
        messenger.setMockMethodCallHandler(
            MethodChannel('xyz.luan/audioplayers/events/$id'),
            (_) async => null);
      } else if (call.method == 'setSourceUrl') {
        durations[id] =
            args['url'] == 'https://example.org/next.mp3' ? 123000 : 80000;
        await event(id, 'audio.onDuration', durations[id]!);
        await event(id, 'audio.onPrepared', true);
      } else if (call.method == 'getDuration') {
        return heldDuration?.future ?? durations[id];
      } else if (call.method == 'getCurrentPosition') {
        return 0;
      } else if (call.method == 'resume' && failResume) {
        throw PlatformException(code: 'resume_failed');
      } else if (call.method == 'resume' && nextResume != null) {
        final held = nextResume!;
        nextResume = null;
        await held.future;
      } else if (call.method == 'stop') {
        stopped.add(id);
      }
      return null;
    });
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(global, null);
    messenger.setMockMethodCallHandler(players, null);
  });

  test(
      'standby duration is hidden until successful handoff, even without a resume event',
      () async {
    final engine = SongPlaybackEngine();
    final values = <Duration>[];
    final subscription = engine.onDuration.listen(values.add);
    await engine.play('https://example.org/first.mp3');
    await Future<void>.delayed(Duration.zero);
    values.clear();
    await engine.preload('https://example.org/next.mp3');
    await Future<void>.delayed(Duration.zero);
    expect(values, isEmpty);
    await engine.play('https://example.org/next.mp3');
    await Future<void>.delayed(Duration.zero);
    expect(values, [const Duration(seconds: 123)]);
    await subscription.cancel();
    await engine.dispose();
  });

  test(
      'late handoff duration cannot overwrite a newer track on the same player',
      () async {
    final engine = SongPlaybackEngine();
    final values = <Duration>[];
    final subscription = engine.onDuration.listen(values.add);
    await engine.play('https://example.org/first.mp3');
    await engine.preload('https://example.org/next.mp3');
    heldDuration = Completer<int?>();
    final handoff = engine.play('https://example.org/next.mp3');
    await handoff; // Metadata discovery must not hold playback loading.
    await Future<void>.delayed(Duration.zero);
    await engine.play('https://example.org/third.mp3');
    await Future<void>.delayed(Duration.zero);
    values.clear();
    heldDuration!.complete(123000);
    await handoff;
    await Future<void>.delayed(Duration.zero);
    expect(values, isEmpty);
    await subscription.cancel();
    await engine.dispose();
  });

  test('failed standby resume stops old audio and reports its attempt',
      () async {
    final engine = SongPlaybackEngine();
    final errors = <(int, String)>[];
    final subscription = engine.onError.listen(errors.add);
    await engine.play('https://example.org/first.mp3');
    await engine.preload('https://example.org/next.mp3');
    failResume = true;
    await engine.play('https://example.org/next.mp3');
    await Future<void>.delayed(Duration.zero);
    expect(stopped, contains(created.first));
    expect(errors.single.$1, engine.attempt);
    await subscription.cancel();
    await engine.dispose();
  });
  test('late resume stops prior sounding player after a newer play attempt',
      () async {
    final engine = SongPlaybackEngine();
    await engine.play('https://example.org/first.mp3');
    await engine.preload('https://example.org/next.mp3');
    final held = nextResume = Completer<void>();
    final handoff = engine.play('https://example.org/next.mp3');
    await Future<void>.delayed(Duration.zero);
    await engine.play('https://example.org/third.mp3');
    held.complete();
    await handoff;
    await Future<void>.delayed(Duration.zero);
    expect(stopped, contains(created.first));
    await engine.dispose();
  });

  test('late resume preserves a prior player repurposed for another preload',
      () async {
    final engine = SongPlaybackEngine();
    await engine.play('https://example.org/first.mp3');
    await engine.preload('https://example.org/next.mp3');
    final held = nextResume = Completer<void>();
    final handoff = engine.play('https://example.org/next.mp3');
    await Future<void>.delayed(Duration.zero);
    await engine.preload('https://example.org/third.mp3');
    held.complete();
    await handoff;
    await Future<void>.delayed(Duration.zero);
    expect(stopped, isNot(contains(created.first)));
    await engine.dispose();
  });
}
