// The position pill follows a page turn — 2026-09-20.
//
// Reported from a phone: 「当我words翻到下一页 你看那个bar没有跟着一起
// 动」. The pill (e.g. "3 / 27") kept the previous chapter's reading
// until the reader scrolled vertically.
//
// Two causes, both guarded below:
//
//   1. `_attachPositionsListener` re-subscribes to the new page's
//      `itemPositions` but never reads it. That is a ValueNotifier:
//      it fires on CHANGE, and the incoming page was already laid out
//      and settled (AutomaticKeepAliveClientMixin) before we
//      subscribed — so nothing fires and nothing updates.
//   2. `_switchTo` reset `_visibleItemIndexNotifier`, which the pill
//      does not read, and left `_visibleItemPosNotifier` /
//      `_chapterProgressNotifier` — which it does — on the old
//      chapter's values.
//
// This is a SOURCE guard, not a behavioural one: nothing in this suite
// mounts BibleReadingPane (it needs the full provider stack, the asset
// corpus and a live ScrollablePositionedList), so there is no page turn
// to drive here. It fails if either invariant is removed, which is what
// makes the fix hard to undo by accident. The arithmetic the pill does
// with these values is covered by progress_pill_geometry_test.dart.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source =
      File('lib/widgets/bible_reading_pane.dart').readAsStringSync();

  String bodyOf(String signature) {
    final start = source.indexOf(signature);
    expect(start, isNot(-1), reason: '$signature is gone — rename?');
    // Brace-match from the signature to the end of the method.
    final open = source.indexOf('{', start);
    var depth = 0;
    for (var i = open; i < source.length; i++) {
      if (source[i] == '{') depth++;
      if (source[i] == '}') {
        depth--;
        if (depth == 0) return source.substring(start, i + 1);
      }
    }
    fail('unbalanced braces reading $signature');
  }

  test('subscribing to the new page also reads it once', () {
    final body = bodyOf('void _attachPositionsListener(MainProvider provider)');
    expect(body, contains('addListener(_handleItemPositionsChanged)'),
        reason: 'it must still subscribe');
    expect(
      RegExp(r'^\s*_handleItemPositionsChanged\(\);', multiLine: true)
          .hasMatch(body),
      isTrue,
      reason: 'and must CALL it once after subscribing — a settled '
          'ValueNotifier delivers nothing on attach, which is exactly '
          'why the pill froze on a page turn',
    );
  });

  test('a chapter switch clears the two values the pill reads', () {
    final body = bodyOf('void _switchTo(MainProvider provider');
    for (final notifier in [
      '_visibleItemPosNotifier',
      '_chapterProgressNotifier',
    ]) {
      expect(body, contains('$notifier.value = 0'),
          reason: '$notifier is what the pill reads; stale it shows the '
              "old chapter's verse against the new chapter's total");
    }
  });

  test('the pill really does read those two, so the guard above means '
      'something', () {
    // If the pill is ever rewired to different notifiers, the test
    // above would keep passing while guarding nothing.
    final pill = source.substring(source.indexOf('_VerticalProgressIndicator('
        '\n'));
    expect(source, contains('valueListenable: _visibleItemPosNotifier'));
    expect(source, contains('valueListenable: _chapterProgressNotifier'));
    expect(pill, isNotEmpty);
  });
}
