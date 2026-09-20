// The splash holds long enough to read the verse — 2026-09-20.
//
// It was a fixed 3 s. The feedback that changed it: 「都没有看清楚就
// 进去了」 — the verse was gone before it had been read. Now the reader
// sets the hold (10 s by default) and can leave at once with the button
// on the splash, so a longer default costs nobody time.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahwehs_words/models/app_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ten seconds by default, not three', () async {
    SharedPreferences.setMockInitialValues({});
    final s = AppSettings();
    await s.loadSettings();
    expect(s.splashSeconds, 10);
    expect(kSplashSecondsDefault, 10);
  });

  test('the reader can change it, and it survives a restart', () async {
    SharedPreferences.setMockInitialValues({});
    final first = AppSettings();
    await first.loadSettings();
    await first.setSplashSeconds(20);

    final second = AppSettings();
    await second.loadSettings();
    expect(second.splashSeconds, 20);
  });

  test('a hand-edited preference cannot park the reader on the splash',
      () async {
    SharedPreferences.setMockInitialValues({'splashSeconds': 600});
    final s = AppSettings();
    await s.loadSettings();
    expect(s.splashSeconds, kSplashSecondsMax);

    await s.setSplashSeconds(0);
    expect(s.splashSeconds, kSplashSecondsMin);
  });

  test('reset puts it back to the default', () async {
    SharedPreferences.setMockInitialValues({});
    final s = AppSettings();
    await s.loadSettings();
    await s.setSplashSeconds(25);
    await s.resetAllSettings();
    expect(s.splashSeconds, kSplashSecondsDefault);

    final after = AppSettings();
    await after.loadSettings();
    expect(after.splashSeconds, kSplashSecondsDefault);
  });
}
