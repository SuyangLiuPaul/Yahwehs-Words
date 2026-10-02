/// The watch and the car follow the phone's theme: the colour and the logo
/// variant ride along in the snapshot, and a cover-less song or sermon gets the
/// themed logo rather than a fixed blue one.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahwehs_words/services/car_audio_catalogue.dart';
import 'package:yahwehs_words/services/companion_theme.dart';
import 'package:yahwehs_words/services/media_companion_service.dart';
import 'package:yahwehs_words/services/song_audio_handler.dart';

import 'support/fake_song_playback_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CompanionTheme.reset();
  });

  test('the default theme is the blue mark and its own colour', () {
    expect(CompanionTheme.logo, 'Default');
    expect(CompanionTheme.accent, Colors.lightBlue.toARGB32());
    expect(CompanionTheme.artwork.toString(),
        'https://yahwehword.com/icons/Icon-512.png');
  });

  test('each theme colour names the logo the home-screen icon uses', () {
    final expected = {
      Colors.red: 'Red',
      Colors.orange: 'Orange',
      Colors.green: 'Green',
      Colors.purple: 'Purple',
      Colors.pink: 'Pink',
    };
    for (final entry in expected.entries) {
      CompanionTheme.reset();
      expect(CompanionTheme.update(entry.key), isTrue);
      expect(CompanionTheme.logo, entry.value, reason: '${entry.key}');
      expect(CompanionTheme.accent, entry.key.toARGB32());
      expect(CompanionTheme.artwork.toString(),
          'https://yahwehword.com/icons/Icon-${entry.value}-512.png');
    }
  });

  test('setting the colour it already has reports no change', () {
    expect(CompanionTheme.update(Colors.lightBlue), isFalse);
    expect(CompanionTheme.update(Colors.red), isTrue);
    expect(CompanionTheme.update(Colors.red), isFalse);
  });

  test('a saved colour is picked up before any screen has loaded settings',
      () async {
    SharedPreferences.setMockInitialValues(
        {'primaryColor': Colors.green.toARGB32()});
    expect(await CompanionTheme.loadSaved(), isTrue);
    expect(CompanionTheme.logo, 'Green');
  });

  test('the snapshot carries the theme, and the car artwork follows it',
      () async {
    final h = SongAudioHandler(engine: FakeSongPlaybackEngine());
    CompanionTheme.update(Colors.red);
    final snapshot = MediaCompanionService.snapshotFor(h);
    expect(snapshot['accent'], Colors.red.toARGB32());
    expect(snapshot['logo'], 'Red');
    expect(CarAudioCatalogue.artwork.toString(),
        'https://yahwehword.com/icons/Icon-Red-512.png');
    await h.dispose();
  });
}
