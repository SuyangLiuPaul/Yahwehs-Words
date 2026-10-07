import 'dart:math';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_version.dart';
import 'release_registry.dart';

/// Local random installation identity, never a hardware fingerprint.
/// Reading, media playback and sign-in do not depend on storage succeeding.
class InstallationDiagnostics {
  static const preferenceKey = 'installation_diagnosis_id_v1';
  static Future<String>? _loading;
  static String? _memoryId;
  static bool persistent = true;
  static Future<void> _resets = Future.value();
  static final List<Map<String, Object>> _events = [];
  static final Map<String, String> _companions = {};
  static void companion(Object? platform, Object? id) {
    if ((platform == 'watchos' || platform == 'wearos') &&
        id is String &&
        validId(id)) {
      _companions[platform as String] = id;
    }
  }

  static const eventKinds = {'update', 'companion', 'audio', 'report'};
  static const eventResults = {
    'started',
    'succeeded',
    'failed',
    'playing',
    'paused',
    'interrupted',
    'available',
    'upToDate',
    'required',
    'connected',
    'disconnected'
  };

  /// Only enum-like status codes are accepted; no titles, URLs or error text.
  static void record(String kind, String result) {
    if (!eventKinds.contains(kind) || !eventResults.contains(result)) return;
    if (_events.isNotEmpty &&
        _events.last['kind'] == kind &&
        _events.last['result'] == result) {
      return;
    }
    _events.add({
      'kind': kind,
      'result': result,
      'at': DateTime.now().toUtc().toIso8601String()
    });
    if (_events.length > 20) _events.removeAt(0);
  }

  @visibleForTesting
  static void clearMemoryForTest() {
    _loading = null;
    _memoryId = null;
    persistent = true;
    _events.clear();
    _companions.clear();
    _resets = Future.value();
  }

  static Future<String> id() => _loading ??= _load();
  static bool validId(String value) =>
      RegExp(r'^YD-[0-9a-f]{32}$').hasMatch(value);
  static String generate() {
    final random = Random.secure();
    return 'YD-${List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
  }

  static Future<String> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getString(preferenceKey);
      if (existing != null && validId(existing)) return _memoryId = existing;
      final next = _memoryId ??= generate();
      persistent = await prefs.setString(preferenceKey, next);
      return next;
    } catch (_) {
      persistent = false;
      return _memoryId ??= generate();
    }
  }

  static Future<void> reset() {
    final task = _resets.then((_) => _reset());
    _resets = task.catchError((Object _) {});
    return task;
  }

  static Future<void> _reset() async {
    final next = generate();
    // Replace the in-flight loader so late completion cannot expose an old ID.
    final loading = _loading;
    if (loading != null) await loading;
    _memoryId = next;
    _loading = Future.value(next);
    try {
      persistent = await (await SharedPreferences.getInstance())
          .setString(preferenceKey, next);
    } catch (_) {
      persistent = false;
    }
  }

  static Future<Map<String, Object>> snapshot() async => {
        'diagnosisId': await id(),
        'app': kRegistryApp,
        'appVersion': kAppVersion,
        'platform': registryPlatform(),
        'channel': registryChannel(),
        'idPersistent': persistent,
        'companions': Map<String, String>.of(_companions),
        'events': [for (final event in _events) Map<String, Object>.of(event)],
      };
}
