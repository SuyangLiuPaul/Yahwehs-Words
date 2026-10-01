import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

/// Windows Firebase supports credentials, but its provider UI is mobile-only.
/// An isolated browser page obtains the Google credential and returns it to
/// a short-lived, one-use IPv4 loopback listener. Tokens never enter URLs,
/// files or logs. Firebase itself verifies the returned Google credential.
class DesktopGoogleBridge {
  DesktopGoogleBridge({
    this.origin = 'https://yahwehword.com',
    this.timeout = const Duration(minutes: 5),
    Future<bool> Function(Uri)? openBrowser,
  }) : _openBrowser = openBrowser ??
            ((uri) => launchUrl(uri, mode: LaunchMode.externalApplication));

  final String origin;
  final Duration timeout;
  final Future<bool> Function(Uri) _openBrowser;
  bool _busy = false;
  static const allowedOrigins = {
    'https://yahwehword.com',
    'https://yswords.netlify.app',
    'https://yswords-dev.netlify.app',
    'https://yswords-qat.netlify.app',
  };

  Future<AuthCredential> signIn({String locale = 'en'}) async {
    if (_busy) {
      throw FirebaseAuthException(code: 'web-context-already-presented');
    }
    if (!allowedOrigins.contains(origin)) {
      throw ArgumentError('Untrusted desktop sign-in origin');
    }
    _busy = true;
    final deadline = DateTime.now().add(timeout);
    Duration remaining() {
      final value = deadline.difference(DateTime.now());
      if (value <= Duration.zero) {
        throw FirebaseAuthException(code: 'web-context-cancelled');
      }
      return value;
    }

    bool finished = false;
    HttpServer? server;
    StreamSubscription<HttpRequest>? listener;
    final completed = Completer<AuthCredential>();
    bool claimed = false;
    // Attach error handling before a fast browser response can arrive.
    final result = completed.future.timeout(timeout, onTimeout: () {
      throw FirebaseAuthException(
          code: 'web-context-cancelled',
          message: 'Browser sign-in timed out. Please try again.');
    });
    // Awaited below; suppress early unhandled asynchronous errors while launching.
    unawaited(result.then<void>((_) {}, onError: (Object _) {}));
    try {
      final binding = HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      unawaited(binding.then<void>((bound) {
        if (finished) unawaited(bound.close(force: true));
      }, onError: (Object _) {}));
      server = await binding.timeout(remaining());
      final port = server.port;
      final random = Random.secure();
      final state = base64Url
          .encode(List.generate(32, (_) => random.nextInt(256)))
          .replaceAll('=', '');
      final expectedHost = '127.0.0.1:$port';
      listener = server.listen((request) async {
        final response = request.response;
        response.headers
          ..contentType = ContentType.html
          ..set('Cache-Control', 'no-store')
          ..set('Referrer-Policy', 'no-referrer')
          ..set('Content-Security-Policy',
              "default-src 'none'; style-src 'unsafe-inline'")
          ..set('X-Content-Type-Options', 'nosniff');
        AuthCredential? receivedCredential;
        FirebaseAuthException? receivedError;
        try {
          if (claimed ||
              completed.isCompleted ||
              request.uri.path != '/google-sign-in' ||
              request.uri.hasQuery ||
              request.method != 'POST' ||
              request.headers.value('host') != expectedHost ||
              request.headers.value('origin') != origin ||
              request.headers.contentType?.mimeType !=
                  'application/x-www-form-urlencoded') {
            response.statusCode = HttpStatus.forbidden;
            response.write('Invalid or expired sign-in request.');
            return;
          }
          final bytes = <int>[];
          await for (final chunk
              in request.timeout(const Duration(seconds: 15))) {
            if (bytes.length + chunk.length > 65536) {
              response.statusCode = HttpStatus.requestEntityTooLarge;
              return;
            }
            bytes.addAll(chunk);
          }
          final fields = Uri.splitQueryString(utf8.decode(bytes));
          final receivedState = fields['state'] ?? '';
          var difference = receivedState.length ^ state.length;
          for (var i = 0; i < state.length; i++) {
            difference |= state.codeUnitAt(i) ^
                (i < receivedState.length ? receivedState.codeUnitAt(i) : 0);
          }
          if (difference != 0) {
            response.statusCode = HttpStatus.forbidden;
            response.write('Invalid sign-in request.');
            return;
          }
          if (claimed || completed.isCompleted) {
            response.statusCode = HttpStatus.forbidden;
            return;
          }
          if (fields['error'] == 'cancelled') {
            claimed = true;
            receivedError =
                FirebaseAuthException(code: 'web-context-cancelled');
            response.write('Sign-in cancelled. 登录已取消。登入已取消。');
          } else {
            final idToken = fields['idToken'];
            final accessToken = fields['accessToken'];
            // Firebase's Google redirect credential may contain only an
            // access token. The native SDK accepts either Google token;
            // requiring both incorrectly rejects a successful browser login.
            if ((idToken == null || idToken.isEmpty) &&
                    (accessToken == null || accessToken.isEmpty) ||
                (idToken?.length ?? 0) > 16384 ||
                (accessToken?.length ?? 0) > 16384) {
              response.statusCode = HttpStatus.badRequest;
              response.write('Missing Google credential.');
              return;
            }
            claimed = true;
            receivedCredential = GoogleAuthProvider.credential(
                idToken: idToken == null || idToken.isEmpty ? null : idToken,
                accessToken: accessToken == null || accessToken.isEmpty
                    ? null
                    : accessToken);
            response.write(
                '<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>Yahweh’s Words</title><style>body{font:18px system-ui;max-width:40rem;margin:12vh auto;padding:24px;line-height:1.7}</style><h1>Return to Yahweh’s Words</h1><p>Your Google response was received. Return to the app to finish signing in.</p><p>请返回应用完成登录。請返回應用完成登入。</p>');
          }
        } catch (_) {
          // Invalid or interrupted HTTP requests do not finish the auth attempt.
          try {
            response.statusCode = HttpStatus.badRequest;
          } catch (_) {}
        } finally {
          try {
            await response.close();
          } catch (_) {/* Client closed the tab. */}
          if (!completed.isCompleted) {
            if (receivedCredential != null) {
              completed.complete(receivedCredential);
            }
            if (receivedError != null) {
              completed.completeError(receivedError);
            }
          }
        }
      });
      final uri = Uri.parse('$origin/desktop-google-sign-in.html')
          .replace(queryParameters: {
        'port': '$port',
        'state': state,
        'lang': {'en', 'zh-Hans', 'zh-Hant'}.contains(locale) ? locale : 'en'
      });
      if (!await _openBrowser(uri).timeout(remaining())) {
        throw FirebaseAuthException(
            code: 'web-context-cancelled',
            message: 'Unable to open the browser.');
      }
      return await result;
    } finally {
      finished = true;
      if (!completed.isCompleted) {
        completed.completeError(
            FirebaseAuthException(code: 'web-context-cancelled'));
      }
      await server?.close(force: true);
      await listener?.cancel();
      _busy = false;
    }
  }
}

final _desktopGoogleBridge = DesktopGoogleBridge();
Future<AuthCredential> desktopGoogleCredential({String locale = 'en'}) =>
    _desktopGoogleBridge.signIn(locale: locale);
