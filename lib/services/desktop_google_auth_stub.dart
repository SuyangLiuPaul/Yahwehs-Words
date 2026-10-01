import 'package:firebase_auth/firebase_auth.dart';

Future<AuthCredential> desktopGoogleCredential({String locale = 'en'}) async {
  throw FirebaseAuthException(
      code: 'operation-not-supported-in-this-environment');
}
