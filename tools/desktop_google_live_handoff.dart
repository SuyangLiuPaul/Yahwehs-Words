// Manual browser round-trip only; excluded from automatic CI test discovery.
// No token, user identifier or email is written to disk or test output.
import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahwehs_words/services/desktop_google_auth_io.dart';

void main() {
  test('live Google browser response reaches the bounded desktop bridge',
      () async {
    final bridge = DesktopGoogleBridge(
        origin: 'https://yswords-dev.netlify.app',
        openBrowser: (uri) async {
          await File('/tmp/yswords-desktop-google-live-url.txt')
              .writeAsString(uri.toString());
          return true;
        });
    final credential =
        await bridge.signIn(locale: 'zh-Hans') as OAuthCredential;
    final hasIdToken = credential.idToken?.isNotEmpty ?? false;
    if (hasIdToken) {
      final parts = credential.idToken!.split('.');
      expect(parts.length, 3);
      final claims = jsonDecode(
          utf8.decode(base64Url.decode(base64Url.normalize(parts[1])))) as Map;
      expect(claims['iss'],
          anyOf('https://accounts.google.com', 'accounts.google.com'));
      expect(claims['aud'],
          '461522287670-a1vgu2ganbmf373b6u7nr6pfju21u50r.apps.googleusercontent.com');
    }
    expect(hasIdToken || (credential.accessToken?.isNotEmpty ?? false), isTrue);
    await File(
            '/Users/pliu0036/Downloads/Yahweh-Publication-Assets-20261001/windows-browser-google-live-handoff.json')
        .writeAsString(jsonEncode({
      'checkedAt': DateTime.now().toUtc().toIso8601String(),
      'origin': 'https://yswords-dev.netlify.app',
      'googleIssuerVerified': hasIdToken,
      'expectedProjectClientAudience': hasIdToken,
      'receivedGoogleCredential': true,
      'physicalWindowsFirebaseExchangeVerified': false
    }));
  }, timeout: const Timeout(Duration(minutes: 6)));
}
