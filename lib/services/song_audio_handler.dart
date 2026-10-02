import 'dart:async';
import 'remote_audio_source.dart';
import 'car_audio_catalogue.dart';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';

import 'package:yahwehs_words/models/song.dart';
import 'package:yahwehs_words/models/song_queue.dart';
import 'package:yahwehs_words/services/playback/song_playback_engine.dart';

/// Bridges the song queue to the platform media session.
///
/// audio_service owns the parts a plain player cannot reach: the iOS
/// AVAudioSession and now-playing info (lock screen, Control Center,
/// CarPlay), the Android foreground service and media notification
/// (including Android Auto and steering-wheel buttons), and the Media
/// Session API on web. audioplayers stays the actual playback engine
/// underneath — this class translates between the two.
///
/// Why wrap rather than migrate: audioplayers already covers all six
/// targets this app ships to. just_audio would have needed a separate
/// media-kit backend for Windows and Linux, for no gain here.
class SongAudioHandler extends BaseAudioHandler with SeekHandler {
  /// [engine] is a test seam: production call sites pass nothing and
  /// get the real platform engine, and a test can inject a fake that
  /// implements the same public surface with no audio plugin and no
  /// network. See test/song_auto_advance_test.dart.
  SongAudioHandler({SongPlaybackEngine? engine})
      : _player = engine ?? SongPlaybackEngine() {
    _player.onPlaying.listen((playing) {
      _playing = playing;
      _broadcast();
    });
    _player.onDuration.listen((d) {
      _duration = d;
      // Restore the position carried across a mix change, now that the
      // new file is long enough to seek into. Doing it before the
      // duration is known just gets clamped back to zero.
      final resume = _resumeAt;
      if (resume != null) {
        _resumeAt = null;
        if (resume > Duration.zero && resume < d) {
          unawaited(seek(resume));
        }
      }
      // Real data arrived — this track is alive.
      if (d > Duration.zero) _cancelStallWatchdog();
      _broadcast();
      _publishMediaItem();
      unawaited(_publishQueue());
    });
    _player.onPosition.listen((p) {
      if (p > Duration.zero) _cancelStallWatchdog();
      _position = p;
      _maybePreloadNext(p);
      _broadcast();
    });
    // Auto-advance. Fires only on a natural end — not on stop() or
    // pause() — so this cannot loop on user-initiated stops.
    _player.onComplete.listen((_) => _onTrackFinished());
    // Web reports playback failures asynchronously from the element,
    // long after play() returned, so they arrive here rather than as
    // a thrown exception. On native, `_guard` (song_playback_engine_
    // native.dart) funnels EVERY guarded command's failure through
    // this exact same stream — play, resume, pause, stop, seek and
    // setVolume alike — so this listener cannot tell "the track is
    // dead" apart from "the user's pause failed" by the message alone.
    _player.onError.listen((event) {
      if (_remote != null) return;
      final (attempt, message) = event;
      // Discard an error that belongs to a play() attempt this handler
      // has already moved past — see `_playCurrent`, which records
      // `_currentAttempt` right after issuing play(). This closes the
      // misattribution this comment used to describe (playAt(0) starts
      // loading A; before A's error arrives the user or auto-advance
      // moves to B; A's error used to land here and get blamed on B).
      // It does NOT close every stale-error race: an error that
      // arrives late for the SAME track that is still current — one
      // that went alive then died, for instance — carries the current
      // id and is not filtered by this check.
      if (attempt != _currentAttempt) return;
      _error = message;
      _loading = false;
      _broadcast();
      if (message.contains('[audio-focus]')) {
        _durationUrl = null;
        _cancelStallWatchdog();
        return; // A call is not a broken recording; retain the whole queue.
      }
      // A track that already produced real position or duration — the
      // same "is this track alive" signal _armStallWatchdog trusts —
      // is not the one that just failed to start; some other command
      // (pause/stop/seek) failed on a perfectly good track, and
      // skipping here would move the music on out from under a user
      // who only pressed pause. 2026-08-16, "为什么一首歌完了下首歌
      // 没有继续播放而是停住了": quarantining and skipping only a
      // track that never proved itself alive is also what lets a
      // queue of genuinely dead tracks terminate — see
      // docs/autonomous-queue.md:7636.
      if (_duration > Duration.zero || _position > Duration.zero) return;
      final item = _queue.current;
      if (item != null) _failed.add(item.song.id);
      _skipPastFailure();
    });

    // ignore: unawaited_futures
    _configureSession();
  }

  /// Declare this app as a music player to the OS.
  ///
  /// Without an explicit category, iOS treats the audio as ambient and
  /// **the physical Ring/Silent switch mutes it** — playback keeps
  /// running, the position advances, the lock screen shows controls,
  /// and no sound comes out. That exact symptom was reported from an
  /// iPhone with the silent switch on. `AVAudioSessionCategory.playback`
  /// is what every music app uses to keep playing regardless of the
  /// switch, and it is also what permits audio to continue while the
  /// screen is locked.
  ///
  /// `usage: media` + `contentType: music` on Android does the
  /// equivalent: routes to the media volume stream rather than the
  /// notification one, so the volume keys adjust the right thing.
  ///
  /// Note this cannot help the WEB build — a browser page has no
  /// audio-session category to set, so on iOS Safari/Chrome the silent
  /// switch mutes web audio and nothing in our code can override it.
  /// That is a platform rule, and one more reason the native app is
  /// the answer for listening while driving.
  Future<void> _configureSession() async {
    if (kIsWeb) return;
    try {
      final session = await AudioSession.instance;
      await _interruptions?.cancel();
      await _noisyRoute?.cancel();
      _interruptions = session.interruptionEventStream.listen(
          (event) => _queueSessionEvent(() => _handleInterruption(event)));
      _noisyRoute = session.becomingNoisyEventStream
          .listen((_) => _queueSessionEvent(() async {
                _resumeAfterInterruption = false;
                await pause();
              }));
      await session.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          usage: AndroidAudioUsage.media,
        ),
        // Pause during audio interruptions and recover only when the
        // system grants focus again.
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: false,
      ));
    } catch (e) {
      // A misconfigured session must not stop playback from working
      // at all; it only costs the silent-switch override.
      debugPrint('[SongAudioHandler] audio session config failed: $e');
    }
  }

  StreamSubscription<AudioInterruptionEvent>? _interruptions;
  StreamSubscription<void>? _noisyRoute;
  bool _interrupted = false;
  bool _resumeAfterInterruption = false;
  RemoteAudioSource? _interruptedSource;
  String? _interruptedItem;
  Future<void> _sessionEvents = Future.value();

  void _queueSessionEvent(Future<void> Function() action) {
    _sessionEvents =
        _sessionEvents.then((_) => action()).catchError((Object error) {
      debugPrint('[SongAudioHandler] session event failed: $error');
    });
  }

  Future<void> _handleInterruption(AudioInterruptionEvent event) async {
    // Both songs and sermons feed one session. A call must not leave the
    // phone claiming playback after the OS has silenced the audio route.
    if (event.begin) {
      if (!_interrupted) {
        _resumeAfterInterruption = playbackState.value.playing;
        _interruptedSource = _remote;
        _interruptedItem = mediaItem.valueOrNull?.id;
      }
      _interrupted = true;
      _playing = false;
      _broadcast();
      await (_remote?.remotePause() ?? _player.pause());
    } else {
      _interrupted = false;
      final resume = _resumeAfterInterruption &&
          event.type != AudioInterruptionType.unknown &&
          identical(_remote, _interruptedSource) &&
          mediaItem.valueOrNull?.id == _interruptedItem;
      _resumeAfterInterruption = false;
      if (resume) await play();
    }
  }

  RemoteAudioSource? _remote;

  void attachRemote(RemoteAudioSource source) {
    if (!identical(_remote, source)) {
      _remote?.removeListener(_broadcast);
      _remote = source;
      source.addListener(_broadcast);
    }
    _broadcast();
  }

  Future<void> pauseSongForFocus() {
    _cancelStallWatchdog();
    return _player.pause();
  }

  void useSongs() {
    _remote?.removeListener(_broadcast);
    _remote = null;
    _publishMediaItem();
    unawaited(_publishQueue());
    _broadcast();
  }

  @override
  Future<List<MediaItem>> getChildren(String parentMediaId,
          [Map<String, dynamic>? options]) =>
      CarAudioCatalogue.children(parentMediaId);

  @override
  Future<void> playFromMediaId(String mediaId,
          [Map<String, dynamic>? extras]) =>
      CarAudioCatalogue.play(mediaId);

  @override
  Future<MediaItem?> getMediaItem(String mediaId) =>
      CarAudioCatalogue.item(mediaId);

  @override
  Future<List<MediaItem>> search(String query,
          [Map<String, dynamic>? extras]) =>
      CarAudioCatalogue.search(query);

  @override
  Future<void> playFromSearch(String query,
      [Map<String, dynamic>? extras]) async {
    final matches = await CarAudioCatalogue.search(query);
    if (matches.isNotEmpty) await playFromMediaId(matches.first.id);
  }

  @override
  Future<void> fastForward() =>
      _remote?.remoteForward() ?? seek(_position + const Duration(seconds: 30));

  @override
  Future<void> rewind() =>
      _remote?.remoteBackward() ??
      seek(_position > const Duration(seconds: 15)
          ? _position - const Duration(seconds: 15)
          : Duration.zero);

  final SongPlaybackEngine _player;

  /// Injected so this file stays free of the native-only download
  /// layer: given a song and its upstream URL, returns what to
  /// actually open (a local file when downloaded, else the proxied or
  /// direct URL). Wired in main.dart.
  static String? Function(Song song, String url)? sourceResolver;

  /// Native-only second chance: given the upstream URL of a track that
  /// just failed, returns a proxied URL to retry with, or null.
  ///
  /// 2026-08-23, "有些歌播放不了". Native streams DIRECTLY from the
  /// church hosts, and two of them (fydt.org and
  /// christiandiscipleschurch.org — same server) refuse connections
  /// they classify as datacenter traffic. The user's status bar in the
  /// report screenshots shows a VPN, whose exit is exactly that. So on
  /// the same phone, cgdc songs played while cdc/fydt songs sat at
  /// 0:00 until the stall watchdog killed them — "some songs won't
  /// play" with no pattern visible to the user.
  ///
  /// Wired in main.dart to SongPlayerService.nativeProxyFallbackUrl.
  /// Web never uses this: it ALWAYS goes through the proxy (see
  /// resolvePlaybackUrl), so a failure there is not about the route.
  static String? Function(String url)? proxyFallback;

  /// Songs already retried through the proxy this session — one retry
  /// each, so a genuinely dead file still fails promptly instead of
  /// looping between two routes.
  final Set<String> _proxyRetried = <String>{};

  /// Track-level URL overrides installed by the proxy retry.
  final Map<String, String> _proxyUrlFor = <String, String>{};

  SongQueue _queue = SongQueue.empty;
  bool _playing = false;
  bool _loading = false;
  String? _error;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  String? _durationUrl;

  /// The URL the engine has been asked to warm for the upcoming track,
  /// so the ask is made once per track and not on every `timeupdate`.
  /// Cleared whenever a track starts, because "next" has moved.
  String? _preloadedUrl;

  /// How far before the end of a track the next one is fetched.
  ///
  /// Long enough for a song-length file to arrive over a phone
  /// connection in a moving car; short enough that a listener who skips
  /// around a track does not have every neighbour fetched. Twenty
  /// seconds of a 3–4 minute song.
  static const Duration kPreloadLead = Duration(seconds: 20);

  /// Where a track's audio actually comes from, after the proxy fallback
  /// and the source resolver have had their say — one answer for
  /// [_playCurrent] and [_maybePreloadNext], so the warmed URL is the
  /// one that will be asked for.
  String _resolvedUrl(QueueItem item) {
    final baseUrl = _proxyUrlFor[item.song.id] ?? item.url;
    return sourceResolver?.call(item.song, baseUrl) ?? baseUrl;
  }

  /// Ask the engine to warm the next track once we are inside the lead
  /// window. See `SongPlaybackEngine.preload` (web) for why this exists.
  ///
  /// "Next" is what [_onTrackFinished] will actually play: nothing under
  /// repeat-one (the element loops — there is no next), the wrap-around
  /// under repeat-all, and nothing at the end of the queue otherwise. A
  /// track the queue has marked failed is skipped the same way
  /// [_skipPastFailure] would skip it.
  void _maybePreloadNext(Duration position) {
    final d = _duration;
    if (d <= Duration.zero || d - position > kPreloadLead) return;
    if (_queue.repeat == RepeatMode.one || _sleepAtEndOfTrack) return;
    final next = _queue.nextIndex();
    if (next == null || next == _queue.index) return;
    final item = _queue.items[next];
    if (_failed.contains(item.song.id)) return;
    final url = _resolvedUrl(item);
    if (_preloadedUrl == url) return;
    _preloadedUrl = url;
    unawaited(_player.preload(url));
  }

  Timer? _sleepTimer;
  DateTime? _sleepAt;

  /// "Pause when the current track ends" — no DateTime, because
  /// seeking, skipping or a track of unknown duration would desync one
  /// faked from the remaining position. A separate flag instead, read
  /// by [_onTrackFinished].
  bool _sleepAtEndOfTrack = false;

  /// Songs whose URL failed this session. Prevents an auto-advance
  /// loop: without it a queue of dead links would skip forward
  /// forever, hammering three church servers as it went.
  final Set<String> _failed = {};

  /// The [SongPlaybackEngine.attempt] id of the `play()` call this
  /// handler is currently trying — set right after issuing `play()`,
  /// so `onError`'s listener can drop an error whose id is older, i.e.
  /// one that belongs to a track already left behind.
  int _currentAttempt = 0;

  /// The song queue. Named `songQueue`, not `queue`, because
  /// BaseAudioHandler already owns `queue` as its BehaviorSubject of
  /// MediaItems — the OS-facing view of the same thing.
  SongQueue get songQueue => _queue;
  bool get isPlaying => _playing;
  bool get isLoading => _loading;
  String? get error => _error;
  Duration get position => _position;
  QueueItem? get currentItem => _queue.current;
  Song? get currentSong => _queue.current?.song;
  DateTime? get sleepAt => _sleepAt;
  bool get sleepAtEndOfTrack => _sleepAtEndOfTrack;

  Duration get duration {
    final item = _queue.current;
    return item == null
        ? Duration.zero
        : _itemDuration(item, active: true) ?? Duration.zero;
  }

  // ── Queue control ───────────────────────────────────────────────

  /// Replace the queue and start playing at its current index.
  ///
  /// Note the ORDER: playback starts before the queue is published to
  /// the OS. Publishing is an await, and on iOS web an await between
  /// the user's tap and the play call costs the gesture activation the
  /// Web Audio context needs — see [_playCurrent]. The OS queue is a
  /// display detail; sound is not.
  Future<void> setQueue(SongQueue next, {bool autoPlay = true}) async {
    _queue = next;
    _failed.clear();
    if (next.isEmpty) {
      await _publishQueue();
      await stop();
      return;
    }
    if (autoPlay) {
      final started = _playCurrent();
      await _publishQueue();
      await started;
    } else {
      await _publishQueue();
      _publishMediaItem();
      _broadcast();
    }
  }

  Future<void> playAt(int index) async {
    if (index < 0 || index >= _queue.length) return;
    _queue = _queue.copyWith(index: index);
    await _playCurrent();
  }

  static String remoteLocale = 'en';
  String _remoteText(String en, String hans, String hant) =>
      remoteLocale == 'zh-Hant'
          ? hant
          : remoteLocale.startsWith('zh')
              ? hans
              : en;

  @override
  Future<dynamic> customAction(String name,
      [Map<String, dynamic>? extras]) async {
    if (_remote != null || _queue.isEmpty) return null;
    if (name == 'words.shuffle' && extras?['on'] is bool) {
      await setShuffle(extras!['on'] as bool);
    } else if (name == 'words.repeat') {
      final modes = {
        'off': RepeatMode.off,
        'all': RepeatMode.all,
        'one': RepeatMode.one
      };
      final mode = modes[extras?['mode']];
      if (mode != null) await setRepeat(mode);
    }
    return null;
  }

  Future<void> setShuffle(bool on) async {
    // Repeated remote commands are idempotent and never reshuffle twice.
    if (_remote != null || _queue.shuffled == on) return;
    _queue = _queue.withShuffle(on,
        keepCurrent: _durationUrl == _queue.current?.url);
    await _publishQueue();
    _broadcast();
  }

  /// Queue a song without interrupting what is playing.
  ///
  /// [playNext] puts it directly after the current track; otherwise it
  /// goes on the end. If nothing is playing there is no queue to add
  /// to, so it simply starts.
  Future<void> addToQueue(Song song, {bool playNext = false}) async {
    final item = SongQueue.resolveTrack(
        song, TrackPreference.vocal, TrackFallback.useVocal);
    if (item == null) return;
    if (_queue.isEmpty) {
      await setQueue(SongQueue(items: [item], sourceLabel: song.sourceLabel));
      return;
    }
    _queue = _queue.insertAt(playNext ? _queue.index + 1 : _queue.length, item);
    await _publishQueue();
    _broadcast();
  }

  /// Drop one track from the queue.
  ///
  /// `SongQueue.removeAt` has existed with tests since the queue was
  /// built, with nothing able to call it — so a track you did not want
  /// stayed until the queue was rebuilt. Removing the track that is
  /// playing moves to the one that takes its place, which is what
  /// every player does; removing the last track stops.
  Future<void> removeFromQueue(int index) async {
    if (index < 0 || index >= _queue.length) return;
    final wasCurrent = index == _queue.index;
    final next = _queue.removeAt(index);
    if (next.isEmpty) {
      _queue = next;
      await _publishQueue();
      await stop();
      return;
    }
    _queue = next;
    if (wasCurrent) {
      await _playCurrent();
    }
    await _publishQueue();
    _broadcast();
  }

  Future<void> setRepeat(RepeatMode mode) async {
    _queue = _queue.copyWith(repeat: mode);
    await _syncLoop();
    _broadcast();
  }

  /// Push repeat-one down into the player, or take it back.
  ///
  /// Repeat-one used to live entirely here: wait for the track to end,
  /// `seek(0)`, `resume()`. That works while the app is on screen and
  /// fails in the background on iOS, because iOS keeps a backgrounded
  /// app scheduled only while it is actually producing audio — and the
  /// end-of-track event, by definition, arrives after the audio has
  /// stopped. The owner met it in a car with navigation in front:
  /// 「单曲循环…播完一次就停了」, and the song resumed on reopening the
  /// app, which is the signature of a suspended page rather than a lost
  /// one.
  ///
  /// Handing the repeat to the player (`<audio loop>` on web,
  /// ReleaseMode.loop natively) means the audio never stops, so there
  /// is no gap for the OS to suspend us in, and no event to miss.
  ///
  /// **Gated on [_sleepAtEndOfTrack].** Both engines stop reporting
  /// end-of-track while looping, and "stop at the end of this song" is
  /// built on exactly that report. Sleep therefore wins, which is the
  /// precedence [_onTrackFinished] already had for the same reason: a
  /// reader who asked for the music to stop meant it.
  Future<void> _syncLoop() =>
      _player.setLoop(_queue.repeat == RepeatMode.one && !_sleepAtEndOfTrack);

  /// Which mix the whole queue plays, changed mid-listen.
  /// Change the current song's recording without replacing its queue.
  /// Unsupported mixes are a no-op even for non-widget callers. Playlist
  /// preferences are resolved when the playlist is created, not here.
  Future<void> setTrackPreference(
    TrackPreference preference,
    TrackFallback fallback,
  ) async {
    final current = _queue.current;
    if (current == null || _loading || !_queue.hasCurrentMix(preference)) {
      return;
    }
    final next = _queue.withCurrentMix(preference);
    if (identical(next, _queue)) return;
    final wasPlaying = _playing;
    final resumeAt = _position;
    _queue = next;
    await _playCurrent(
        autoPlay: wasPlaying,
        resumeAt: resumeAt > Duration.zero ? resumeAt : null);
    await _publishQueue();
  }

  /// The mix the queue is currently set to, for the UI's highlighting.
  TrackPreference get preference => switch (_queue.current?.kind) {
        'instrumental' => TrackPreference.instrumental,
        'accompaniment' => TrackPreference.accompaniment,
        _ => TrackPreference.vocal,
      };
  TrackFallback get fallback => _fallback;
  final TrackFallback _fallback = TrackFallback.useVocal;

  /// Position to restore once the next track has loaded. Set only when
  /// swapping mixes mid-song.
  Duration? _resumeAt;

  /// Sleep timer — pauses playback at [at]. Passing null cancels.
  ///
  /// Also disarms "end of this song" ([setSleepAtEndOfTrack]) — only
  /// one sleep mode is armed at a time.
  void setSleepTimer(Duration? after) {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepAt = null;
    _sleepAtEndOfTrack = false;
    unawaited(_syncLoop());
    if (after == null) {
      _broadcast();
      return;
    }
    _sleepAt = DateTime.now().add(after);
    _sleepTimer = Timer(after, () async {
      _sleepAt = null;
      await pause();
    });
    _broadcast();
  }

  /// Arm or disarm pausing at the current track's natural end — see
  /// [_onTrackFinished]. Arming cancels any DateTime timer, same "one
  /// mode at a time" contract as [setSleepTimer].
  void setSleepAtEndOfTrack(bool on) {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepAt = null;
    _sleepAtEndOfTrack = on;
    unawaited(_syncLoop());
    _broadcast();
  }

  // ── audio_service contract ──────────────────────────────────────
  // These are what the lock screen, CarPlay, Android Auto, headset
  // buttons and the web Media Session actually call.

  @override
  Future<void> play() async {
    if (_interrupted) return;
    if (_remote != null) return _remote!.remotePlay();
    if (_queue.isEmpty) return;
    if (currentItem == null) return;
    _error = null;
    if (_durationUrl != currentItem!.url) {
      await _playCurrent(resumeAt: _position);
    } else {
      await _player.resume();
    }
  }

  @override
  Future<void> pause() {
    _resumeAfterInterruption = false;
    if (_remote != null) return _remote!.remotePause();
    // A user pause is not a stall; the watchdog would otherwise fire
    // on a track paused within 20s of starting.
    _cancelStallWatchdog();
    return _player.pause();
  }

  @override
  Future<void> stop() async {
    _resumeAfterInterruption = false;
    if (_remote != null) {
      await _remote!.remoteStop();
      _broadcast();
      return;
    }
    _cancelStallWatchdog();
    _sleepTimer?.cancel();
    _sleepAt = null;
    _sleepAtEndOfTrack = false;
    await _syncLoop();
    await _player.stop();
    _playing = false;
    _position = Duration.zero;
    _duration = Duration.zero;
    _durationUrl = null;
    _resumeAt = null;
    _publishMediaItem();
    unawaited(_publishQueue());
    _broadcast();
    await super.stop();
  }

  /// Stop AND put the player away: empties the queue so
  /// `SongPlayerService.current` becomes null and the mini-player strip
  /// leaves the screen.
  ///
  /// 2026-08-11, reported by the user — "如果我不想听了去其他页面底下還是
  /// 有播放器，一直在那里，但是每次退出才没有". They were right, and it
  /// was worse than it looked: the strip renders whenever
  /// `current != null` and **nothing in the app ever set that back to
  /// null**. [stop] halts playback but deliberately keeps the queue, and
  /// the strip's stop button only appeared when the queue held a single
  /// song. Play from a list — which is what every row's play button does
  /// — and there was no affordance anywhere to dismiss the player.
  /// Force-quitting really was the only way.
  ///
  /// Kept separate from [stop] on purpose: the sleep timer firing, or
  /// running off the end of a queue, should stop playback and KEEP the
  /// queue, because pressing play again is the likely next move. This is
  /// the explicit "I am done listening" gesture and only a user issues
  /// it.
  Future<void> dismiss() async {
    await stop();
    _queue = SongQueue.empty;
    _error = null;
    _loading = false;
    _broadcast();
    _publishMediaItem();
    // The OS track list too. CarPlay and Android Auto read this one,
    // and a dismissed player that still offers a list to jump around
    // in is the same defect the metadata had.
    unawaited(_publishQueue());
    notifyUi();
  }

  @override
  Future<void> seek(Duration position) =>
      _remote?.remoteSeek(position) ?? _player.seek(position);

  @override
  Future<void> skipToNext() async {
    if (_remote != null) return _remote!.remoteForward();
    final next = _queue.nextIndex(manual: true);
    if (next == null) {
      await stop();
      return;
    }
    _queue = _queue.copyWith(index: next);
    await _playCurrent();
  }

  @override
  Future<void> skipToPrevious() async {
    if (_remote != null) return _remote!.remoteBackward();
    // Standard media behaviour: past a few seconds in, "previous"
    // restarts the current track rather than leaving it.
    if (_position > const Duration(seconds: 3)) {
      await seek(Duration.zero);
      return;
    }
    final prev = _queue.previousIndex(manual: true);
    if (prev == null) {
      await seek(Duration.zero);
      return;
    }
    _queue = _queue.copyWith(index: prev);
    await _playCurrent();
  }

  @override
  Future<void> skipToQueueItem(int index) => playAt(index);

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    await setRepeat(switch (repeatMode) {
      AudioServiceRepeatMode.one => RepeatMode.one,
      AudioServiceRepeatMode.all ||
      AudioServiceRepeatMode.group =>
        RepeatMode.all,
      AudioServiceRepeatMode.none => RepeatMode.off,
    });
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) =>
      setShuffle(shuffleMode != AudioServiceShuffleMode.none);

  // ── Internals ───────────────────────────────────────────────────

  Future<void> _playCurrent({bool autoPlay = true, Duration? resumeAt}) async {
    if (_remote != null) useSongs();
    final item = _queue.current;
    if (item == null) return;

    // ── iOS web: play() MUST be reached with the user gesture still
    // valid. ────────────────────────────────────────────────────────
    //
    // audioplayers_web routes audio through the Web Audio API
    // (`createMediaElementSource` in wrapped_player.recreateNode), so
    // nothing is audible unless its AudioContext is running. It tries
    // to `resume()` that context — but iOS only permits
    // AudioContext.resume() inside a user gesture, and every `await`
    // between the tap and that call spends the activation.
    //
    // The symptom when it fails is precisely what was reported from an
    // iPhone: element.play() succeeds, currentTime advances, the media
    // session shows "playing", and there is no sound.
    //
    // So the play call is issued FIRST, synchronously, before any
    // state updates or notifications — and the future is awaited
    // afterwards. Everything below this line used to happen before it.
    _resumeAt = resumeAt;
    final resolved = _resolvedUrl(item);
    _preloadedUrl = null;
    // Reset before asking the engine to play: a new file must not
    // inherit the previous song/mix's decoded length in OS metadata.
    _position = Duration.zero;
    _duration = Duration.zero;
    _durationUrl = item.url;
    if (!autoPlay) _playing = false;
    final playing =
        autoPlay ? _player.play(resolved) : _player.loadPaused(resolved);
    _currentAttempt = _player.attempt;
    final attempt = _currentAttempt;
    // Applied per track, not once: the web element keeps `loop` across
    // sources, but the native player's release mode is reset by some
    // platform implementations when a new source is set.
    unawaited(_syncLoop());

    _loading = true;
    _error = null;
    _armStallWatchdog(item);
    _publishMediaItem();
    unawaited(_publishQueue());
    _broadcast();

    try {
      await playing;
      if (attempt != _currentAttempt) return;
      if (!autoPlay) _cancelStallWatchdog();
      _failed.remove(item.song.id);
    } on PlaybackBlockedException catch (e) {
      // The browser refused to START — not a bad track. Handled apart
      // from the dead-URL case below, which drops the song and
      // advances: doing that here would walk the whole queue, refuse
      // at every step for the same reason, mark all of them dead and
      // finish with silence and nothing left to play. Stop, say what
      // happened, and leave the song exactly where it is so one tap
      // resumes it.
      debugPrint('[SongAudioHandler] playback blocked: $e');
      _error = 'blocked';
      _loading = false;
      _playing = false;
      _broadcast();
      return;
    } catch (e) {
      // Before declaring the track dead, try the other route once.
      // A refused direct connection and a missing file look identical
      // from here; the proxy retry is what tells them apart.
      if (_tryProxyRetry(item, 'error: $e')) return;
      // One dead URL must not end the listening session. Drop it and
      // move on — the catalogue points at four third-party servers and
      // any of them can 404 between syncs.
      debugPrint('[SongAudioHandler] ${item.song.id} failed: $e');
      _failed.add(item.song.id);
      _error = e.toString();
      _loading = false;
      _broadcast();
      await _skipPastFailure();
      return;
    }
    _loading = false;
    _broadcast();
  }

  /// Fails a track that starts but never produces any audio.
  ///
  /// 2026-08-11, from the phone: "God's Sheepfold" sat at `0:00 / 5:54`
  /// with the pause button showing and nothing happening. The duration
  /// comes from the catalogue, so the row looks live while not one byte
  /// has arrived. It is a Christian Disciples Church song, and that
  /// host accepts no connection from their network.
  ///
  /// `await playing` cannot catch this. The platform sometimes throws
  /// (the DarwinAudioError report) and sometimes just accepts the
  /// source and waits forever, and the second case had no bound at
  /// all — no error, no skip, no message, indefinitely.
  ///
  /// Deliberately keyed on "no duration AND no position", not on a
  /// clock: a slow connection that is genuinely loading reports its
  /// duration almost immediately, so this cannot cut off a download
  /// that is merely slow.
  void _armStallWatchdog(QueueItem item) {
    _stallTimer?.cancel();
    _stallTimer = Timer(_stallTimeout, () {
      if (_duration > Duration.zero || _position > Duration.zero) return;
      final host = Uri.tryParse(item.url)?.host;
      debugPrint('[SongAudioHandler] ${item.song.id} produced no audio in '
          '${_stallTimeout.inSeconds}s (host: $host)');
      // The blocked-host case usually lands HERE, not in the catch:
      // the platform accepts the source and then nothing ever arrives.
      if (_tryProxyRetry(item, 'stall (host: $host)')) return;
      _failed.add(item.song.id);
      // The same wording the engines use for a failed source load, so
      // the mini-player's existing classifier reaches the "cannot reach
      // the server" message rather than "could not play that track".
      _error = 'failed to set source: no answer from ${host ?? item.url}';
      _loading = false;
      _playing = false;
      _broadcast();
      unawaited(_skipPastFailure());
    });
  }

  /// Retry [item] through the media proxy. True when a retry was
  /// started (the caller must not mark the track failed); false when
  /// there is nothing left to try.
  bool _tryProxyRetry(QueueItem item, String why) {
    final fallback = proxyFallback?.call(item.url);
    if (fallback == null) return false;
    if (_proxyRetried.contains(item.song.id)) return false;
    // A local download never gets here in the first place — the
    // resolver returns the file path and file playback does not fail
    // on network grounds.
    _proxyRetried.add(item.song.id);
    _proxyUrlFor[item.song.id] = fallback;
    debugPrint('[SongAudioHandler] ${item.song.id} $why — retrying '
        'through the media proxy');
    unawaited(_playCurrent());
    return true;
  }

  void _cancelStallWatchdog() {
    _stallTimer?.cancel();
    _stallTimer = null;
  }

  Timer? _stallTimer;

  /// Long enough that a slow-but-live start is never cut off, short
  /// enough that a dead host does not leave the user staring at 0:00.
  static const _stallTimeout = Duration(seconds: 20);

  Future<void> _skipPastFailure() async {
    // Every remaining track already failed → stop rather than spin.
    final playable =
        _queue.items.where((i) => !_failed.contains(i.song.id)).length;
    if (playable == 0) {
      await stop();
      return;
    }
    final next = _queue.nextIndex();
    if (next == null) {
      await stop();
      return;
    }
    _queue = _queue.copyWith(index: next);
    await _playCurrent();
  }

  Future<void> _onTrackFinished() async {
    if (_remote != null) return;
    // Checked before repeat-one: "end of this song" means pause, even
    // for a track set to repeat itself — it must not seek back to zero
    // and keep playing.
    if (_sleepAtEndOfTrack) {
      _sleepAtEndOfTrack = false;
      await pause();
      _broadcast();
      return;
    }
    if (_queue.repeat == RepeatMode.one) {
      await seek(Duration.zero);
      await _player.resume();
      return;
    }
    await skipToNext();
  }

  /// Publish the queue to the OS so CarPlay / Android Auto can show
  /// and jump around the track list, not just play/pause.
  Future<void> _publishQueue() async {
    if (_remote != null) return;
    queue.add([
      for (final entry in _queue.items.indexed)
        _toMediaItem(entry.$2, active: entry.$1 == _queue.index),
    ]);
  }

  void _publishMediaItem() {
    if (_remote != null) return;
    final item = _queue.current;
    // An empty queue publishes NULL, it does not return early.
    //
    // 2026-09-13, from the owner's iPhone lock screen: 「正在播放不是
    // 不用了吗放在那里」 — a card for 良善的神, paused at 0:00, still
    // sitting there after the player had been put away. `dismiss()`
    // empties the queue and calls this, and this returned without
    // touching `mediaItem`, so the OS kept the last metadata it was
    // given. `playbackState` was already reporting `idle`; metadata is
    // the half that draws the card, and nothing ever took it back.
    if (item == null) {
      mediaItem.add(null);
      return;
    }
    mediaItem.add(_toMediaItem(item, active: true));
  }

  Duration? _itemDuration(QueueItem item, {required bool active}) {
    if (active && item.url == _durationUrl && _duration > Duration.zero) {
      return _duration;
    }
    final seconds = item.song.durationSec;
    return seconds != null && seconds > 0 ? Duration(seconds: seconds) : null;
  }

  /// What the lock screen / CarPlay actually displays.
  MediaItem _toMediaItem(QueueItem item, {required bool active}) {
    final s = item.song;
    // Name the mix in the title when it is not the sung take, so a
    // glance at the lock screen says whether this is the instrumental.
    final suffix = switch (item.kind) {
      'instrumental' => ' (伴奏)',
      'accompaniment' => ' (伴唱)',
      _ => '',
    };
    return MediaItem(
      id: item.url,
      title: '${s.title}$suffix',
      artist: s.creditLine ?? s.sourceLabel,
      album: s.album ?? _queue.sourceLabel,
      duration: _itemDuration(item, active: active),
      artUri: s.artworkUrl == null
          ? Uri.parse('https://yahwehword.com/icons/Icon-512.png')
          : Uri.tryParse(s.artworkUrl!),
      extras: {'songId': s.id, 'kind': item.kind},
    );
  }

  /// Push transport state to the OS + any listening UI.
  void _broadcast() {
    final remote = _remote;
    if (remote != null) {
      mediaItem.add(remote.remoteItem);
      queue.add(remote.remoteItem == null ? [] : [remote.remoteItem!]);
      playbackState.add(remote.remoteState);
      notifyUi();
      return;
    }
    // Skip controls are offered whenever there is a queue at all, not
    // only when there is something on that side of it.
    //
    // Reported from an iPhone: the lock screen showed ⏪ ⏩ and neither
    // did anything. Two causes. (a) `MediaAction.seekForward` /
    // `seekBackward` were declared, and audio_service maps those to
    // MPRemoteCommandCenter's skipForward/skipBackward — but it only
    // attaches a handler when `fastForwardInterval` / `rewindInterval`
    // are non-zero, and this app never set them. So iOS was told the
    // app supports skip-by-interval and then given nothing to call:
    // buttons that render and do nothing. They are gone.
    // (b) previous/next were conditional on `hasPrevious`/`hasNext`, so
    // on the first track of a queue — or a one-song queue, which is
    // what the row play button used to build — the real ⏮ ⏭ were never
    // enabled at all, leaving only the dead pair.
    final multi = _queue.length > 1;
    playbackState.add(PlaybackState(
      controls: [
        if (multi) MediaControl.skipToPrevious,
        if (_playing) MediaControl.pause else MediaControl.play,
        if (multi) MediaControl.skipToNext,
        MediaControl.stop,
        if (_queue.isNotEmpty)
          MediaControl.custom(
              androidIcon: 'drawable/ic_shuffle',
              label: _remoteText(
                  _queue.shuffled ? 'Shuffle off' : 'Shuffle on',
                  _queue.shuffled ? '关闭随机' : '随机播放',
                  _queue.shuffled ? '關閉隨機' : '隨機播放'),
              name: 'words.shuffle',
              extras: {'on': !_queue.shuffled}),
        if (_queue.isNotEmpty)
          MediaControl.custom(
              androidIcon: _queue.repeat == RepeatMode.one
                  ? 'drawable/ic_repeat_one'
                  : 'drawable/ic_repeat',
              label: _remoteText(
                  _queue.repeat == RepeatMode.off
                      ? 'Repeat queue'
                      : _queue.repeat == RepeatMode.all
                          ? 'Repeat one'
                          : 'Repeat off',
                  _queue.repeat == RepeatMode.off
                      ? '列表循环'
                      : _queue.repeat == RepeatMode.all
                          ? '单曲循环'
                          : '关闭循环',
                  _queue.repeat == RepeatMode.off
                      ? '清單循環'
                      : _queue.repeat == RepeatMode.all
                          ? '單曲循環'
                          : '關閉循環'),
              name: 'words.repeat',
              extras: {
                'mode': _queue.repeat == RepeatMode.off
                    ? 'all'
                    : _queue.repeat == RepeatMode.all
                        ? 'one'
                        : 'off'
              }),
      ],
      // `seek` is the scrubber and it works; the interval-skip actions
      // are deliberately absent — see above.
      systemActions: {
        MediaAction.seek,
        MediaAction.setShuffleMode,
        MediaAction.setRepeatMode,
        if (multi) MediaAction.skipToNext,
        if (multi) MediaAction.skipToPrevious,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: _loading
          ? AudioProcessingState.loading
          : (_error != null
              ? AudioProcessingState.error
              : _queue.isEmpty
                  ? AudioProcessingState.idle
                  : AudioProcessingState.ready),
      errorCode: _error == null ? null : 1,
      errorMessage: _error,
      playing: _playing,
      updatePosition: _position,
      bufferedPosition: _position,
      speed: 1.0,
      queueIndex: _queue.isEmpty ? null : _queue.index,
      repeatMode: switch (_queue.repeat) {
        RepeatMode.off => AudioServiceRepeatMode.none,
        RepeatMode.all => AudioServiceRepeatMode.all,
        RepeatMode.one => AudioServiceRepeatMode.one,
      },
      shuffleMode: _queue.shuffled
          ? AudioServiceShuffleMode.all
          : AudioServiceShuffleMode.none,
    ));
    notifyUi();
  }

  /// ChangeNotifier-style hook for Flutter widgets. audio_service's
  /// streams are the OS-facing contract; this is the in-app one.
  final ValueNotifier<int> revision = ValueNotifier(0);
  void notifyUi() => revision.value++;

  void clearError() {
    if (_error == null) return;
    _error = null;
    _broadcast();
  }

  Future<void> dispose() async {
    _remote?.removeListener(_broadcast);
    _sleepTimer?.cancel();
    await _player.dispose();
  }
}
