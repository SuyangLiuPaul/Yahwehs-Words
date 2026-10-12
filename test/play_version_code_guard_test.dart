import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Play phone and Wear codes increase across shared-package releases', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    final workflow = File('.github/workflows/play-aab.yml').readAsStringSync();
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final appVersion = File('lib/constants/app_version.dart').readAsStringSync();
    expect(gradle, contains('project.findProperty("playVersionCode")'));
    final version = RegExp(r'^version: (\d+\.\d+\.\d+)', multiLine: true)
        .firstMatch(pubspec)!
        .group(1)!;
    expect(appVersion, contains("defaultValue: '$version'"));
    expect(appVersion, contains("? '$version' : _envAppVersion"));
    final phone = RegExp(r'playVersionCode=\$\(\(([^)]+)\)\)')
        .firstMatch(workflow)!;
    final wear = RegExp(r'-PwearVersionCode=\$\(\(([^)]+)\)\)')
        .firstMatch(workflow)!;
    int code(Match expression, int run) {
      final result = Process.runSync('bash', [
        '-c',
        'GITHUB_RUN_NUMBER=$run; printf "%s" \$(( ${expression.group(1)} ))',
      ]);
      expect(result.exitCode, 0);
      return int.parse(result.stdout as String);
    }

    // Play validates both form factors against all existing bundles. The
    // historical phone maximum was 20,002,028 when this allocation was fixed.
    for (final run in [30, 31, 100, 10000]) {
      final phoneCode = code(phone, run);
      final wearCode = code(wear, run);
      expect(phoneCode, greaterThan(20002028));
      expect(wearCode, greaterThan(phoneCode));
      expect(code(phone, run + 1), greaterThan(wearCode));
      expect(wearCode, lessThanOrEqualTo(2100000000));
    }
    expect(workflow, contains('wear-release.aab'));
    expect(workflow, contains('app-intl-release.aab build/wear/outputs/bundle/release/wear-release.aab'));
  });
}
