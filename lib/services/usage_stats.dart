// Anonymous usage counters for the admin portal's "Usage stats" page.
//
// What is sent: a day (UTC), and +1 on three counters — sessions, page
// views, and views per top-level page ("songs", "sermons", …). Nothing
// that identifies a person or a device, no IP kept, no content, no
// timing. Each send is one tiny PATCH that the database rules cap at +5
// page views, so a misbehaving client cannot distort the numbers much.
//
// Never throws, never waits for the network, and does nothing in tests.

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:yahwehs_words/services/admin_overlay.dart' show kAdminDbBase;
import 'package:yahwehs_words/services/release_registry.dart'
    show kRegistryApp;

class UsageStats {
  UsageStats._();

  /// Off in tests and wherever `--dart-define=USAGE_STATS=false`.
  static bool enabled = const bool.fromEnvironment('USAGE_STATS',
          defaultValue: true) &&
      !const bool.fromEnvironment('FLUTTER_TEST');

  /// Test seam: receives the day key and the PATCH body.
  static Future<void> Function(String day, Map<String, Object?> body)? sender;

  static bool _sessionSent = false;

  /// "/sermons/004" -> "sermons"; "/SongsPage" -> "songspage". Keys must
  /// not contain `. # $ [ ] /` (Realtime Database), and must stay a small
  /// set — the first path segment only.
  static String pageKey(String route) {
    final seg = route.split('?').first.split('/').where((s) => s.isNotEmpty);
    final first = seg.isEmpty ? 'home' : seg.first;
    final k = first.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_-]'), '');
    return k.isEmpty ? 'other' : (k.length > 32 ? k.substring(0, 32) : k);
  }

  static String dayKey([DateTime? now]) {
    final d = (now ?? DateTime.now()).toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  static Map<String, Object?> body({required bool session, String? page}) {
    Map<String, Object?> inc() => {
          '.sv': {'increment': 1}
        };
    return {
      'day': dayKey(),
      'pv': inc(),
      if (session) 'sessions': inc(),
      if (page != null) 'pages/${pageKey(page)}': inc(),
      'apps/$kRegistryApp': inc(),
    };
  }

  /// Once per app launch.
  static void session() {
    if (_sessionSent) return;
    _sessionSent = true;
    _send(body(session: true, page: 'home'));
  }

  /// A page opened.
  static void page(String route) => _send(body(session: false, page: route));

  static void _send(Map<String, Object?> b) {
    if (!enabled && sender == null) return;
    final day = b['day']! as String;
    () async {
      try {
        if (sender != null) {
          await sender!(day, b);
          return;
        }
        await http
            .patch(Uri.parse('$kAdminDbBase/adm_stats/$day.json'),
                headers: const {'Content-Type': 'application/json'},
                body: jsonEncode(b))
            .timeout(const Duration(seconds: 5));
      } catch (_) {/* counters are best-effort */}
    }();
  }
}
