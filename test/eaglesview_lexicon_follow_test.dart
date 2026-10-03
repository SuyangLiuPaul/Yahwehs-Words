// 2026-10-03: Sword's lexicon follows Eagle's View where EV edited it
// (tools/follow_eaglesview_lexicon.py). EV's author removed the Trinity /
// "second person" / "God incarnate" wording from G2316, G3056 and G2424
// (and, in English, G4151). The entry reads as EV's; a footnote labelled
// "EagleView 版本" / "[Eagle's View version]" quotes what was left out.

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

String _body(String s) => s.split('※ EagleView 版本').first;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('greek.json Chinese outlines carry EV wording and an EV footnote', () async {
    final g = jsonDecode(await rootBundle.loadString('assets/strongs/greek.json')) as Map;
    for (final f in ['defZh', 'defZhTw']) {
      for (final id in ['G2316', 'G3056', 'G2424']) {
        expect(g[id][f], contains('※ EagleView 版本'), reason: '$id.$f');
      }
      expect(_body(g['G2316'][f]), contains('2) 神性'));
      expect(_body(g['G2316'][f]), isNot(contains('三位一')));
      expect(_body(g['G3056'][f]), isNot(contains('第二位格')));
      expect(_body(g['G2424'][f]), isNot(contains('道成肉身')));
    }
    expect(g['G2424']['glossZh'], '耶稣, 上帝的儿子, 人类的救主');
  });

  test('thayer_zh.json outlines carry EV wording and an EV footnote', () async {
    final z = jsonDecode(await rootBundle.loadString('assets/strongs/thayer_zh.json')) as Map;
    String body(String k) => (z[k]['s'] as List).where((x) => !(x as String).startsWith('※')).join('\n');
    for (final id in ['G2316', 'G3056', 'G2424']) {
      expect((z[id]['s'] as List).last, startsWith('※ EagleView 版本'), reason: id);
    }
    expect(body('G2316'), isNot(contains('三位一体')));
    expect(body('G3056'), isNot(contains('第二位格')));
    expect(body('G3056'), contains('3) 在约翰福音中, 是指神的话'));
    expect(body('G2424'), isNot(contains('道成肉身')));
  });

  test('English Thayer entries carry an EV footnote', () async {
    final t = (jsonDecode(await rootBundle.loadString('assets/thayer.json')) as Map)['entries'] as Map;
    for (final id in ['G2316', 'G3056', 'G4151', 'G2424']) {
      expect(t[id], contains("[Eagle's View version]"), reason: id);
    }
    // The outline itself is EV's: no Trinity line above the footnote.
    expect((t['G2316'] as String).split("[Eagle's View version]").first,
        isNot(contains('trinity')));
    expect((t['G3056'] as String).split("[Eagle's View version]").first,
        isNot(contains('second person')));
  });
}
