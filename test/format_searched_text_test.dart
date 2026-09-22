// 2026-09-23: `formatSearchText()` is the highlighter behind every
// text-search result row (`search_page.dart:1977`, called with
// `sanitizeForSearch(verse.text)` as `input` and
// `fuzzySearchHighlightQuery(query)` as `text`) and had zero test
// references before this file — a user-visible reading surface with
// no guard at all.
//
// This pins EXISTING behaviour (characterization, not redesign),
// including the two structurally-unavoidable empty-string spans a
// match at index 0 or running to the end of the string produces —
// `substring(0, 0)` and `substring(length)` are both `''`, and the
// implementation adds them unconditionally.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yahwehs_words/constants/text_patterns.dart'
    show sanitizeForSearch;
import 'package:yahwehs_words/utils/format_searched_text.dart';
import 'package:yahwehs_words/utils/fuzzy_result_label.dart'
    show fuzzySearchHighlightQuery;

/// Pumps a bare [MaterialApp] and hands back the [BuildContext] +
/// resolved primary color `formatSearchText` reads via `Theme.of`.
Future<(BuildContext, Color)> _pumpContext(WidgetTester tester) async {
  late BuildContext ctx;
  late Color primary;
  await tester.pumpWidget(MaterialApp(
    home: Builder(builder: (context) {
      ctx = context;
      primary = Theme.of(context).colorScheme.primary;
      return const SizedBox();
    }),
  ));
  return (ctx, primary);
}

List<TextSpan> _spans(Text t) =>
    (t.textSpan as TextSpan).children!.cast<TextSpan>();

bool _isHighlighted(TextSpan s, Color primary) =>
    s.style?.color == primary && s.style?.fontWeight == FontWeight.bold;

void main() {
  testWidgets('a single literal hit splits into before / highlighted / after',
      (tester) async {
    final (ctx, primary) = await _pumpContext(tester);

    final result = formatSearchText(
      input: 'In the beginning God created',
      text: 'God',
      context: ctx,
    );

    final spans = _spans(result);
    expect(spans.length, 3);
    expect(spans[0].text, 'In the beginning ');
    expect(_isHighlighted(spans[0], primary), isFalse);
    expect(spans[1].text, 'God');
    expect(_isHighlighted(spans[1], primary), isTrue);
    expect(spans[2].text, ' created');
    expect(_isHighlighted(spans[2], primary), isFalse);
  });

  testWidgets(
      'multiple non-adjacent hits all highlight, in order, and every span '
      'reassembles the input byte-for-byte', (tester) async {
    final (ctx, primary) = await _pumpContext(tester);
    const input = 'cat sat cat mat cat';

    final result = formatSearchText(input: input, text: 'cat', context: ctx);
    final spans = _spans(result);

    // pre1, hit1, pre2, hit2, pre3, hit3, remainder.
    expect(spans.length, 7);
    for (final i in [1, 3, 5]) {
      expect(spans[i].text, 'cat');
      expect(_isHighlighted(spans[i], primary), isTrue,
          reason: 'span $i should be highlighted');
    }
    for (final i in [0, 2, 4, 6]) {
      expect(_isHighlighted(spans[i], primary), isFalse,
          reason: 'span $i should not be highlighted');
    }

    final reassembled = spans.map((s) => s.text).join();
    expect(reassembled, input);
  });

  testWidgets('English matching is case-insensitive', (tester) async {
    final (ctx, primary) = await _pumpContext(tester);
    const input = 'God is good, GOD is great';

    final result = formatSearchText(input: input, text: 'god', context: ctx);
    final spans = _spans(result);

    final highlighted =
        spans.where((s) => _isHighlighted(s, primary)).map((s) => s.text);
    expect(highlighted, ['God', 'GOD'],
        reason: 'the original casing of each hit is preserved verbatim');
    expect(spans.map((s) => s.text).join(), input);
  });

  testWidgets('CJK matching is an exact character run', (tester) async {
    final (ctx, primary) = await _pumpContext(tester);
    const input = '耶和华是我的牧者，耶和华也是爱';

    final result =
        formatSearchText(input: input, text: '耶和华', context: ctx);
    final spans = _spans(result);

    final highlighted =
        spans.where((s) => _isHighlighted(s, primary)).map((s) => s.text);
    expect(highlighted, ['耶和华', '耶和华']);
    expect(spans.map((s) => s.text).join(), input);
  });

  testWidgets('empty input returns a plain Text, not Text.rich',
      (tester) async {
    final (ctx, _) = await _pumpContext(tester);

    final result = formatSearchText(input: '', text: 'abc', context: ctx);

    expect(result.textSpan, isNull);
    expect(result.data, '');
  });

  testWidgets('empty query returns a plain Text carrying the input verbatim',
      (tester) async {
    final (ctx, _) = await _pumpContext(tester);

    final result = formatSearchText(input: 'abc', text: '', context: ctx);

    expect(result.textSpan, isNull);
    expect(result.data, 'abc');
  });

  group('a query containing regex metacharacters is matched literally', () {
    testWidgets('a bare "." does not act as any-character', (tester) async {
      final (ctx, primary) = await _pumpContext(tester);
      const input = '3.14 and 3x14';

      final result =
          formatSearchText(input: input, text: '3.14', context: ctx);
      final spans = _spans(result);

      final highlighted =
          spans.where((s) => _isHighlighted(s, primary)).map((s) => s.text);
      expect(highlighted, ['3.14'],
          reason: '"3x14" must not match if "." is escaped, not any-char');
      expect(spans.map((s) => s.text).join(), input);
    });

    testWidgets('parentheses do not act as a capture group', (tester) async {
      final (ctx, primary) = await _pumpContext(tester);
      const input = 'say (maybe) once';

      final result =
          formatSearchText(input: input, text: '(maybe)', context: ctx);
      final spans = _spans(result);

      expect(spans.length, 3);
      expect(spans[1].text, '(maybe)');
      expect(_isHighlighted(spans[1], primary), isTrue);
      expect(spans.map((s) => s.text).join(), input);
    });

    testWidgets('a bare "*" does not act as a repetition quantifier',
        (tester) async {
      final (ctx, primary) = await _pumpContext(tester);
      const input = 'try *not* this';

      final result =
          formatSearchText(input: input, text: '*not*', context: ctx);
      final spans = _spans(result);

      expect(spans.length, 3);
      expect(spans[1].text, '*not*');
      expect(_isHighlighted(spans[1], primary), isTrue);
      expect(spans.map((s) => s.text).join(), input);
    });
  });

  group('a hit at a string boundary produces no range error', () {
    testWidgets('a hit at index 0', (tester) async {
      final (ctx, primary) = await _pumpContext(tester);
      const input = 'catdog';

      final result = formatSearchText(input: input, text: 'cat', context: ctx);
      final spans = _spans(result);

      expect(spans.length, 3);
      expect(spans[0].text, '');
      expect(spans[1].text, 'cat');
      expect(_isHighlighted(spans[1], primary), isTrue);
      expect(spans[2].text, 'dog');
      expect(spans.map((s) => s.text).join(), input);
    });

    testWidgets('a hit running to the end of the string', (tester) async {
      final (ctx, primary) = await _pumpContext(tester);
      const input = 'dogcat';

      final result = formatSearchText(input: input, text: 'cat', context: ctx);
      final spans = _spans(result);

      expect(spans.length, 3);
      expect(spans[0].text, 'dog');
      expect(spans[1].text, 'cat');
      expect(_isHighlighted(spans[1], primary), isTrue);
      expect(spans[2].text, '');
      expect(spans.map((s) => s.text).join(), input);
    });

    testWidgets('a hit that is the entire string', (tester) async {
      final (ctx, primary) = await _pumpContext(tester);
      const input = 'cat';

      final result = formatSearchText(input: input, text: 'cat', context: ctx);
      final spans = _spans(result);

      expect(spans.length, 3);
      expect(spans[0].text, '');
      expect(spans[1].text, 'cat');
      expect(_isHighlighted(spans[1], primary), isTrue);
      expect(spans[2].text, '');
    });
  });

  testWidgets(
      'the real call-site shape: a note-stripped, brace-unwrapped, '
      'divine-name-normalized verse and the same-sanitized query', (tester) async {
    final (ctx, primary) = await _pumpContext(tester);

    const verse = 'In the beginning<note: creation account> God created '
        '{the heavens} and 耶和华 saw it was good';
    final sanitizedVerse = sanitizeForSearch(verse);
    // Pin the fixture's own preconditions, so a future change to
    // sanitizeForSearch's rules fails here first, not as a mysterious
    // "highlight lands nowhere" below.
    expect(sanitizedVerse.contains('<note:'), isFalse);
    expect(sanitizedVerse.contains('{'), isFalse);
    expect(sanitizedVerse, contains('the heavens'));
    expect(sanitizedVerse, contains('雅伟'));

    final highlightQuery = fuzzySearchHighlightQuery('耶和华');
    expect(highlightQuery, '雅伟',
        reason: 'search_page.dart:1979 — both sides must be sanitized the '
            'same way or a query for 耶和华 marks nothing in a 雅伟 verse');

    final result = formatSearchText(
      input: sanitizedVerse,
      text: highlightQuery,
      context: ctx,
    );
    final spans = _spans(result);

    final highlighted =
        spans.where((s) => _isHighlighted(s, primary)).map((s) => s.text);
    expect(highlighted, ['雅伟']);
    expect(spans.map((s) => s.text).join(), sanitizedVerse);
  });

  testWidgets(
      'a multi-word query only highlights where the contiguous run appears '
      '(current behaviour: the words are matched as one literal phrase)',
      (tester) async {
    final (ctx, primary) = await _pumpContext(tester);

    final matching = formatSearchText(
      input: 'for god so loved the world',
      text: 'god so loved',
      context: ctx,
    );
    final matchingSpans = _spans(matching);
    expect(
      matchingSpans.where((s) => _isHighlighted(s, primary)).map((s) => s.text),
      ['god so loved'],
    );

    // No match: the early-return in formatSearchText only fires for an
    // EMPTY input/text, not a failed match, so this still comes back as
    // Text.rich — with a single, unhighlighted span holding the whole
    // input unchanged.
    final nonMatching = formatSearchText(
      input: 'god so very much loved the world',
      text: 'god so loved',
      context: ctx,
    );
    final nonMatchingSpans = _spans(nonMatching);
    expect(nonMatchingSpans.length, 1);
    expect(nonMatchingSpans.single.text, 'god so very much loved the world');
    expect(_isHighlighted(nonMatchingSpans.single, primary), isFalse);
  });
}
