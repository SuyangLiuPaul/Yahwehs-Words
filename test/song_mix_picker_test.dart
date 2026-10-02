import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahwehs_words/constants/ui_strings.dart';
import 'package:yahwehs_words/models/song.dart';
import 'package:yahwehs_words/models/song_queue.dart';
import 'package:yahwehs_words/widgets/song_mix_picker.dart';

void main() {
  Song song(String id, {String? accompaniment}) => Song(
      id: id,
      title: id,
      language: 'en',
      source: 'cgdc',
      sourceLabel: 'CGDC',
      url: 'https://example.test/$id',
      audioUrl: 'https://example.test/$id.mp3',
      accompanimentUrl: accompaniment,
      themes: const []);
  for (final locale in ['en', 'zh-Hans', 'zh-Hant']) {
    testWidgets('Ask has no mix even when Free Man does — $locale',
        (tester) async {
      final queue = SongQueue.fromSongs([
        song('ask'),
        song('free', accompaniment: 'https://example.test/free-acc.mp3')
      ]);
      var taps = 0;
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: SongMixPicker(
                  queue: queue, locale: locale, onSelected: (_) => taps++))));
      final chip = find.widgetWithText(
          ChoiceChip, uiStrings['songsTrackAccompaniment']![locale]!);
      expect(tester.widget<ChoiceChip>(chip).onSelected, isNull);
      await tester.tap(chip);
      expect(taps, 0);
      expect(queue.current!.song.id, 'ask');
    });
  }
  testWidgets(
      'an available mix is selectable and loading blocks duplicate taps',
      (tester) async {
    final queue = SongQueue.fromSongs(
        [song('free', accompaniment: 'https://example.test/free-acc.mp3')]);
    TrackPreference? picked;
    Future<void> render(bool busy) => tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SongMixPicker(
                queue: queue,
                locale: 'en',
                loading: busy,
                onSelected: (value) => picked = value))));
    final chip = find.widgetWithText(
        ChoiceChip, uiStrings['songsTrackAccompaniment']!['en']!);
    await render(false);
    await tester.tap(chip);
    expect(picked, TrackPreference.accompaniment);
    await render(true);
    expect(tester.widget<ChoiceChip>(chip).onSelected, isNull);
  });
}
