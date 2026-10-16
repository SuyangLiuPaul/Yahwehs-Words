// The normaliser is the importer's security boundary and its fidelity
// contract: whatever a module's markup says, the reader gets plain text,
// `[added words]`, `<note: …>` and `\n` — nothing else, nothing leaked.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:yahwehs_words/utils/addons/addon_types.dart';
import 'package:yahwehs_words/utils/addons/markup_normaliser.dart';

NormalisedVerse _n(String raw, MarkupDialect d, [ImportReport? r]) =>
    normaliseVerse(raw, d, r ?? ImportReport());

String _my(String raw) => _n(raw, MarkupDialect.myBible).text;
String _gbf(String raw) => _n(raw, MarkupDialect.gbf).text;
String _zef(String raw) => _n(raw, MarkupDialect.zefania).text;

void main() {
  group('MyBible.zone markup', () {
    test('added words become [brackets]', () {
      expect(_my('the earth was <i>without form</i>, and void'),
          'the earth was [without form], and void');
    });
    test('Strong\'s numbers and morphology are dropped, and counted', () {
      final r = ImportReport();
      final v = _n('In<S>7225</S> the beginning<S>7225</S><m>N-FSA</m>', MarkupDialect.myBible, r);
      expect(v.text, 'In the beginning');
      expect(v.hadStrongs, isTrue);
      expect(r.strongsTagsDropped, 2);
    });
    test('words of Jesus / emphasis: tags stripped, text kept', () {
      expect(_my('He said, <J>Follow me</J>, and <e>they did</e>.'),
          'He said, Follow me, and they did.');
    });
    test('<n> becomes a note; <f> markers and <h> headings are dropped', () {
      final r = ImportReport();
      final v = _n('For God<n>a note here</n> so loved<f>1</f> the world.<h>A heading</h>',
          MarkupDialect.myBible, r);
      expect(v.text, 'For God<note: a note here> so loved the world.');
      expect(r.notesKept, 1);
      expect(r.footnoteMarkersDropped, 1);
      expect(r.headingsDropped, 1);
    });
    test('<br/> is a newline, <pb/> is a paragraph marker', () {
      expect(_my('one<br/>two'), 'one\ntwo');
      final lead = _n('<pb/>Thus the heavens', MarkupDialect.myBible);
      expect(lead.startsParagraph, isTrue);
      expect(lead.endsParagraph, isFalse);
      final trail = _n('and all the host of them.<pb/>', MarkupDialect.myBible);
      expect(trail.endsParagraph, isTrue);
      expect(trail.startsParagraph, isFalse);
      expect(trail.text, 'and all the host of them.');
    });
    test('<t> starts a new line', () {
      expect(_my('As it is written:<t>the just shall live</t>'),
          'As it is written:\nthe just shall live');
    });
    test('an unknown tag is stripped and its text kept', () {
      final r = ImportReport();
      expect(_n('a <blink>b</blink> c', MarkupDialect.myBible, r).text, 'a b c');
      expect(r.unknownTagsDropped, greaterThan(0));
    });
  });

  group('GBF (MySword / theWord) markup', () {
    test('<FI>..<Fi> are added words', () {
      expect(_gbf('the earth was <FI>without form<Fi>, and void'),
          'the earth was [without form], and void');
    });
    test('Strong\'s numbers after the word are dropped', () {
      expect(_gbf('God<WH430> created<WH1254> the heaven<WH8064>'),
          'God created the heaven');
    });
    test('words of Jesus, OT quotes and underline are stripped', () {
      expect(_gbf('<FR>I am the way<Fr>, <FO>it is written<Fo>, <FU>so<Fu>.'),
          'I am the way, it is written, so.');
    });
    test('<RF> is a note; <RX> cross-references are dropped', () {
      final r = ImportReport();
      final v = _n('loved<RF>some witnesses omit this<Rf> the world<RX43.3.17>.',
          MarkupDialect.gbf, r);
      expect(v.text, 'loved<note: some witnesses omit this> the world.');
      expect(r.crossRefsDropped, 1);
    });
    test('headings <TS>..<Ts> are dropped with their text', () {
      expect(_gbf('<TS>The First Day<Ts>And God said'), 'And God said');
      expect(_gbf('<TS2>Sub<Ts>Text'), 'Text');
    });
    test('<CM> at the end opens the next paragraph; mid-verse it is nothing', () {
      expect(_n('Amen.<CM>', MarkupDialect.gbf).endsParagraph, isTrue);
      expect(_n('<CM>In the beginning', MarkupDialect.gbf).startsParagraph, isTrue);
    });
    test('<CL> is a newline', () {
      expect(_gbf('line one<CL>line two'), 'line one\nline two');
    });
    test('interlinear <Q> blocks are dropped whole', () {
      final r = ImportReport();
      expect(_n('word<Q><E>english<e><X>translit<x><q>more', MarkupDialect.gbf, r).text,
          'wordmore');
      expect(r.interlinearDropped, 1);
    });
    test('simple HTML is stripped', () {
      expect(_gbf('a <b>bold</b> <i>word</i> and <font color="red">red</font>'),
          'a bold word and red');
    });

    // Every defect tools/import_yahweh_ont.py catalogues in a real export.
    group('real-world damage', () {
      test('text swallowed into a tag:  <牲畜WH2874>', () {
        expect(_gbf('各样<牲畜WH2874>的'), '各样牲畜的');
      });
      test('a missing > nesting two tags:  <WH5921<WH3802>', () {
        expect(_gbf('渊面<WH5921<WH3802>黑暗'), '渊面黑暗');
      });
      test('a doubled <:  <<WG5624>', () {
        expect(_gbf('ab<<WG5624>cd'), 'abcd');
      });
      test('suffix noise:  <WH3190s>', () {
        expect(_gbf('good<WH3190s> day'), 'good day');
      });
      test('a dropped W:  <H4480x>', () {
        expect(_gbf('from<H4480x> there'), 'from there');
      });
      test('a dropped letter:  <3588>', () {
        expect(_gbf('for<3588> God'), 'for God');
      });
      test('none of them leaks a number into the reading text', () {
        final t = _gbf('<牲畜WH2874> a<WH5921<WH3802> b<<WG5624> c<WH3190s> d<H4480x> e<3588> f');
        expect(RegExp(r'\d').hasMatch(t), isFalse, reason: t);
      });
    });
  });

  group('Zefania markup', () {
    test('<NOTE> is a note, <BR/> a newline', () {
      expect(_zef('Let there be light<NOTE type="x">a note</NOTE>.<BR/>Next'),
          'Let there be light<note: a note>.\nNext');
    });
    test('<STYLE> is stripped, <CAPTION> and <XREF> dropped', () {
      expect(_zef('a <STYLE css="font-style:italic">b</STYLE> c<XREF fscope="Rom 5:8"/>'),
          'a b c');
    });
    test('entities are decoded', () {
      expect(_zef('God &amp; man &#8212; &lt;&gt; &quot;x&quot;'),
          'God & man — "x"');
    });
  });

  group('the guarantees', () {
    test('nothing angle-bracketed or braced survives except our own tokens', () {
      final t = _my('a <a href="http://evil.example">link</a> <img src=x onerror=alert(1)> '
          '<script>alert(1)</script> b {c} [d] <e e> f > g < h');
      expect(t.contains('<'), isFalse, reason: t);
      expect(t.contains('>'), isFalse, reason: t);
      expect(t.contains('{'), isFalse);
      expect(t.contains('}'), isFalse);
      expect(t.contains('['), isFalse);
      expect(t.contains(']'), isFalse);
      expect(t.contains('evil.example'), isFalse,
          reason: 'a link target lives inside the tag and is dropped with it');
      expect(t.contains('link'), isTrue, reason: 'the link TEXT is kept as text');
    });

    test('a module cannot smuggle in our private markers', () {
      final t = _my('a b c');
      expect(t, 'a b c');
    });

    test('unbalanced and unclosed tags never swallow the rest of the verse', () {
      expect(_my('start <i>never closed then more text'), 'start [never closed then more text]');
      expect(_gbf('start <FI>never closed then more text'), 'start [never closed then more text]');
      expect(_my('stray </i> close and </n> more'), 'stray close and more');
    });

    test('empty insertions and notes vanish', () {
      expect(_my('a <i></i>b<n> </n>c'), 'a bc');
    });

    test('whitespace is tidied', () {
      expect(_my('  a   b \t c\r\n d  '), 'a b c d');
    });

    test('10,000 random tag soups: no raw bracket, balanced tokens only', () {
      final rng = Random(20261017);
      const bits = [
        '<i>', '</i>', '<S>', '</S>', '<n>', '</n>', '<f>', '<h>', '</h>', '<J>',
        '<br/>', '<pb/>', '<FI>', '<Fi>', '<RF>', '<Rf>', '<TS>', '<Ts>', '<Q>',
        '<q>', '<WH123>', '<WG5>', '<<', '>', '<', '{', '}', '[', ']', '&amp;',
        '&#x3C;', 'word', ' ', 'God', '神', '<note:', '<NOTE>', '</NOTE>', '\n',
        '<RX1.2.3>', '<CM>', '<牲畜WH1>', '<3588>',
      ];
      for (var i = 0; i < 10000; i++) {
        final raw = List.generate(rng.nextInt(20), (_) => bits[rng.nextInt(bits.length)]).join();
        for (final d in MarkupDialect.values) {
          final t = _n(raw, d).text;
          // Strip our two legitimate constructs; nothing bracketed may remain.
          final rest = t
              .replaceAll(RegExp(r'<note: [^<>\[\]{}]+>'), '')
              .replaceAll(RegExp(r'\[[^<>\[\]{}]+\]'), '');
          expect(rest.contains(RegExp(r'[<>\[\]{}]')), isFalse,
              reason: '$d: "$raw" -> "$t"');
        }
      }
    });
  });
}
