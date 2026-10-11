import 'dart:convert';
import 'dart:js_interop';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web/web.dart' as web;
import '../constants/app_version.dart';
import 'song_cache_validation.dart';

const songValidationEvidenceKey = 'songs.downloads.web.v1.validation-evidence';

class SongCacheProbe {
  SongCacheProbe(this.report, this.blob);
  final Map<String, dynamic> report;
  final web.Blob? blob;
  bool get valid => report['reason'] == 'valid';
}

/// Reads existing CacheStorage only. Does not fetch, write, delete or recover.
Future<SongCacheProbe> probeSongCache(
    web.Cache? cache, String id, String key, int expectedBytes) async {
  final report = <String, dynamic>{
    'id': id,
    'origin': Uri.base.origin,
    'key': diagnosticCacheUrl(key, Uri.base),
    'expectedBytes': expectedBytes,
    'phase': 'match',
  };
  if (cache == null) {
    report['reason'] = 'cache_bucket_missing';
    return SongCacheProbe(report, null);
  }
  try {
    final hit = await cache.match(key.toJS).toDart;
    if (hit == null) {
      final keys = (await cache.keys().toDart).toDart;
      final exact = Uri.base.resolve(key).toString();
      report['matchingKeys'] = keys
          .where((r) => r.url == exact)
          .map((r) => diagnosticCacheUrl(r.url, Uri.base))
          .toList();
      final varying = await cache
          .match(key.toJS, web.CacheQueryOptions(ignoreVary: true))
          .toDart;
      report['ignoreVaryHit'] = varying != null;
      report['reason'] = varying != null
          ? 'vary_mismatch'
          : (report['matchingKeys'] as List).isNotEmpty
              ? 'match_unavailable_key_present'
              : 'cache_entry_missing';
      return SongCacheProbe(report, null);
    }
    report.addAll({
      'httpStatus': hit.status,
      'responseType': hit.type,
      'contentType': hit.headers.get('Content-Type'),
      'phase': 'body'
    });
    final blob = await hit.blob().toDart;
    report['actualBytes'] = blob.size.toInt();
    report['phase'] = 'prefix';
    final prefix =
        (await blob.slice(0, 64).arrayBuffer().toDart).toDart.asUint8List();
    report['prefixHex'] =
        prefix.take(8).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    report['reason'] =
        classifySongCacheBody(expectedBytes, blob.size.toInt(), prefix);
    report['phase'] = 'complete';
    return SongCacheProbe(report, blob);
  } catch (e) {
    // Raw browser error messages can contain URLs. Keep only error type/phase.
    report['reason'] = 'read_exception';
    report['errorType'] = e.runtimeType.toString();
    // Keep only known exception names, never the raw message or URL.
    for (final name in [
      'QuotaExceededError',
      'SecurityError',
      'InvalidStateError',
      'NotFoundError',
      'AbortError',
      'TypeError'
    ]) {
      if (e.toString().contains(name)) {
        report['browserException'] = name;
        break;
      }
    }
    return SongCacheProbe(report, null);
  }
}

/// The first failure remains available even after explicit download retry.
/// Writes diagnostic metadata only; audio/index/queue keys are untouched.
Future<void> retainSongValidationFailure(
    SharedPreferences prefs, Map<String, dynamic> report) async {
  if (report['reason'] == 'valid') return;
  try {
    Map<String, dynamic> old = {};
    final raw = prefs.getString(songValidationEvidenceKey);
    if (raw != null) old = (jsonDecode(raw) as Map).cast<String, dynamic>();
    final id = report['id'] as String;
    old.putIfAbsent(
        id,
        () => {
              ...report,
              'capturedUTC': DateTime.now().toUtc().toIso8601String(),
              'version': kAppVersion
            });
    await prefs.setString(songValidationEvidenceKey, jsonEncode(old));
  } catch (_) {
    // Diagnostic journal failure cannot erase or invalidate the audio.
  }
}
