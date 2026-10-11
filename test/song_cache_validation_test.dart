import 'package:flutter_test/flutter_test.dart';
import 'package:yahwehs_words/services/song_cache_validation.dart';

void main() {
  test('distinguishes empty, size mismatch and rejected prefix', () {
    expect(classifySongCacheBody(10, 0, []), 'empty_body');
    expect(classifySongCacheBody(10, 9, [73, 68, 51]), 'size_mismatch');
    expect(classifySongCacheBody(3, 3, [60, 104, 116]), 'invalid_prefix');
    expect(classifySongCacheBody(3, 3, [73, 68, 51]), 'valid');
    expect(classifySongCacheBody(0, 3, [73, 68, 51]), 'valid');
  });
  test('report URLs exclude credentials, query tokens and fragments', () {
    final base = Uri.parse('https://example.test/');
    expect(
        diagnosticCacheUrl(
            'https://user:secret@a.test/audio?q=key#secret', base),
        'https://a.test/audio');
    expect(diagnosticCacheUrl('/song-media/track?token=secret', base),
        'https://example.test/song-media/track');
  });
}
