import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart' as gsi;

import 'desktop_google_auth.dart';

/// Mac Firebase supports credentials, but not the generic Google provider UI.
/// Reauthentication must obtain a credential without replacing currentUser.
Future<AuthCredential> macGoogleCredential(GoogleAuthProvider provider) async {
  final signIn = gsi.GoogleSignIn(
    scopes:
        provider.scopes.isEmpty ? const ['email', 'profile'] : provider.scopes,
  );
  final account = await signIn.signIn();
  if (account == null) {
    throw FirebaseAuthException(
      code: 'cancelled',
      message: 'Google sign-in cancelled by user.',
    );
  }
  final auth = await account.authentication;
  if (auth.idToken == null && auth.accessToken == null) {
    throw FirebaseAuthException(code: 'invalid-credential');
  }
  return GoogleAuthProvider.credential(
    idToken: auth.idToken,
    accessToken: auth.accessToken,
  );
}

Future<UserCredential> reauthenticateGoogleUser(
  User user, {
  bool isWeb = kIsWeb,
  TargetPlatform? platform,
  Future<AuthCredential> Function()? windowsCredential,
  Future<AuthCredential> Function(GoogleAuthProvider)? macCredential,
}) async {
  final provider = GoogleAuthProvider();
  if (isWeb) return user.reauthenticateWithPopup(provider);
  switch (platform ?? defaultTargetPlatform) {
    case TargetPlatform.windows:
      final credential = await (windowsCredential ?? desktopGoogleCredential)();
      return user.reauthenticateWithCredential(credential);
    case TargetPlatform.macOS:
      final credential = await (macCredential ?? macGoogleCredential)(provider);
      return user.reauthenticateWithCredential(credential);
    case TargetPlatform.iOS:
    case TargetPlatform.android:
      return user.reauthenticateWithProvider(provider);
    case TargetPlatform.linux:
    case TargetPlatform.fuchsia:
      throw FirebaseAuthException(
          code: 'operation-not-supported-in-this-environment');
  }
}
