import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Play phone codes exceed the published code and stay below Wear', () {
    final workflow = File('.github/workflows/play-aab.yml').readAsStringSync();
    final phone = RegExp(r'--build-number=\$\(\((\d+) \+ GITHUB_RUN_NUMBER\)\)')
        .firstMatch(workflow);
    final wear =
        RegExp(r'-PwearVersionCode=\$\(\((\d+) \+ GITHUB_RUN_NUMBER\)\)')
            .firstMatch(workflow);
    expect(phone, isNotNull);
    expect(wear, isNotNull);
    final phoneBase = int.parse(phone!.group(1)!);
    final wearBase = int.parse(wear!.group(1)!);
    expect(phoneBase + 1, greaterThan(1006032));
    expect(phoneBase + 1000000, lessThan(wearBase));
    expect(wearBase + 1000000, lessThan(2100000000));
  });
}
