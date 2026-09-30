import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Play code follows the Gradle version-name policy below Wear codes', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    final workflow = File('.github/workflows/play-aab.yml').readAsStringSync();
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(gradle, contains('versionCode = flutter.versionName'));
    expect(gradle, contains('p.getOrElse(0) { 0 } * 1_000_000'));
    expect(gradle, contains('p.getOrElse(1) { 0 } * 1_000'));
    expect(gradle, contains('p.getOrElse(2) { 0 }'));
    final build =
        workflow.split('run: flutter build appbundle').last.split('\n').first;
    expect(build, isNot(contains('--build-number=')));
    final version = RegExp(r'^version: (\d+)\.(\d+)\.(\d+)', multiLine: true)
        .firstMatch(pubspec)!;
    final parts = [1, 2, 3].map((i) => int.parse(version.group(i)!)).toList();
    expect(parts[1], lessThan(1000));
    expect(parts[2], lessThan(1000));
    final code = parts[0] * 1000000 + parts[1] * 1000 + parts[2];
    final wear =
        RegExp(r'-PwearVersionCode=\$\(\((\d+) \+ GITHUB_RUN_NUMBER\)\)')
            .firstMatch(workflow)!;
    expect(code, greaterThan(1006032));
    expect(code, lessThan(int.parse(wear.group(1)!)));
  });
}
