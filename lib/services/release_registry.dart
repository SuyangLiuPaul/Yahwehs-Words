// What the admin portal (admin.yahwehword.com) says about releases and
// announcements. Read-only, public, tiny JSON from the project's Realtime
// Database (`adm_site/…`). Every failure returns null: the app must never
// depend on this being reachable.

import 'dart:convert';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:http/http.dart' as http;

/// Which app this build is, as the portal names it.
const String kRegistryApp =
    String.fromEnvironment('REGISTRY_APP', defaultValue: 'words');

const String _base = 'https://ysword-default-rtdb.firebaseio.com/adm_site';

/// The portal's platform key for the running build.
String registryPlatform() {
  if (kIsWeb) return 'web';
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return 'android';
    case TargetPlatform.iOS:
      return 'ios';
    case TargetPlatform.macOS:
      return 'macos';
    case TargetPlatform.windows:
      return 'windows';
    default:
      return 'linux';
  }
}

class ReleaseEntry {
  final String latest; // "" when the portal has no value
  final String min;
  final String url; // "" when none
  final Map<String, String> notes; // locale -> text
  const ReleaseEntry(
      {this.latest = '',
      this.min = '',
      this.url = '',
      this.notes = const {}});

  String notesFor(String locale) {
    final n = notes[locale] ?? '';
    if (n.isNotEmpty) return n;
    return notes['zh-Hans'] ?? notes['en'] ?? '';
  }
}

class ReleaseRegistry {
  ReleaseRegistry._();

  /// Parse the `versions/<app>` node. Pure so it can be tested.
  static ReleaseEntry? parseVersions(Object? json, String platform) {
    if (json is! Map) return null;
    final plat = (json['platforms'] as Map?)?[platform];
    if (plat is! Map) return null;
    String s(Object? v) => v is String ? v.trim() : '';
    final notes = <String, String>{};
    final n = json['notes'];
    if (n is Map) {
      n.forEach((k, v) {
        if (v is String && v.trim().isNotEmpty) notes['$k'] = v.trim();
      });
    }
    final e = ReleaseEntry(
        latest: s(plat['latest']),
        min: s(plat['min']),
        url: s(plat['url']),
        notes: notes);
    return e.latest.isEmpty && e.min.isEmpty && e.url.isEmpty ? null : e;
  }

  /// The portal's entry for this app on this platform, or null.
  static Future<ReleaseEntry?> fetch({
    String app = kRegistryApp,
    String? platform,
    http.Client? client,
  }) async {
    try {
      final c = client ?? http.Client();
      final r = await c
          .get(Uri.parse('$_base/versions/$app.json'))
          .timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) return null;
      return parseVersions(jsonDecode(r.body), platform ?? registryPlatform());
    } catch (_) {
      return null;
    }
  }
}
