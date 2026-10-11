import 'dart:convert';
import 'dart:js_interop';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web/web.dart' as web;
import '../constants/app_version.dart';
import 'song_cache_validation.dart';

import 'song_cache_probe_web.dart';
import 'song_download_web.dart';

Future<Map<String, dynamic>> inspectSongDownloadStorage() async {
  final result = <String, dynamic>{
    'origin': Uri.base.origin,
    'version': kAppVersion,
    'capturedUTC': DateTime.now().toUtc().toIso8601String(),
    'readOnly': true,
    'cacheName': 'song-media-v1'
  };
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  final raw = prefs.getString('songs.downloads.web.v1');
  final records = raw == null
      ? <String, dynamic>{}
      : (jsonDecode(raw) as Map).cast<String, dynamic>();
  final cacheNames = (await web.window.caches.keys().toDart)
      .toDart
      .map((s) => s.toDart)
      .toList();
  result['cacheNames'] = cacheNames;
  final cache = cacheNames.contains('song-media-v1')
      ? await web.window.caches.open('song-media-v1').toDart
      : null;
  result['actualKeys'] = cache == null
      ? <String>[]
      : (await cache.keys().toDart)
          .toDart
          .map((r) => diagnosticCacheUrl(r.url, Uri.base))
          .toList();
  final rows = <Map<String, dynamic>>[];
  for (final e in records.entries) {
    try {
      final row = (e.value as Map).cast<String, dynamic>();
      rows.add((await probeSongCache(cache, e.key, row['url'] as String,
              (row['bytes'] as num?)?.toInt() ?? 0))
          .report);
    } catch (_) {
      rows.add({'id': e.key, 'reason': 'invalid_index_record'});
    }
  }
  result['records'] = rows;
  result['count'] = rows.length;
  result['validCount'] = rows.where((r) => r['reason'] == 'valid').length;
  final evidence = prefs.getString(songValidationEvidenceKey);
  result['firstFailuresBeforeRecovery'] =
      evidence == null ? {} : jsonDecode(evidence);
  try {
    final registrations =
        (await web.window.navigator.serviceWorker.getRegistrations().toDart)
            .toDart;
    final controller = web.window.navigator.serviceWorker.controller;
    result['controller'] = controller == null
        ? null
        : {
            'script': diagnosticCacheUrl(controller.scriptURL, Uri.base),
            'state': controller.state
          };
    result['workers'] = registrations
        .map((r) => {
              'scope': diagnosticCacheUrl(r.scope, Uri.base),
              'activeScript': r.active == null
                  ? null
                  : diagnosticCacheUrl(r.active!.scriptURL, Uri.base)
            })
        .toList();
    final estimate = await web.window.navigator.storage.estimate().toDart;
    result['storage'] = {
      'usage': estimate.usage,
      'quota': estimate.quota,
      'persisted':
          (await web.window.navigator.storage.persisted().toDart).toDart
    };
  } catch (e) {
    result['environmentReadErrorType'] = e.runtimeType.toString();
  }
  return result;
}

/// Explicit read-only recheck. First capture failures before refreshing UI state.
Future<bool> recheckSongDownloadStorage() async {
  final service = SongDownloadService.instance;
  if (service.pendingCount > 0) return false;
  final report = await inspectSongDownloadStorage();
  final prefs = await SharedPreferences.getInstance();
  for (final row in (report['records'] as List).cast<Map<String, dynamic>>()) {
    await retainSongValidationFailure(prefs, row);
  }
  return service.recheckSavedAudio();
}
