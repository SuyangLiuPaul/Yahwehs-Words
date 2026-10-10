import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahwehs_words/widgets/global_mini_player.dart';

void main() {
  test('loading is explicit in all supported locales', () {
    for (final entry
        in {'en': 'Loading…', 'zh-Hans': '加载中…', 'zh-Hant': '載入中…'}.entries) {
      expect(
          songPlaybackTimeLabel(
              position: Duration.zero,
              duration: Duration.zero,
              loading: true,
              locale: entry.key),
          entry.value);
    }
  });
  test('unknown duration is not displayed as a zero-length song', () {
    expect(
        songPlaybackTimeLabel(
            position: const Duration(seconds: 7),
            duration: Duration.zero,
            loading: false,
            locale: 'en'),
        '0:07 / —');
    expect(
        songPlaybackTimeLabel(
            position: const Duration(seconds: 7),
            duration: const Duration(seconds: 200),
            loading: false,
            locale: 'en'),
        '0:07 / 3:20');
  });
  testWidgets('missing CDC artwork uses the catalogue source asset offline',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: SizedBox(
            width: 34, height: 34, child: SongArtworkFallback(source: 'cdc'))));
    expect(
        tester.widget<Image>(find.byType(Image)).image,
        isA<AssetImage>().having((image) => image.assetName, 'source',
            'assets/song_sources/cdc.png'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('unknown source retains a safe placeholder', (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: SongArtworkFallback(source: 'new-source')));
    expect(find.byIcon(Icons.music_note_rounded), findsOneWidget);
  });
}
