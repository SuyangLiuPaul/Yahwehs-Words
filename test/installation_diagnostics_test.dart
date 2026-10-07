import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahwehs_words/services/installation_diagnostics.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    InstallationDiagnostics.clearMemoryForTest();
  });
  test('random valid ID persists across restart', () async {
    final first = await InstallationDiagnostics.id();
    expect(InstallationDiagnostics.validId(first), isTrue);
    InstallationDiagnostics.clearMemoryForTest();
    expect(await InstallationDiagnostics.id(), first);
  });
  test('parallel reads use one identity', () async {
    final ids = await Future.wait(
        List.generate(30, (_) => InstallationDiagnostics.id()));
    expect(ids.toSet().length, 1);
  });
  test('invalid stored identities are replaced', () async {
    SharedPreferences.setMockInitialValues(
        {InstallationDiagnostics.preferenceKey: '<secret>'});
    expect(InstallationDiagnostics.validId(await InstallationDiagnostics.id()),
        isTrue);
  });
  test('reset replaces and persists identity without overlap', () async {
    final old = await InstallationDiagnostics.id();
    await Future.wait(
        [InstallationDiagnostics.reset(), InstallationDiagnostics.reset()]);
    final next = await InstallationDiagnostics.id();
    expect(next, isNot(old));
    InstallationDiagnostics.clearMemoryForTest();
    expect(await InstallationDiagnostics.id(), next);
  });
  test('diagnosis payload has no hardware, key or content fields', () async {
    final payload = await InstallationDiagnostics.snapshot();
    expect(payload.keys.toSet(), {
      'diagnosisId',
      'app',
      'appVersion',
      'platform',
      'channel',
      'idPersistent',
      'companions',
      'events'
    });
  });
  test('companion identities accept supported random IDs only', () async {
    InstallationDiagnostics.companion('watchos', 'YD-${'a' * 32}');
    InstallationDiagnostics.companion('wearos', 'hardware serial');
    InstallationDiagnostics.companion('unknown', 'YD-${'b' * 32}');
    expect((await InstallationDiagnostics.snapshot())['companions'],
        {'watchos': 'YD-${'a' * 32}'});
  });
  test('local events are bounded, enum-only and detached snapshots', () async {
    InstallationDiagnostics.record('audio', 'https://secret.example/key');
    InstallationDiagnostics.record('secret', 'playing');
    for (var i = 0; i < 60; i++) {
      InstallationDiagnostics.record('audio', i.isEven ? 'playing' : 'paused');
    }
    final events = (await InstallationDiagnostics.snapshot())['events'] as List;
    expect(events.length, 20);
    events.clear();
    expect(
        ((await InstallationDiagnostics.snapshot())['events'] as List).length,
        20);
  });
}
