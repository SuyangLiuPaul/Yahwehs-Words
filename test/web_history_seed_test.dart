/// The page starts the Flutter engine in single-entry history.
///
/// 2026-09-21. A prod crash on v1.6.28 (iOS home-screen web app, at
/// boot): "Null check operator used on a null value", thrown inside the
/// ENGINE's `MultiEntriesBrowserHistory.tearDown()` — `currentState!` —
/// during the handoff from the multi-entry history the engine builds
/// for a cold open to the single-entry history this app always uses.
/// `web/index.html` now tags the page's own entry as the engine's origin
/// entry before the engine starts, so it picks single-entry at once and
/// that handoff never happens. The long form is beside the script.
///
/// Two halves, because either can rot without the other noticing: the
/// page must still seed the tag BEFORE the bootstrap, and the engine
/// must still read that tag the way the seed assumes. The second half
/// reads the engine source out of the Flutter SDK running this test —
/// so a Flutter upgrade that renames the tag fails here, not in prod.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The Flutter SDK root, found by walking up from the running binary to
/// the directory that holds `packages/flutter`.
Directory? _flutterRoot() {
  var dir = File(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 12; i++) {
    if (Directory('${dir.path}/packages/flutter').existsSync()) return dir;
    final up = dir.parent;
    if (up.path == dir.path) break;
    dir = up;
  }
  final env = Platform.environment['FLUTTER_ROOT'];
  return env == null ? null : Directory(env);
}

void main() {
  test('the page tags its entry as the origin before the engine loads', () {
    final html = File('web/index.html').readAsStringSync();
    final seed = html.indexOf('window.history.replaceState({ origin: true');
    final boot = html.indexOf('<script src="flutter_bootstrap.js"');
    expect(seed, greaterThan(0), reason: 'the history seed is gone');
    expect(boot, greaterThan(0));
    expect(seed, lessThan(boot),
        reason: 'the seed must run before the engine creates its history, '
            'or the engine has already chosen multi-entry');
    // Only a cold open. A reload lands on the engine's own {flutter: true}
    // entry, and overwriting that would break Back after a refresh.
    expect(html, contains('window.history.state == null'),
        reason: 'the seed must leave an existing state alone');
  });

  test('the engine still starts single-entry from an origin-tagged state', () {
    final root = _flutterRoot();
    final src = root == null
        ? null
        : File('${root.path}/engine/src/flutter/lib/web_ui/lib/src/engine/'
            'navigation/history.dart');
    if (src == null || !src.existsSync()) {
      markTestSkipped('engine source not in this Flutter SDK');
      return;
    }
    final text = src.readAsStringSync();
    // The tag's name and value.
    expect(text, contains("static const String _kOriginTag = 'origin';"),
        reason: 'the engine renamed its origin tag; web/index.html seeds '
            "{origin: true} and would now be ignored");
    expect(text, contains('state[_kOriginTag] == true'));
    // And the decision the seed relies on: an origin-tagged state makes
    // createHistoryForExistingState pick SingleEntryBrowserHistory.
    final pick = text.indexOf('BrowserHistory createHistoryForExistingState(');
    final single = text.indexOf('return SingleEntryBrowserHistory(', pick);
    final originCheck =
        text.indexOf('SingleEntryBrowserHistory._isOriginEntry(state)', pick);
    expect(pick, greaterThan(0));
    expect(originCheck, allOf(greaterThan(pick), lessThan(single)),
        reason: 'the engine no longer starts single-entry from an origin '
            'entry — the seed in web/index.html would do nothing');
  });
}
