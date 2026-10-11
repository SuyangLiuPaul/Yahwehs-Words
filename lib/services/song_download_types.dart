/// Shared vocabulary for offline downloads.
///
/// Kept separate from the implementations so both the dart:io one and
/// the web stub can speak it — the UI imports only this plus the
/// conditional façade, and never a platform-specific file directly.
library;

import '../models/song.dart';

/// What a song's audio is doing right now.
enum SongDownloadState { none, queued, paused, downloading, done, failed }

/// Classifies a batch without modifying saved files or queued downloads.
/// An empty pending batch is not evidence that the device has no downloads.
class SongDownloadBatchPlan {
  final List<Song> pending;
  final int playableCount;
  final int queuedCount;

  factory SongDownloadBatchPlan(Iterable<Song> selection,
      {required bool Function(Song) isDownloaded,
      required SongDownloadStatus Function(Song) statusOf}) {
    final pending = <Song>[];
    final seen = <String>{};
    var playableCount = 0;
    var queuedCount = 0;
    for (final song in selection) {
      if (!song.hasPlayableAudio || !seen.add(song.id)) continue;
      playableCount++;
      if (isDownloaded(song)) continue;
      final status = statusOf(song);
      if (status.isBusy || status.state == SongDownloadState.paused) {
        queuedCount++;
      } else {
        pending.add(song);
      }
    }
    return SongDownloadBatchPlan._(
        List.unmodifiable(pending), playableCount, queuedCount);
  }

  const SongDownloadBatchPlan._(
      this.pending, this.playableCount, this.queuedCount);

  String get emptyMessageKey => playableCount == 0
      ? 'songsNoDownloadableAudio'
      : queuedCount > 0
          ? 'songsDownloadsAlreadyQueued'
          : 'songsDownloadsAlreadySaved';
}

/// A song's offline status, as the UI needs to render it.
class SongDownloadStatus {
  final SongDownloadState state;

  /// 0.0–1.0 while [SongDownloadState.downloading]; null when the
  /// server sends no Content-Length and progress is unknowable.
  final double? progress;

  /// Bytes on disk once [SongDownloadState.done].
  final int bytes;

  /// Why it failed, for the retry affordance.
  final String? error;

  const SongDownloadStatus({
    this.state = SongDownloadState.none,
    this.progress,
    this.bytes = 0,
    this.error,
  });

  bool get isDone => state == SongDownloadState.done;
  bool get isBusy =>
      state == SongDownloadState.queued ||
      state == SongDownloadState.downloading;
}

/// Human-readable size. Shared so the estimate shown before a download
/// and the total shown after it are formatted identically.
String formatDownloadBytes(int bytes) {
  if (bytes <= 0) return '0 MB';
  const mb = 1024 * 1024;
  if (bytes < mb) return '${(bytes / 1024).round()} KB';
  if (bytes < 1024 * mb) return '${(bytes / mb).round()} MB';
  return '${(bytes / (1024 * mb)).toStringAsFixed(1)} GB';
}

/// Public catalogue fields required to recover an interrupted song download.
Map<String, dynamic> songQueueRecord(Song song) => {
      'id': song.id,
      'title': song.title,
      'language': song.language,
      'source': song.source,
      'sourceLabel': song.sourceLabel,
      'url': song.url,
      'audioUrl': song.audioUrl ??
          (song.audioTracks.isNotEmpty ? song.audioTracks.first.url : null),
      'scoreUrl': song.scoreUrl,
      'artworkUrl': song.artworkUrl,
      'durationSec': song.durationSec,
    };
