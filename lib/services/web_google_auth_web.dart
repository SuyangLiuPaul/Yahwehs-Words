import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:web/web.dart' as web;

Future<AuthCredential>? _pending;

/// Same-origin, one-use channel survives strict COOP without window.opener.
/// The helper uses its own session-only Firebase app, leaving currentUser intact.
Future<AuthCredential> webGoogleCredential() {
  if (_pending != null) return _pending!;
  final future = _acquire();
  _pending = future;
  return future.whenComplete(() {
    if (identical(_pending, future)) _pending = null;
  });
}

Future<AuthCredential> _acquire() async {
  final state = base64UrlEncode(
          List<int>.generate(32, (_) => Random.secure().nextInt(256)))
      .replaceAll('=', '');
  final channel = web.BroadcastChannel('yswords.google.$state');
  final result = Completer<AuthCredential>();
  channel.onmessage = ((web.MessageEvent event) {
    final data = event.data.dartify();
    if (data is! String || data.length > 32768 || result.isCompleted) return;
    try {
      final value = jsonDecode(data);
      if (value is! Map || value['state'] != state) return;
      if (value['error'] == 'cancelled') {
        result.completeError(FirebaseAuthException(code: 'cancelled'));
      } else {
        final id = value['idToken'];
        final access = value['accessToken'];
        if ((id != null &&
                (id is! String || id.isEmpty || id.length > 16384)) ||
            (access != null &&
                (access is! String ||
                    access.isEmpty ||
                    access.length > 16384)) ||
            (id == null && access == null)) {
          return;
        }
        result.complete(GoogleAuthProvider.credential(
            idToken: id as String?, accessToken: access as String?));
      }
      channel.postMessage(jsonEncode({'state': state, 'received': true}).toJS);
    } catch (_) {/* Ignore malformed or unrelated channel messages. */}
  }).toJS;
  try {
    // Open synchronously from the confirmation gesture, before awaiting a result.
    final url = Uri(path: '/desktop-google-sign-in.html', queryParameters: {
      'mode': 'web',
      'state': state,
      'lang': web.document.documentElement?.getAttribute('lang') ?? 'en'
    });
    web.window.open(url.toString(), '_blank', 'noopener');
    return await result.future.timeout(const Duration(minutes: 4),
        onTimeout: () =>
            throw FirebaseAuthException(code: 'web-sign-in-timeout'));
  } finally {
    channel.close();
  }
}
