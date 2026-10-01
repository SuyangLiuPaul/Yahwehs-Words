import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahwehs_words/services/google_auth_platform.dart';

class _Credential extends Fake implements UserCredential {}

class _User extends Fake implements User {
  String? method;
  AuthCredential? credential;
  AuthProvider? provider;
  FirebaseAuthException? error;
  final result = _Credential();

  Future<UserCredential> complete() async {
    if (error != null) throw error!;
    return result;
  }

  @override
  Future<UserCredential> reauthenticateWithCredential(AuthCredential value) {
    method = 'credential';
    credential = value;
    return complete();
  }

  @override
  Future<UserCredential> reauthenticateWithPopup(AuthProvider value) {
    method = 'popup';
    provider = value;
    return complete();
  }

  @override
  Future<UserCredential> reauthenticateWithProvider(AuthProvider value) {
    method = 'provider';
    provider = value;
    return complete();
  }
}

void main() {
  final credential = GoogleAuthProvider.credential(idToken: 'test-only-id');
  test('web uses the web reauthentication API, even on a Mac browser',
      () async {
    final user = _User();
    final result = await reauthenticateGoogleUser(user,
        isWeb: true, platform: TargetPlatform.macOS);
    expect(result, same(user.result));
    expect(user.method, 'popup');
    expect(user.provider, isA<GoogleAuthProvider>());
  });
  for (final platform in [TargetPlatform.windows, TargetPlatform.macOS]) {
    test('$platform reauthenticates the existing user using a credential',
        () async {
      final user = _User();
      var calls = 0;
      Future<AuthCredential> acquire() async {
        calls++;
        return credential;
      }

      await reauthenticateGoogleUser(user,
          isWeb: false,
          platform: platform,
          windowsCredential: acquire, macCredential: (provider) {
        expect(provider.scopes, isEmpty);
        return acquire();
      });
      expect(calls, 1);
      expect(user.method, 'credential');
      expect(user.credential, same(credential));
    });
    test('$platform cancellation never calls a user auth method', () async {
      final user = _User();
      Future<AuthCredential> cancel() async =>
          throw FirebaseAuthException(code: 'cancelled');
      await expectLater(
          reauthenticateGoogleUser(user,
              isWeb: false,
              platform: platform,
              windowsCredential: cancel,
              macCredential: (_) => cancel()),
          throwsA(isA<FirebaseAuthException>()
              .having((e) => e.code, 'code', 'cancelled')));
      expect(user.method, isNull);
    });
    test('$platform preserves the SDK wrong-account rejection', () async {
      final user = _User()
        ..error = FirebaseAuthException(code: 'user-mismatch');
      await expectLater(
          reauthenticateGoogleUser(user,
              isWeb: false,
              platform: platform,
              windowsCredential: () async => credential,
              macCredential: (_) async => credential),
          throwsA(isA<FirebaseAuthException>()
              .having((e) => e.code, 'code', 'user-mismatch')));
    });
  }
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    test('$platform retains the supported mobile provider flow', () async {
      final user = _User();
      await reauthenticateGoogleUser(user, isWeb: false, platform: platform);
      expect(user.method, 'provider');
      expect(user.provider, isA<GoogleAuthProvider>());
    });
  }
  for (final platform in [TargetPlatform.linux, TargetPlatform.fuchsia]) {
    test('$platform fails explicitly without invoking unsupported provider UI',
        () async {
      final user = _User();
      await expectLater(
          reauthenticateGoogleUser(user, isWeb: false, platform: platform),
          throwsA(isA<FirebaseAuthException>()));
      expect(user.method, isNull);
    });
  }
  test('account deletion awaits reauthentication before deleting cloud data',
      () {
    final source =
        File('lib/services/cloud_auth_service.dart').readAsStringSync();
    final deletion = source.substring(
        source.indexOf('Future<CloudAuthActionResult> deleteCurrentAccount'),
        source.indexOf('Future<bool> refreshDriveAccessToken'));
    expect(deletion.indexOf('await reauthenticateGoogleUser(user)'),
        lessThan(deletion.indexOf(".ref('users/")));
    final bridge =
        File('lib/services/google_auth_platform.dart').readAsStringSync();
    final reauth = bridge.substring(
        bridge.indexOf('Future<UserCredential> reauthenticateGoogleUser'));
    expect(reauth, isNot(contains('signInWithCredential')));
    expect(reauth, isNot(contains('FirebaseAuth.instance')));
  });
}
