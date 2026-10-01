import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahwehs_words/services/desktop_google_auth_io.dart';
import 'package:yahwehs_words/firebase_options.dart';

void main() {
  final requests = <Uri>[];
  Future<int> post(Uri uri,
      {String? state,
      String origin = 'https://yahwehword.com',
      String path = '/google-sign-in',
      String method = 'POST',
      Map<String, String>? fields,
      String? rawBody}) async {
    final client = HttpClient();
    try {
      final req = await client.openUrl(method,
          Uri.parse('http://127.0.0.1:${uri.queryParameters['port']}$path'));
      req.headers.set('Origin', origin);
      req.headers.contentType =
          ContentType('application', 'x-www-form-urlencoded');
      if (method != 'GET') {
        req.write(rawBody ??
            Uri(queryParameters: {
              'state': state ?? uri.queryParameters['state']!,
              'idToken': 'test-only-google-id-token',
              'accessToken': 'test-only-access-token',
              ...?fields
            }).query);
      }
      final response = await req.close();
      await response.drain<void>();
      return response.statusCode;
    } finally {
      client.close(force: true);
    }
  }

  test(
      'valid loopback POST returns a Google credential and closes the listener',
      () async {
    late Future<int> posted;
    final bridge = DesktopGoogleBridge(openBrowser: (uri) async {
      requests.add(uri);
      posted = post(uri);
      return true;
    });
    final credential =
        await bridge.signIn(locale: 'zh-Hant') as OAuthCredential;
    expect(credential.providerId, 'google.com');
    expect(credential.idToken, 'test-only-google-id-token');
    expect(credential.accessToken, 'test-only-access-token');
    expect(await posted, 200);
    expect(requests.last.host, 'yahwehword.com');
    expect(requests.last.queryParameters['lang'], 'zh-Hant');
    expect(requests.last.queryParameters['state']!.length, 43);
    expect(requests.last.toString(), isNot(contains('token')));
    await expectLater(post(requests.last), throwsA(isA<SocketException>()));
  });

  for (final absent in ['idToken', 'accessToken']) {
    test('accepts a Google credential without $absent', () async {
      late Future<int> posted;
      final bridge = DesktopGoogleBridge(openBrowser: (uri) async {
        posted = post(uri, fields: {absent: ''});
        return true;
      });
      final credential = await bridge.signIn() as OAuthCredential;
      expect(credential.providerId, 'google.com');
      expect(absent == 'idToken' ? credential.idToken : credential.accessToken,
          isNull);
      expect(await posted, 200);
    });
  }

  for (final invalid in [
    'state',
    'origin',
    'path',
    'method',
    'oversize',
    'missing'
  ]) {
    test('rejects $invalid then still accepts a legitimate response', () async {
      late Future<void> sequence;
      final bridge = DesktopGoogleBridge(openBrowser: (uri) async {
        sequence = () async {
          final status = await post(uri,
              state: invalid == 'state' ? 'wrong' : null,
              origin: invalid == 'origin'
                  ? 'https://attacker.example'
                  : 'https://yahwehword.com',
              path: invalid == 'path' ? '/other' : '/google-sign-in',
              method: invalid == 'method' ? 'GET' : 'POST',
              rawBody: invalid == 'oversize' ? 'x' * 65537 : null,
              fields: invalid == 'missing'
                  ? {'idToken': '', 'accessToken': ''}
                  : null);
          expect(
              status,
              invalid == 'oversize'
                  ? 413
                  : invalid == 'missing'
                      ? 400
                      : 403);
          expect(await post(uri), 200);
        }();
        return true;
      });
      expect((await bridge.signIn()).providerId, 'google.com');
      await sequence;
    });
  }

  test('browser cancellation completes promptly without a credential',
      () async {
    late Future<int> posted;
    final bridge = DesktopGoogleBridge(openBrowser: (uri) async {
      posted = post(uri, fields: {'error': 'cancelled'});
      return true;
    });
    await expectLater(
        bridge.signIn(),
        throwsA(isA<FirebaseAuthException>()
            .having((e) => e.code, 'code', 'web-context-cancelled')));
    expect(await posted, 200);
  });

  test('timeout and failed launch close listener and allow retries', () async {
    final launched = <Uri>[];
    final bridge = DesktopGoogleBridge(
        timeout: const Duration(milliseconds: 40),
        openBrowser: (uri) async {
          launched.add(uri);
          return true;
        });
    for (var i = 0; i < 2; i++) {
      await expectLater(bridge.signIn(), throwsA(isA<FirebaseAuthException>()));
      await expectLater(post(launched.last), throwsA(isA<SocketException>()));
    }
    expect(launched[0].queryParameters['state'],
        isNot(launched[1].queryParameters['state']));
    final failed = DesktopGoogleBridge(openBrowser: (uri) async {
      launched.add(uri);
      return false;
    });
    await expectLater(failed.signIn(), throwsA(isA<FirebaseAuthException>()));
    await expectLater(post(launched.last), throwsA(isA<SocketException>()));
  });

  test('simultaneous attempts do not create competing sign-in contexts',
      () async {
    final launched = Completer<Uri>();
    final bridge = DesktopGoogleBridge(openBrowser: (uri) async {
      launched.complete(uri);
      return true;
    });
    final first = bridge.signIn();
    final uri = await launched.future;
    await expectLater(
        bridge.signIn(),
        throwsA(isA<FirebaseAuthException>()
            .having((e) => e.code, 'code', 'web-context-already-presented')));
    final posted = post(uri);
    await first;
    expect(await posted, 200);
  });
  test('a submitted credential survives the browser disconnecting', () async {
    final bridge = DesktopGoogleBridge(
        timeout: const Duration(seconds: 3),
        openBrowser: (uri) async {
          final body = Uri(queryParameters: {
            'state': uri.queryParameters['state']!,
            'idToken': 'test-only-google-id-token',
            'accessToken': 'test-only-access-token'
          }).query;
          final socket = await Socket.connect(
              '127.0.0.1', int.parse(uri.queryParameters['port']!));
          socket.write(
              'POST /google-sign-in HTTP/1.1\r\nHost: 127.0.0.1:${uri.queryParameters['port']}\r\nOrigin: https://yahwehword.com\r\nContent-Type: application/x-www-form-urlencoded\r\nContent-Length: ${utf8.encode(body).length}\r\nConnection: close\r\n\r\n$body');
          await socket.flush();
          socket.destroy();
          return true;
        });
    expect((await bridge.signIn()).providerId, 'google.com');
  });
  test(
      'browser launch shares the sign-in deadline and cannot wait indefinitely',
      () async {
    final bridge = DesktopGoogleBridge(
        timeout: const Duration(milliseconds: 40),
        openBrowser: (_) => Completer<bool>().future);
    await expectLater(bridge.signIn(), throwsA(isA<TimeoutException>()));
  });
  test('untrusted helper origins are rejected before launching', () async {
    final bridge = DesktopGoogleBridge(
        origin: 'https://attacker.example',
        openBrowser: (_) async => fail('must not launch'));
    await expectLater(bridge.signIn(), throwsArgumentError);
  });
  test('browser public config matches Flutter and exposes no client secret',
      () {
    final js = File('web/desktop-google-config.js').readAsStringSync();
    final config =
        jsonDecode(js.substring(js.indexOf('{'), js.lastIndexOf('}') + 1))
            as Map;
    expect(config.keys.toSet(),
        {'apiKey', 'projectId', 'storageBucket', 'messagingSenderId', 'appId'});
    expect(config['apiKey'], DefaultFirebaseOptions.web.apiKey);
    expect(config['appId'], DefaultFirebaseOptions.web.appId);
    expect(config['projectId'], DefaultFirebaseOptions.web.projectId);
    final flow = File('web/desktop-google-sign-in.js').readAsStringSync();
    expect(flow, contains('browserSessionPersistence'));
    expect(flow, contains("'yswords-desktop-google'"));
    expect(
        flow, isNot(contains('localStorage.'))); // Comments below also guarded.
    expect(flow, isNot(contains('client_secret')));
    expect(flow, isNot(contains('drive.file')));
    final auth =
        File('lib/services/cloud_auth_service.dart').readAsStringSync();
    expect(auth, contains('TargetPlatform.windows'));
    expect(auth, contains('await desktopGoogleCredential()'));
  });
}
