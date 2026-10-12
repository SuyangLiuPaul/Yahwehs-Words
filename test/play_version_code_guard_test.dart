import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Play phone and Wear codes use monotonic disjoint ranges', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    final workflow = File('.github/workflows/play-aab.yml').readAsStringSync();
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(gradle, contains('project.findProperty("playVersionCode")'));
    expect(pubspec, contains('version: 1.7.21'));
    final phone = RegExp(r'playVersionCode=\$\(\((\d+) \+ GITHUB_RUN_NUMBER\)\)')
        .firstMatch(workflow)!;
    final wear = RegExp(r'-PwearVersionCode=\$\(\((\d+) \+ GITHUB_RUN_NUMBER\)\)')
        .firstMatch(workflow)!;
    expect(int.parse(phone.group(1)!), greaterThan(int.parse(wear.group(1)!)));
    expect(int.parse(wear.group(1)!), greaterThanOrEqualTo(20001000));
    expect(workflow, contains('wear-release.aab'));
    expect(workflow, contains('app-intl-release.aab build/wear/outputs/bundle/release/wear-release.aab'));
  });
}
