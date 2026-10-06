// Content the admin portal (admin.yahwehword.com) has changed on top of the
// shipped data: songs hidden / edited / added, the home page's featured
// order, and the announcement. Read-only, public, small.
//
// The app never depends on it: every failure returns "no overlay" and the
// shipped data is shown exactly as before. Results are cached in memory for
// [ttl] so opening Songs twice does not fetch twice.

import 'dart:convert';

import 'package:http/http.dart' as http;

const String kAdminDbBase = 'https://ysword-default-rtdb.firebaseio.com';

class AdminSite {
  final List<String>? featuredOrder; // null = no preference
  final Set<String> featuredOff;
  final AdminAnnouncement? announcement;
  const AdminSite(
      {this.featuredOrder,
      this.featuredOff = const {},
      this.announcement});
  static const AdminSite none = AdminSite();
}

class AdminAnnouncement {
  final String id; // changes whenever the text changes, so a dismissal resets
  final Map<String, String> text;
  final String url;
  final bool warn;
  const AdminAnnouncement(
      {required this.id,
      required this.text,
      this.url = '',
      this.warn = false});

  String textFor(String locale) {
    final t = text[locale] ?? '';
    if (t.isNotEmpty) return t;
    return text['zh-Hans'] ?? text['en'] ?? '';
  }
}

class AdminOverlay {
  AdminOverlay._();

  static const Duration ttl = Duration(minutes: 30);

  /// Test seam: path (e.g. `adm_songs`) -> decoded JSON or null.
  static Future<Object?> Function(String path)? fetcher;

  static final Map<String, (DateTime, Object?)> _cache = {};

  static void clearCache() => _cache.clear();

  static Future<Object?> _get(String path,
      {Duration timeout = const Duration(seconds: 6)}) async {
    final hit = _cache[path];
    if (hit != null && DateTime.now().difference(hit.$1) < ttl) return hit.$2;
    Object? v;
    try {
      if (fetcher != null) {
        v = await fetcher!(path);
      } else {
        final r = await http
            .get(Uri.parse('$kAdminDbBase/$path.json'))
            .timeout(timeout);
        if (r.statusCode == 200) v = jsonDecode(r.body);
      }
    } catch (_) {
      v = null;
    }
    // Only a successful read is cached; a failure retries next time.
    if (v != null) _cache[path] = (DateTime.now(), v);
    return v;
  }

  /// `adm_songs` as {id: {patch?, hidden?, custom?, data?}}; empty when
  /// none or unreachable.
  static Future<Map<String, Map<String, dynamic>>> collection(String name,
      {Duration timeout = const Duration(seconds: 6)}) async {
    final raw = await _get(name, timeout: timeout);
    if (raw is! Map) return const {};
    final out = <String, Map<String, dynamic>>{};
    raw.forEach((k, v) {
      if (v is Map) out['$k'] = Map<String, dynamic>.from(v);
    });
    return out;
  }

  static Future<AdminSite> site({DateTime? now}) async {
    final raw = await _get('adm_site');
    return parseSite(raw, now: now ?? DateTime.now());
  }

  /// Pure, for tests.
  static AdminSite parseSite(Object? raw, {required DateTime now}) {
    if (raw is! Map) return AdminSite.none;
    List<String>? order;
    final off = <String>{};
    final f = raw['featured'];
    if (f is Map) {
      final o = f['order'];
      if (o is List) order = o.map((e) => '$e').toList();
      final x = f['off'];
      if (x is List) off.addAll(x.map((e) => '$e'));
    }
    AdminAnnouncement? ann;
    final a = raw['announcement'];
    if (a is Map && a['enabled'] == true) {
      final apps = a['apps'];
      final forThisApp = apps is! Map || apps[_appKey] == true;
      final start = DateTime.tryParse('${a['startsAt'] ?? ''}');
      final end = DateTime.tryParse('${a['endsAt'] ?? ''}');
      final live = (start == null || !now.isBefore(start)) &&
          (end == null || !now.isAfter(end));
      final text = <String, String>{};
      final t = a['text'];
      if (t is Map) {
        t.forEach((k, v) {
          if (v is String && v.trim().isNotEmpty) text['$k'] = v.trim();
        });
      }
      if (forThisApp && live && text.isNotEmpty) {
        ann = AdminAnnouncement(
            id: '${a['updatedAt'] ?? ''}|${jsonEncode(text)}',
            text: text,
            url: '${a['url'] ?? ''}'.trim(),
            warn: a['level'] == 'warn');
      }
    }
    return AdminSite(featuredOrder: order, featuredOff: off, announcement: ann);
  }

  static const String _appKey =
      String.fromEnvironment('REGISTRY_APP', defaultValue: 'words');
}
