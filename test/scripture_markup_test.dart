import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yahwehs_words/utils/scripture_markup.dart';

/// Coverage for `bracketSpanKind`/`isReferentGloss` themselves, past the
/// 5-of-16 tokens incidentally pinned by
/// `test/cuv_three_referent_markers_test.dart` (耶稣/耶穌/Jesus/雅偉/基督).
void main() {
  const divineNameTokens = {
    '雅伟', '雅偉', '雅威', 'Yahweh', 'YHWH', 'YHVH', '耶和华', '耶和華',
  };
  const referentTokens = {
    '基督', 'Christ', 'Messiah', '弥赛亚', '彌賽亞', '耶稣', '耶穌', 'Jesus',
  };

  group('bracketSpanKind — the two closed sets', () {
    for (final token in divineNameTokens) {
      test('$token → divineName', () {
        expect(bracketSpanKind(token), ScriptureSpanKind.divineName);
        expect(isReferentGloss(token), isTrue);
      });
    }
    for (final token in referentTokens) {
      test('$token → gloss', () {
        expect(bracketSpanKind(token), ScriptureSpanKind.gloss);
        expect(isReferentGloss(token), isTrue);
      });
    }
  });

  group('supplied is the default outside both sets', () {
    test('empty string', () {
      expect(bracketSpanKind(''), ScriptureSpanKind.supplied);
      expect(isReferentGloss(''), isFalse);
    });
    test('an ordinary supplied word', () {
      expect(bracketSpanKind('is'), ScriptureSpanKind.supplied);
      expect(isReferentGloss('is'), isFalse);
    });
  });

  group('whitespace is trimmed before matching', () {
    test('ASCII space', () {
      expect(bracketSpanKind(' 雅偉 '), ScriptureSpanKind.divineName);
    });
    test('newline', () {
      expect(bracketSpanKind('\n耶穌\n'), ScriptureSpanKind.gloss);
    });
    test('U+3000 ideographic space', () {
      // Checked empirically rather than assumed: Dart's String.trim()
      // treats U+3000 as whitespace the same as an ASCII space (both
      // fold), so a bracket body an importer padded with a full-width
      // space still matches its token.
      expect(bracketSpanKind('　基督　'), ScriptureSpanKind.gloss);
    });
  });

  group('case sensitivity — characterization, not a fix', () {
    // Both sets are exact-match today, so a differently-cased token that
    // is not itself in the set falls through to supplied. Whether a
    // reading asset could ever ship a lower/upper-cased token is an open
    // question for the user; changing this here would reclassify spans
    // and move Strong's numbers, which is out of scope for this file.
    test('lowercase "yahweh" is supplied, not divineName', () {
      expect(bracketSpanKind('yahweh'), ScriptureSpanKind.supplied);
    });
    test('uppercase "JESUS" is supplied, not gloss', () {
      expect(bracketSpanKind('JESUS'), ScriptureSpanKind.supplied);
    });
  });

  group('dataset-coverage guard — frozen reading assets', () {
    // assets/cuvs-yhwh.json and -tr.json are FROZEN (read-only,
    // hash-pinned by test/cuvs_yhwh_frozen_test.dart). This test only
    // reads them, and only to sweep every distinct `[...]` body that
    // actually ships, asserting the classifier never falls through to
    // `supplied` for one of them — the failure mode the doc comment in
    // scripture_markup.dart warns moves a Strong's number onto the
    // wrong word.
    //
    // The distinct-body count is deliberately not asserted here — it is
    // a fact about the asset, not about the classifier, and pinning it
    // in a second file would be exactly the kind of figure the tree can
    // silently drift under that this queue avoids. The sweep instead
    // asserts non-emptiness (so a broken regex cannot pass by finding
    // nothing) and then checks every body it actually finds.
    //
    // The tagged corpus (assets/tagged/cuvs-yhwh/*.json, 264 files) is
    // deliberately NOT swept here. Its raw TaggedRun structure splits
    // exactly these brackets across two runs — e.g.
    // assets/tagged/cuvs-yhwh/luke.json verse 1:6 has one run whose `w`
    // ends "主 [" and the next run's `w` opens "雅伟] 的一切" — so a
    // sweep over each run's own text independently would silently miss
    // the tokens this file exists to cover, undercounting rather than
    // erroring. TaggedTextService.reuniteGlossRuns joins the halves back
    // together before bracketSpanKind ever sees them; a sweep faithful
    // to that would have to reimplement the join, which is a fragile
    // enough sweep to be worse than no sweep. Restricting to the two
    // reading assets, where a bracket is never split across rows,
    // avoids that trap.
    final bracket = RegExp(r'\[([^\[\]]*)\]');
    for (final path in [
      'assets/cuvs-yhwh.json',
      'assets/cuvs-yhwh-tr.json',
    ]) {
      test(path, () {
        final rows = json.decode(File(path).readAsStringSync()) as List;
        final bodies = <String>{};
        for (final r in rows) {
          final text = (r as Map)['text'] as String? ?? '';
          for (final m in bracket.allMatches(text)) {
            bodies.add(m.group(1) ?? '');
          }
        }
        expect(bodies, isNotEmpty,
            reason: 'the sweep found no bracketed spans at all — '
                'the regex or the asset shape probably changed');
        for (final body in bodies) {
          expect(isReferentGloss(body), isTrue,
              reason: '"$body" in $path classifies as supplied — either '
                  'a genuine supplied word appeared in a frozen reading '
                  'asset (should not happen) or a referent token is '
                  'missing from scripture_markup.dart');
        }
      });
    }
  });
}
