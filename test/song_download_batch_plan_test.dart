import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yahwehs_words/constants/ui_strings.dart';
import 'package:yahwehs_words/models/song.dart';
import 'package:yahwehs_words/services/song_download_types.dart';

Song entry(String id, {bool audio = true}) => Song(
    id: id,
    title: id,
    language: 'en',
    source: 'cdc',
    sourceLabel: 'CDC',
    url: 'https://example.test/$id',
    audioUrl: audio ? 'https://example.test/$id.mp3' : null,
    themes: const []);

void main() {
  test('actual catalogue: separate stores with 575 or 12 ready records differ',
      () {
    final data =
        jsonDecode(File('assets/songs.json').readAsStringSync()) as Map;
    final songs = (data['songs'] as List)
        .map((row) => Song.fromJson((row as Map).cast<String, dynamic>()))
        .toList();
    final downloadable = songs.where((s) => s.hasPlayableAudio).toList();
    // The catalogue is refreshed daily from yswords-data, so the exact
    // counts move; what this test guards is the shape of the plan.
    expect(songs.length, greaterThan(600));
    expect(downloadable.length, greaterThan(500));
    expect(downloadable.length, lessThan(songs.length));
    final allSaved = downloadable.map((s) => s.id).toSet();
    final twelveSaved = downloadable.take(12).map((s) => s.id).toSet();
    final complete = SongDownloadBatchPlan(songs,
        isDownloaded: (s) => allSaved.contains(s.id),
        statusOf: (_) => const SongDownloadStatus());
    final separate = SongDownloadBatchPlan(songs,
        isDownloaded: (s) => twelveSaved.contains(s.id),
        statusOf: (_) => const SongDownloadStatus());
    expect(complete.pending, isEmpty);
    expect(complete.emptyMessageKey, 'songsDownloadsAlreadySaved');
    expect(separate.pending.length, downloadable.length - 12);
    expect(separate.pending.any((s) => twelveSaved.contains(s.id)), false);
  });
  test('575 saved and 55 link-only songs do not mean no downloads', () {
    final songs = [
      for (var i = 0; i < 575; i++) entry('saved-$i'),
      for (var i = 0; i < 55; i++) entry('link-$i', audio: false),
    ];
    final plan = SongDownloadBatchPlan(songs,
        isDownloaded: (s) => s.id.startsWith('saved-'),
        statusOf: (_) =>
            const SongDownloadStatus(state: SongDownloadState.done));
    expect(plan.playableCount, 575);
    expect(plan.pending, isEmpty);
    expect(plan.emptyMessageKey, 'songsDownloadsAlreadySaved');
  });

  test('link-only selection has no downloadable audio, not no saved songs', () {
    final plan = SongDownloadBatchPlan([entry('link', audio: false)],
        isDownloaded: (_) => false,
        statusOf: (_) => const SongDownloadStatus());
    expect(plan.emptyMessageKey, 'songsNoDownloadableAudio');
    expect(plan.pending, isEmpty);
  });

  test('repeated entries are counted and offered once by stable song ID', () {
    final song = entry('repeat');
    final plan = SongDownloadBatchPlan([song, song],
        isDownloaded: (_) => false,
        statusOf: (_) => const SongDownloadStatus());
    expect(plan.playableCount, 1);
    expect(plan.pending, [song]);
    expect(() => plan.pending.add(song), throwsUnsupportedError);
  });

  test('12 saved plus 563 queued offers no second multi-GB batch', () {
    final songs = [
      for (var i = 0; i < 575; i++) entry('audio-$i'),
      for (var i = 0; i < 55; i++) entry('link-$i', audio: false),
    ];
    bool saved(Song s) =>
        s.hasPlayableAudio && int.parse(s.id.substring('audio-'.length)) < 12;
    final plan = SongDownloadBatchPlan(songs,
        isDownloaded: saved,
        statusOf: (s) => SongDownloadStatus(
            state:
                saved(s) ? SongDownloadState.done : SongDownloadState.queued));
    expect(plan.pending, isEmpty);
    expect(plan.queuedCount, 563);
    expect(plan.emptyMessageKey, 'songsDownloadsAlreadyQueued');
  });

  test('saved, queued, downloading and paused entries are not re-enqueued', () {
    final states = {
      'saved': SongDownloadState.done,
      'queued': SongDownloadState.queued,
      'active': SongDownloadState.downloading,
      'paused': SongDownloadState.paused,
    };
    final plan = SongDownloadBatchPlan(states.keys.map(entry),
        isDownloaded: (s) => s.id == 'saved',
        statusOf: (s) => SongDownloadStatus(state: states[s.id]!));
    expect(plan.pending, isEmpty);
    expect(plan.queuedCount, 3);
    expect(plan.emptyMessageKey, 'songsDownloadsAlreadyQueued');
  });

  test('only missing and failed audio is offered for download', () {
    final songs = [
      entry('saved'),
      entry('active'),
      entry('failed'),
      entry('new'),
      entry('video', audio: false),
    ];
    final plan = SongDownloadBatchPlan(songs,
        isDownloaded: (s) => s.id == 'saved',
        statusOf: (s) => SongDownloadStatus(
            state: s.id == 'active'
                ? SongDownloadState.downloading
                : s.id == 'failed'
                    ? SongDownloadState.failed
                    : SongDownloadState.none));
    expect(plan.pending.map((s) => s.id), ['failed', 'new']);
    expect(plan.playableCount, 4);
    expect(plan.queuedCount, 1);
  });

  for (final locale in ['en', 'zh-Hans', 'zh-Hant']) {
    for (final key in [
      'songsDownloadsAlreadySaved',
      'songsDownloadsAlreadyQueued',
      'songsNoDownloadableAudio'
    ]) {
      test('$locale $key differs from the genuinely empty download list', () {
        expect(uiStrings[key]?[locale], isNotEmpty);
        expect(uiStrings[key]?[locale],
            isNot(uiStrings['songsNoDownloads']?[locale]));
      });
    }
  }
}
