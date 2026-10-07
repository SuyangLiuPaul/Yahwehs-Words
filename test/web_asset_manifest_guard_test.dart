import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Flutter manifest verifier rejects missing and mismatched payloads', () {
    final result =
        Process.runSync('python3', ['tools/test_web_asset_manifests.py']);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
  });
}
