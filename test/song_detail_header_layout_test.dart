import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahwehs_words/models/app_settings.dart';
import 'package:yahwehs_words/models/song.dart';
import 'package:yahwehs_words/pages/songs_page.dart';

/// The song detail sheet's header put the title in an Expanded next to
/// six action buttons plus a close X. At phone widths the buttons took
/// ~290 px and the title kept ~20 px, so a CJK title wrapped one
/// character per line (owner's iPhone 14 / 16 Pro / P20 photos). The
/// title must own the full row width; the actions go on their own row.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const song = Song(
    id: 'fydt-s01-006',
    title: '与主合一',
    language: 'zh',
    source: 'fydt',
    sourceLabel: 'FYDT Gospel Radio',
    code: 'S01_006',
    url: 'https://example.com/song',
    artist: '林德茵',
    durationSec: 226,
    audioUrl: 'https://example.com/a.mp3',
    themes: [],
  );

  for (final size in const [Size(360, 800), Size(390, 844), Size(800, 900)]) {
    testWidgets('title is not squeezed at ${size.width.toInt()}x'
        '${size.height.toInt()}', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);

      late BuildContext ctx;
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (c) {
          ctx = c;
          return const SizedBox();
        }),
      ));
      final settings = AppSettings();
      showSongDetailSheet(ctx, song, settings, settings.locale);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final titleBox = tester.renderObject<RenderBox>(find.text(song.title));
      // One 18 px line; a one-char-per-line wrap is ~4x this.
      expect(titleBox.size.height, lessThan(30),
          reason: 'title wrapped: ${titleBox.size}');
      // Four 18 px glyphs side by side, not a 22 px sliver.
      expect(titleBox.size.width, greaterThan(60));

      // Header (top of sheet to the Audio label) stays short.
      final audio = find.text('Audio');
      if (audio.evaluate().isNotEmpty) {
        final top = tester.getTopLeft(find.text(song.title)).dy;
        final audioTop = tester.getTopLeft(audio).dy;
        expect(audioTop - top, lessThan(140));
      }
    });
  }
}
