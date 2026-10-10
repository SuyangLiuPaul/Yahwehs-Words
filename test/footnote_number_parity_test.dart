import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahwehs_words/models/app_settings.dart';
import 'package:yahwehs_words/models/verse.dart';
import 'package:yahwehs_words/utils/build_verse_content_spans.dart';
import 'package:yahwehs_words/widgets/verse_notes_block.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final locale in ['zh-Hans', 'en']) {
    for (final size in [18.0, 28.0]) {
      testWidgets('same footnote number size and weight $locale $size',
          (tester) async {
        final settings = AppSettings();
        addTearDown(settings.dispose);
        await settings.setFontSize(size);
        final note =
            locale == 'en' ? 'Some manuscripts: firstborn son' : '有古卷：头胎的儿子';
        final v =
            Verse(book: '马太福音', chapter: 1, verse: 25, text: '儿子<note:$note>。');
        late List<InlineSpan> spans;
        await tester.pumpWidget(
            MaterialApp(home: Scaffold(body: Builder(builder: (context) {
          final sink = <String>[];
          spans = buildVerseContentSpans(
              verse: v,
              context: context,
              settings: settings,
              locale: locale,
              isSelected: false,
              superscriptVerseNum: true,
              noteSink: sink);
          return SingleChildScrollView(
              child: Column(children: [
            Text.rich(TextSpan(children: spans)),
            VerseNotesBlock(notes: sink, settings: settings, locale: locale),
          ]));
        }))));
        await tester.pump(const Duration(seconds: 1));
        final inline = spans.whereType<NoteMarkerSpan>().single;
        final card = tester.widget<Text>(find.descendant(
            of: find.byType(VerseNotesBlock), matching: find.text('①')));
        final inlineText = (inline.child as Transform).child! as DecoratedBox;
        final number = ((inlineText.child! as Padding).child! as Text);
        expect(number.style!.fontSize, size * 0.55);
        expect(card.style!.fontSize, number.style!.fontSize);
        expect(card.style!.fontWeight, FontWeight.w600);
        expect(number.style!.fontWeight, card.style!.fontWeight);
        final prose = tester.widget<Text>(find.text(note));
        expect(prose.style!.fontSize, size * 0.85);
        expect(inline.marker, '①');
        expect(inline.alignment, PlaceholderAlignment.middle);
        // Verse numbers are a different numbering system; their old rule survives.
        expect(tester.widget<Text>(find.text('25')).style!.fontSize, size * 0.65);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
