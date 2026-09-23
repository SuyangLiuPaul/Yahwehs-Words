import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahwehs_words/models/app_settings.dart';
import 'package:yahwehs_words/models/verse.dart';
import 'package:yahwehs_words/utils/build_verse_content_spans.dart';

/// `buildVerseContentSpans` (`lib/utils/build_verse_content_spans.dart`) is
/// the single choke point that turns `verse.text` into what a reader
/// actually sees, in every reading surface the app has. The two existing
/// tests that touch it — `editorial_bracket_render_test.dart` and
/// `verse_number_tap_test.dart` — each check one feature (bracket
/// preservation, verse-number tap/copy). Neither asserts the more basic
/// property both of them lean on without saying so: that no character of
/// the source verse is silently dropped on the way to the screen.
///
/// This file is that invariant, checked directly, against the documented
/// transformations the builder is supposed to make (verse-number
/// widget, note-marker superscripts, `collapseAnnotationSpacing`,
/// bracket styling/stripping) rather than against any one of them.
void main() {
  /// Renders [text] through the real span builder inside a live widget
  /// tree, the same shape `editorial_bracket_render_test.dart` uses, and
  /// returns the plain text the TOP-LEVEL `RichText` produces.
  ///
  /// `{...}` badges render as a nested widget subtree (their own `Text`/
  /// `RichText` inside a `WidgetSpan`'s child), which `toPlainText` never
  /// sees — see `textAnywhereInTree` below for how that content is
  /// checked instead. The verse-number span is also a `WidgetSpan`, so it
  /// never appears in this return value regardless of `showVerseNumber`;
  /// that toggle is checked separately with `find.text`.
  Future<String> renderPlainText(
    WidgetTester tester,
    String text, {
    String? versionCode,
    bool showVerseNumber = true,
    bool superscriptVerseNum = false,
    bool isSelected = false,
    String paragraphType = 'inline',
    List<String>? noteSink,
  }) async {
    late List<InlineSpan> spans;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (context) {
          spans = buildVerseContentSpans(
            verse: Verse(
              book: '馬太福音',
              chapter: 1,
              verse: 20,
              verseLabel: '20',
              text: text,
              paragraphType: paragraphType,
            ),
            context: context,
            settings: AppSettings(),
            locale: 'zh-Hant',
            isSelected: isSelected,
            versionCode: versionCode,
            showVerseNumber: showVerseNumber,
            superscriptVerseNum: superscriptVerseNum,
            noteSink: noteSink,
          );
          return RichText(text: TextSpan(children: spans));
        }),
      ),
    ));
    final rich = tester.widget<RichText>(find.byType(RichText).first);
    return rich.text.toPlainText(includePlaceholders: false);
  }

  /// Whether [needle] appears in any `Text` or `RichText` in the rendered
  /// tree — used for `{...}` badge content, which reaches the screen
  /// through a nested widget rather than the top-level `RichText`'s flat
  /// span list (see the `{...}` group below for why).
  bool textAnywhereInTree(WidgetTester tester, String needle) {
    for (final t in tester.widgetList<Text>(find.byType(Text))) {
      if (t.data?.contains(needle) == true) return true;
    }
    for (final rt in tester.widgetList<RichText>(find.byType(RichText))) {
      if (rt.text.toPlainText().contains(needle)) return true;
    }
    return false;
  }

  group('plain text with no annotations survives verbatim', () {
    testWidgets('CJK', (tester) async {
      const text = '起初，神創造天地。地是空虛混沌，淵面黑暗。';
      expect(await renderPlainText(tester, text), text);
    });

    testWidgets('Latin', (tester) async {
      const text =
          'In the beginning God created the heavens and the earth.';
      expect(await renderPlainText(tester, text), text);
    });
  });

  group('[...] square brackets', () {
    testWidgets('an allowlisted edition keeps the brackets themselves',
        (tester) async {
      const text = '正思念這事的時候，有主[雅偉]的使者向他夢中顯現，';
      final out =
          await renderPlainText(tester, text, versionCode: 'cuvs-yhwh-tr');
      expect(out, text,
          reason: 'cuvs-yhwh(-tr) brackets ARE the edition\'s own '
              'notation; nothing about the string should change');
    });

    testWidgets(
        'a non-allowlisted edition strips the brackets, keeps the word',
        (tester) async {
      final out = await renderPlainText(
        tester,
        'Now [the] angel of [the] Lord appeared',
        versionCode: 'leb',
      );
      expect(out, 'Now the angel of the Lord appeared');
    });

    testWidgets('a null versionCode falls back to stripping too',
        (tester) async {
      final out = await renderPlainText(tester, '有主[雅偉]的使者');
      expect(out, '有主雅偉的使者');
    });
  });

  group('{...} clarification braces', () {
    testWidgets('the inner text reaches the screen, via a nested widget',
        (tester) async {
      const annotation = 'they exist no longer';
      await renderPlainText(
          tester, 'because {$annotation} the exile is over');
      expect(textAnywhereInTree(tester, annotation), isTrue,
          reason: 'the {...} badge is a WidgetSpan holding its own Text/'
              'RichText — the content must still be somewhere in the '
              'rendered tree even though the OUTER RichText cannot see it');
    });

    testWidgets('…and is therefore invisible to the flat top-level text',
        (tester) async {
      const annotation = 'they exist no longer';
      final flat = await renderPlainText(
          tester, 'because {$annotation} the exile is over');
      expect(flat, isNot(contains(annotation)),
          reason: 'documents the WidgetSpan boundary the test above '
              'checks around, not a defect: toPlainText only walks the '
              'outer TextSpan tree, so a WidgetSpan child\'s own Text is '
              'structurally invisible to it');
    });

    testWidgets(
        'a note directly after a brace is suppressed, not given its own marker',
        (tester) async {
      // Same `splitMapJoin` empty-part artifact as the adjacent-notes
      // case above, but between a `{...}` and a `<note:...>` instead of
      // two notes: the brace chip is already the tap target for this
      // note (its own onTap extracts the note text straight out of
      // `verse.text`), so the note must not ALSO render a superscript.
      final noteSink = <String>[];
      final out = await renderPlainText(
        tester,
        '看哪{注解}<note:額外附註>，日子將到',
        noteSink: noteSink,
      );
      expect(out, '看哪，日子將到',
          reason: 'no superscript marker for the suppressed note — only '
              'the brace chip (a WidgetSpan, invisible to toPlainText) '
              'sits between the two halves of the sentence');
      expect(noteSink, isEmpty,
          reason: 'the note is reachable through the brace chip\'s own '
              'dialog, not the notes block, so it must not also land in '
              'noteSink');
      expect(textAnywhereInTree(tester, '注解'), isTrue,
          reason: 'the brace badge itself still renders normally');
    });
  });

  group('<note: ...> markers', () {
    testWidgets(
        'a mid-verse marker moves its text to noteSink, leaves a superscript',
        (tester) async {
      final noteSink = <String>[];
      final out = await renderPlainText(
        tester,
        '看哪<note:編者按：這是插入語>，日子將到，',
        noteSink: noteSink,
      );
      expect(noteSink, ['編者按：這是插入語']);
      expect(out, '看哪①，日子將到，');
    });

    testWidgets('a verse-final marker does the same at the end of the line',
        (tester) async {
      final noteSink = <String>[];
      final out = await renderPlainText(
        tester,
        '日子將到，我要與以色列家另立新約<note:耶卅一：卅一以下>',
        noteSink: noteSink,
      );
      expect(noteSink, ['耶卅一：卅一以下']);
      expect(out, '日子將到，我要與以色列家另立新約①');
    });

    testWidgets('two notes separated by text both survive, in order',
        (tester) async {
      final noteSink = <String>[];
      final out = await renderPlainText(
        tester,
        '看哪<note:注一>，又如此<note:注二>。',
        noteSink: noteSink,
      );
      expect(noteSink, ['注一', '注二']);
      expect(out, '看哪①，又如此②。');
    });

    testWidgets('no noteSink falls back to a tappable icon, not lost text',
        (tester) async {
      // `noteSink: null` is the OTHER live path (dialogs, not the
      // under-line block) — the note text isn't in the flat text either
      // way, but here it must still be reachable via the icon's dialog,
      // not simply gone.
      await renderPlainText(tester, '看哪<note:編者按>，日子將到');
      expect(find.byIcon(Icons.notes_rounded), findsOneWidget);
    });

    testWidgets('two directly-adjacent markers collapse into one range',
        (tester) async {
      // `splitMapJoin` inserts an `onNonMatch('')` between two
      // zero-gap matches. `<note:注一><note:注二>` (no separating text)
      // is exactly that shape — the previous test above covers markers
      // separated by text, which never hits the empty-part case at all.
      final noteSink = <String>[];
      final out = await renderPlainText(
        tester,
        '看哪<note:注一><note:注二>，日子將到，',
        noteSink: noteSink,
      );
      expect(noteSink, ['注一', '注二'],
          reason: 'both notes must still reach the sink, in order, even '
              'though their markers merge on screen');
      expect(out, '看哪①⁠⁻⁠②，日子將到，',
          reason: 'documented behaviour is a collapsed range (①⁻②), not '
              'two separate markers (①②) — the bug this guards against '
              'printed the latter');
    });

    testWidgets('three in a row collapse to a single range, not a chain',
        (tester) async {
      final noteSink = <String>[];
      final out = await renderPlainText(
        tester,
        '看哪<note:一><note:二><note:三>，',
        noteSink: noteSink,
      );
      expect(noteSink, ['一', '二', '三']);
      expect(out, '看哪①⁠⁻⁠③，',
          reason: '_markerStart always reads the FIRST number of an '
              'existing marker, so a third adjacent note extends the '
              'range (①⁻③) instead of chaining another (①⁻②⁻③)');
    });
  });

  group('collapseAnnotationSpacing (documented pre-processing)', () {
    testWidgets('a space between a bracket close and CJK collapses',
        (tester) async {
      final out = await renderPlainText(
        tester,
        '主[雅伟] 的道',
        versionCode: 'cuvs-yhwh',
      );
      expect(out, '主[雅伟]的道',
          reason: 'collapseAnnotationSpacing treats this as stray '
              'English-style spacing around a CJK-adjacent bracket, not '
              'content — the space is the one documented exception to '
              '"every character survives"');
    });
  });

  group('showVerseNumber', () {
    testWidgets('false omits the verse-number widget entirely',
        (tester) async {
      const text = '大衛遭遇兒子押沙龍追逼的時候，作這詩。';
      await renderPlainText(tester, text, showVerseNumber: false);
      expect(find.text('20'), findsNothing,
          reason: 'a psalm superscription has no verse number to show');
    });

    testWidgets('true (the default) renders the label as its own widget',
        (tester) async {
      const text = '大衛遭遇兒子押沙龍追逼的時候，作這詩。';
      await renderPlainText(tester, text);
      expect(find.text('20'), findsOneWidget);
    });
  });

  group('other flags leave the text itself untouched', () {
    testWidgets('superscriptVerseNum:true', (tester) async {
      const text = '起初，神創造天地。';
      expect(
        await renderPlainText(tester, text, superscriptVerseNum: true),
        text,
      );
    });

    testWidgets('isSelected:true', (tester) async {
      const text = '起初，神創造天地。';
      expect(await renderPlainText(tester, text, isSelected: true), text);
    });

    testWidgets("paragraphType:'reference'", (tester) async {
      const text = '因為將有小孩子為我們而生。';
      expect(
        await renderPlainText(tester, text, paragraphType: 'reference'),
        text,
      );
    });
  });
}
