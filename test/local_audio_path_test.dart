import 'package:flutter_test/flutter_test.dart';
import 'package:yahwehs_words/utils/local_audio_path.dart';

void main() {
  test('local files across iOS Android macOS Windows are not treated as URLs',
      () {
    for (final path in [
      '/var/mobile/audio.mp3',
      '/data/user/0/audio.mp3',
      r'C:\Users\Paul\audio.mp3',
      'D:/Music/audio.m4a',
      r'\\server\share\audio.mp3'
    ]) {
      expect(isLocalAudioPath(path), true, reason: path);
    }
    for (final url in [
      'https://example.test/audio.mp3',
      'blob:https://example.test/abc'
    ]) {
      expect(isLocalAudioPath(url), false);
    }
  });
}
