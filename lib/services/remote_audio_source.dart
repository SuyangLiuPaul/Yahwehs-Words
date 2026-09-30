import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';

/// A second player can share the one OS session without losing its own
/// resume/tape-side logic. The source that owns focus owns remote commands.
abstract interface class RemoteAudioSource implements Listenable {
  MediaItem? get remoteItem;
  PlaybackState get remoteState;
  Future<void> remotePlay();
  Future<void> remotePause();
  Future<void> remoteStop();
  Future<void> remoteSeek(Duration position);
  Future<void> remoteForward();
  Future<void> remoteBackward();
}
