import 'package:shared_preferences/shared_preferences.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahwehs_words/services/car_audio_catalogue.dart';

/// Car, watch and Android Auto pages are named by the songs on them
/// ("Ask – Sail"), not by counting numbers ("1–60"), and every song source
/// carries its own logo.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('four root tabs retain queue and playlists beneath Library', () async {
    SharedPreferences.setMockInitialValues({'locale': 'zh-Hans'});
    final root = await CarAudioCatalogue.children(CarAudioCatalogue.root);
    expect(root.map((item) => item.id),
        ['car:songs', 'car:instrumental', 'car:sermons', 'car:library']);
    expect(root.every((item) => item.playable == false), true);
    final library = await CarAudioCatalogue.children('car:library');
    expect(library.map((item) => item.id), ['car:queue', 'car:playlists']);
    expect(root.last.title, '我的');
  });

  test('Android Auto requests entry grids and readable child lists', () {
    expect(
        CarAudioCatalogue.androidRootExtras[AndroidContentStyle.supportedKey],
        true);
    expect(
        CarAudioCatalogue
            .androidRootExtras[AndroidContentStyle.browsableHintKey],
        AndroidContentStyle.gridItemHintValue);
    expect(
        CarAudioCatalogue
            .androidRootExtras[AndroidContentStyle.playableHintKey],
        AndroidContentStyle.listItemHintValue);
    final folder = CarAudioCatalogue.folder('car:songs', 'Hymns');
    expect(folder.playable, false);
    expect(folder.extras?[AndroidContentStyle.browsableHintKey],
        AndroidContentStyle.listItemHintValue);
    expect(folder.extras?[AndroidContentStyle.playableHintKey],
        AndroidContentStyle.listItemHintValue);
  });

  test(
      'shortTitle: the leading word, or the first characters of a Chinese title',
      () {
    expect(CarAudioCatalogue.shortTitle('Ask 祈求'), 'Ask');
    expect(CarAudioCatalogue.shortTitle('  Amazing Grace 奇异恩典 '), 'Amazing');
    expect(CarAudioCatalogue.shortTitle('同得基業之歌曲名稱很長很長'), '同得基業之歌曲名');
    expect(CarAudioCatalogue.shortTitle(''), '');
  });

  test('pageLabel: start – end, collapsing when both are the same word', () {
    expect(CarAudioCatalogue.pageLabel(['Ask 祈求', 'Learn', 'Sail 乘风破浪']),
        'Ask – Sail');
    expect(CarAudioCatalogue.pageLabel(['Yahweh A', 'Yahweh B']), 'Yahweh');
    expect(CarAudioCatalogue.pageLabel(['Only']), 'Only');
    expect(CarAudioCatalogue.pageLabel(const []), '');
  });

  test('no page label is a bare number range', () {
    final label = CarAudioCatalogue.pageLabel(['A', 'Z']);
    expect(RegExp(r'^\d+\s*[–-]\s*\d+$').hasMatch(label), isFalse);
  });

  test('every song source with a bundled icon has a website logo URL', () {
    for (final s in ['fydt', 'cahaya', 'cdc', 'cgdc', 'setapak', 'ydh']) {
      final u = CarAudioCatalogue.sourceLogo(s);
      expect(u, isNotNull, reason: s);
      expect(u!.toString(),
          startsWith('https://yahwehword.com/assets/assets/song_sources/'));
    }
    expect(CarAudioCatalogue.sourceLogo('no-such-source'), isNull);
  });

  test('folders can carry a subtitle and their own artwork', () {
    final f = CarAudioCatalogue.folder('car:songs/cdc', 'CDC',
        subtitle: '298 首', art: CarAudioCatalogue.sourceLogo('cdc'));
    expect(f.artist, '298 首');
    expect(f.artUri.toString(), contains('cdc.png'));
    expect(
        CarAudioCatalogue.folder('x', 'X').artUri, CarAudioCatalogue.artwork);
  });
}
