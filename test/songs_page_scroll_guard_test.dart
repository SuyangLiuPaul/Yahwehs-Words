import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A crash report (v1.6.30, web, route /songs): "Null check operator used
/// on a null value", from `scroll_to_index` revealing a row whose render
/// object had been detached by a rebuild. The call in
/// `SongsPage._onPlayerChanged` is `unawaited`, so an error from it is
/// nobody's to catch.
///
/// Pinned by source because the failure needs a list to rebuild between a
/// track change and the scroll, which a widget test cannot arrange
/// without reaching into the package's private tag map. If this is ever
/// rewritten as a real reproduction, delete this file.
void main() {
  test('the auto-scroll to the playing song swallows its own failure', () {
    final src = File('lib/pages/songs_page.dart').readAsStringSync();
    final start = src.indexOf('void _onPlayerChanged()');
    expect(start, greaterThan(0));
    final body = src.substring(start, src.indexOf('Widget build(', start));
    expect(body.contains('scrollToIndex('), isTrue);
    expect(body.contains('.catchError('), isTrue,
        reason: 'an unawaited scrollToIndex that can throw on a detached '
            'row must have a catchError, or it is an uncaught crash report');
  });
}
