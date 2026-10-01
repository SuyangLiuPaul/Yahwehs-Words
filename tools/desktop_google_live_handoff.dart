// Manual browser round-trip only; excluded from automatic CI test discovery.
// No token, user identifier or email is written to disk or test output.
import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahwehs_words/services/desktop_google_auth_io.dart';
import 'package:yahwehs_words/firebase_options.dart';

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
    // Exercise the same Firebase backend credential exchange that the
    // Windows SDK performs. Keep response tokens and account data in memory.
    final client = HttpClient();
    try {
      final request = await client.postUrl(Uri.https(
          'identitytoolkit.googleapis.com',
          '/v1/accounts:signInWithIdp',
          {'key': DefaultFirebaseOptions.web.apiKey}));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({
        'postBody': Uri(queryParameters: {
          'providerId': 'google.com',
          if (credential.idToken?.isNotEmpty ?? false)
            'id_token': credential.idToken!,
          if (credential.accessToken?.isNotEmpty ?? false)
            'access_token': credential.accessToken!,
        }).query,
        'requestUri': 'http://localhost',
        'returnSecureToken': false,
      }));
      final response = await request.close();
      final body = jsonDecode(await utf8.decoder.bind(response).join()) as Map;
      // Only compare booleans: failing tests must not print credential payloads.
      expect(response.statusCode == 200, isTrue);
      expect(body['providerId'] == 'google.com', isTrue);
      expect(body['localId'] is String, isTrue);
    } finally {
      client.close(force: true);
    }
    await File(
            '/Users/pliu0036/Downloads/Yahweh-Publication-Assets-20261001/windows-browser-google-live-handoff.json')
        .writeAsString(jsonEncode({
      'checkedAt': DateTime.now().toUtc().toIso8601String(),
      'origin': 'https://yswords-dev.netlify.app',
      'googleIssuerVerified': hasIdToken,
      'expectedProjectClientAudience': hasIdToken,
      'receivedGoogleCredential': true,
      'firebaseBackendCredentialExchangeVerified': true,
      'physicalWindowsFirebaseExchangeVerified': false
    }));
  }, timeout: const Timeout(Duration(minutes: 6)));
}
