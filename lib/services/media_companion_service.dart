import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'song_audio_handler.dart';
import 'car_audio_catalogue.dart';
import 'daily_verse_service.dart';
import '../constants/book_name_mapping.dart';
import '../utils/reference_parser.dart';

/// A phone companion, never an independent streaming player. CarPlay and
/// both watch platforms use the same catalogue and active media session.
class MediaCompanionService {
  static const _channel = MethodChannel('yswords/media_companion');
  static SongAudioHandler? _handler;
  static Map<String, dynamic> _daily = {};
  static String? _dailyDate;
  static Timer? _timer;
  static Future<void>? _dailyLoading;
  static final _subscriptions = <StreamSubscription<dynamic>>[];
  static String? _publishedIdentity;
  static String _locale = 'en';
  static Map<String, dynamic> _reading = {};
  static String _readingIdentity = '';

  static void updateReading(Map<String, dynamic> reading, String locale) {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.iOS &&
            defaultTargetPlatform != TargetPlatform.android)) {
      return;
    }
    final identity = jsonEncode({'reading': reading, 'locale': locale});
    if (identity == _readingIdentity) return;
    _readingIdentity = identity;
    _reading = reading;
    _locale = locale;
    if (_handler != null) unawaited(_publish());
  }

  static void start(SongAudioHandler handler) {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.iOS &&
            defaultTargetPlatform != TargetPlatform.android)) {
      return;
    }
    _handler = handler;
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
    _publishedIdentity = null;
    void publishChange(dynamic _) {
      final snapshot = _snapshot();
      final identity = jsonEncode({
        for (final key in [
          'id',
          'title',
          'subtitle',
          'artwork',
          'locale',
          'duration',
          'loading',
          'canSkip',
          'canNext',
          'canPrevious',
          'playing',
          'error',
          'sermon'
        ])
          key: snapshot[key],
      });
      if (identity != _publishedIdentity) {
        _publishedIdentity = identity;
        unawaited(_publish());
      }
    }

    _subscriptions.add(handler.mediaItem.listen(publishChange));
    _subscriptions.add(handler.playbackState.listen(publishChange));
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'snapshot':
          await _loadLocale();
          await _loadDaily();
          return _snapshot();
        case 'children':
          final args = Map<String, dynamic>.from(call.arguments as Map);
          final children =
              await CarAudioCatalogue.children(args['id'] as String);
          return [
            for (final item in children)
              {
                'id': item.id,
                'title': item.title,
                'subtitle': item.artist ?? item.album ?? '',
                'artwork': item.artUri?.toString() ?? '',
                'playable': item.playable,
              }
          ];
        case 'command':
          await _loadLocale();
          final args = Map<String, dynamic>.from(call.arguments as Map);
          await _command(args['action'] as String, args['id'] as String?);
          unawaited(_publish());
          return _snapshot();
        default:
          throw MissingPluginException('Unknown companion method');
      }
    });
    _timer?.cancel();
    // Position ticks are throttled; watches need a glanceable state, not
    // hundreds of connectivity transfers per minute.
    _timer = Timer.periodic(
        const Duration(seconds: 3), (_) => unawaited(_publish()));
    unawaited(_publish());
  }

  static Future<void> _command(String action, String? id) async {
    final h = _handler!;
    switch (action) {
      case 'play':
        await h.play();
      case 'pause':
        await h.pause();
      case 'next':
        await h.skipToNext();
      case 'previous':
        await h.skipToPrevious();
      case 'forward':
        await h.fastForward();
      case 'backward':
        await h.rewind();
      case 'stop':
        await h.stop();
      case 'select':
        if (id != null) await h.playFromMediaId(id);
      default:
        throw ArgumentError('Unknown remote command: $action');
    }
  }

  static Map<String, dynamic> _snapshot() =>
      snapshotFor(_handler!, locale: _locale);

  @visibleForTesting
  static Map<String, dynamic> snapshotFor(SongAudioHandler h,
      {String locale = 'en'}) {
    final item = h.mediaItem.valueOrNull;
    final state = h.playbackState.value;
    return {
      'title': item?.title ?? '',
      'subtitle': item?.album ?? item?.artist ?? '',
      'artwork': item?.artUri?.toString() ?? '',
      'locale': locale,
      'id': item?.id ?? '',
      'playing': state.playing,
      'loading': state.processingState.name == 'loading',
      'position': state.position.inSeconds,
      'duration': item?.duration?.inSeconds ?? 0,
      // A cached watch snapshot must not masquerade as a live player.
      'syncedAt': DateTime.now().millisecondsSinceEpoch,
      'sermon': item?.id.startsWith('car:sermon/') ?? false,
      'canSkip': state.controls.any((c) => c.action.name == 'skipToNext'),
      'canNext':
          item?.id.startsWith('car:sermon/') == true || h.songQueue.hasNext,
      'canPrevious':
          item?.id.startsWith('car:sermon/') == true || h.songQueue.hasPrevious,
      'error': state.errorMessage ?? '',
      'reading': _reading,
      'daily': _daily
    };
  }

  static Future<void> _publish() async {
    try {
      await _loadLocale();
      await _loadDaily();
      await _channel.invokeMethod<void>('state', _snapshot());
    } on MissingPluginException {
      // Older native shells do not include the companion bridge.
      // Regular audio_service controls still work there.
    } catch (e) {
      debugPrint('[MediaCompanion] state unavailable: $e');
    }
  }

  static Future<void> _loadLocale() async {
    _locale = (await SharedPreferences.getInstance()).getString('locale') ??
        'zh-Hans';
  }

  static Future<void> _loadDaily() async {
    final date = DateTime.now().toIso8601String().substring(0, 10);
    if (_dailyDate == date) return;
    await (_dailyLoading ??= _readDaily(date));
  }

  static Future<void> _readDaily(String date) async {
    try {
      final ref = await DailyVerseService.todayRef();
      final parsed = ref == null ? null : parseReference(ref);
      if (parsed == null) return;
      final texts = <String, String>{};
      for (final edition in ['bsb-yhwh', 'cuvs-yhwh']) {
        final rows =
            jsonDecode(await rootBundle.loadString('assets/$edition.json'))
                as List;
        final matches = rows.cast<Map>().where((v) =>
            (zhToEn(v['book'] as String) ?? v['book']) == parsed.englishBook &&
            v['chapter'].toString() == parsed.chapter.toString() &&
            v['verse'].toString() == parsed.verseStart.toString());
        if (matches.isNotEmpty) {
          texts[edition] = (matches.first['text'] as String)
              .replaceAll(RegExp(r'<note:[^>]*>'), '')
              .replaceAll(RegExp(r'<[^>]+>'), '');
        }
      }
      _daily = {
        'reference': ref,
        'english': texts['bsb-yhwh'] ?? '',
        'chinese': texts['cuvs-yhwh'] ?? '',
        'date': date,
        'editions': 'BSB-Y · CUVS-Y'
      };
      _dailyDate = date;
    } finally {
      _dailyLoading = null;
    }
  }
}
