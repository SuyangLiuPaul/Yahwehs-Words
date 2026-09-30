import 'package:firebase_core/firebase_core.dart';
// The platform interface is used only to replace the native SDK boundary.
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahwehs_words/firebase_options.dart';
import 'package:yahwehs_words/services/cloud_auth_service.dart';

class _FirebaseInitProbe extends FirebasePlatform {
  int calls = 0;
  FirebaseOptions? capturedOptions;

  @override
  Future<FirebaseAppPlatform> initializeApp({
    String? name,
    FirebaseOptions? options,
  }) async {
    calls++;
    capturedOptions = options;
    // Stop at the SDK boundary: this test exercises the real service's
    // configuration selection without authenticating or opening a socket.
    throw FirebaseException(plugin: 'test', code: 'probe-complete');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final originalDelegate = Firebase.delegatePackingProperty;
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    Firebase.delegatePackingProperty = originalDelegate;
  });

  test('Windows auth initialises Firebase with explicit project options',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    final probe = _FirebaseInitProbe();
    Firebase.delegatePackingProperty = probe;

    expect(firebaseConfigured, isTrue);
    await CloudAuthService.instance.retryInit();

    expect(probe.calls, 1);
    expect(probe.capturedOptions, DefaultFirebaseOptions.web);
    expect(probe.capturedOptions!.projectId, 'ysword');
    expect(probe.capturedOptions!.databaseURL, isNotEmpty);
  });

  for (final platform in [
    TargetPlatform.iOS,
    TargetPlatform.android,
    TargetPlatform.macOS,
  ]) {
    test('$platform retains native Firebase configuration loading', () async {
      debugDefaultTargetPlatformOverride = platform;
      final probe = _FirebaseInitProbe();
      Firebase.delegatePackingProperty = probe;

      await CloudAuthService.instance.retryInit();

      expect(probe.calls, 1);
      expect(probe.capturedOptions, isNull);
    });
  }
}
