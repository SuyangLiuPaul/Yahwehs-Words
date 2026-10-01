import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'web credential acquisition preserves strict isolation and has a bounded one-use channel',
      () {
    final source =
        File('lib/services/web_google_auth_web.dart').readAsStringSync();
    expect(source, contains('Random.secure()'));
    expect(source, contains('32768'));
    expect(source, contains('16384'));
    expect(source, contains("value['state'] != state"));
    expect(source, contains("'_blank', 'noopener'"));
    expect(source, contains('Duration(minutes: 4)'));
    expect(source, contains('channel.close()'));
    expect(source, isNot(contains('web.window.opener')));
  });
  test(
      'web and Windows helper modes are mutually exclusive and never log tokens',
      () {
    final source = File('web/desktop-google-sign-in.js').readAsStringSync();
    expect(source, contains("!params.has('mode')"));
    expect(source, contains("webMode && !params.has('port')"));
    expect(source, contains('started.webMode !== webMode'));
    expect(source, contains('browserSessionPersistence'));
    expect(source, contains('new BroadcastChannel'));
    expect(source, isNot(contains('console.log')));
    expect(source, isNot(contains('localStorage.setItem')));
    expect(source, contains('127.0.0.1'));
  });
}
