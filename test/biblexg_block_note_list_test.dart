import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Regression test for the 2026-08-31 defect: `tools/import_ljk2.py`
/// `build_book_verses()` handled exactly three upstream node types
/// (`chapter`, `verse`, `comment`) and silently dropped two more —
/// `comment-list` and `ul-comment-list` — the publisher's numbered and
/// bulleted footnote lists. A note would announce "...包括：" (or any
/// other trailing colon) and the list it introduced would simply not
/// exist in `assets/biblexg-v2*.json`. 帖撒罗尼迦后书 2:4 is the case the
/// user reported with a photo of the print edition; 22 verses per
/// edition were affected (`tools/backfill_ljk2_comment_lists.py`
/// recovered them additively, without touching the ten commits of
/// hand-repairs already sitting in these assets).
///
/// 2026-09-14 (16633cad) reverted the importer fix when it was replaced
/// wholesale, and the September re-fetch (`assets/biblexg-v3*.json`,
/// the edition readers actually reach) shipped the same defect again —
/// 24 verses this time (2 more than the May-derived v2 count: the
/// publisher had added list nodes at 罗8:30 and 多2:15 between the two
/// fetches, so a v2-vs-v3 diff alone could not have found them — only
/// re-parsing the publisher's current source could). Restored
/// 2026-09-24, again by `tools/backfill_ljk2_comment_lists.py`, this
/// time with `--code biblexg-v3 --src-dir /tmp/ljk-source` against a
/// freshly fetched snapshot rather than the vendored April one.
///
/// This does not re-derive that count — it watches for the SHAPE of
/// the defect: a `blockNotes` entry that ends in a colon (`：` / `:`)
/// with nothing list-shaped after it in the same verse. That shape is
/// exactly what a future `import_ljk2.py` re-run, or a future upstream
/// node type this importer still doesn't handle, would reproduce.
void main() {
  final colonEnd = RegExp(r'[：:]$');
  final listStart = RegExp(r'^(\d+\.|•)');

  /// Residual over-flags: real prose that happens to end in a colon
  /// and is not followed by a list, because the colon introduces
  /// something other than a `comment-list` / `ul-comment-list` node —
  /// verified against the source, not guessed. `(verse id, blockNotes
  /// index)` so the allow-list stays as narrow as the defect it covers;
  /// widening a verse-level allow would also hide a real future loss
  /// in the SAME verse's other notes.
  const allowed = <(String, int)>{
    // 可16:8 — the note explains the manuscript evidence for the
    // disputed longer ending and stops; the ending itself is the next
    // verse's text, not a list node.
    ('41016008', 0),
    // 约1:5 — "...译本（阿拉米语又称亚兰文）：" and "...理据如下：" are both
    // followed by ordinary prose paragraphs, not `<li>` lists.
    ('43001005', 8),
    ('43001005', 19),
    // 罗1:17 — three colons in one argument, each followed by prose,
    // not a `comment-list`.
    ('45001017', 4),
    ('45001017', 12),
    ('45001017', 13),
    // 罗2:16 — "...这样作者的思路更加清晰可见，如下：" introduces a
    // re-ordered restatement of verses 5-6 as plain text, not a list.
    ('45002016', 1),
    // 罗16:24 — the critical-apparatus note about NA28/UBS5 manuscript
    // evidence; nothing follows it (last blockNote of the verse).
    ('45016024', 0),
    // 加2:21 — "...释义可分以下三类：" is followed by "分类 1：...", "分类
    // 2：..." etc — the publisher's OWN prose numbering, not our
    // recovered `1. / 2. / 3.` list markers.
    ('48002021', 12),
    // 加3:14 — "...BDAG 及 THAY，πίστις 的释义有：" followed by discursive
    // prose analysing those definitions, not a list node.
    ('48003014', 6),
    // 西2:15 — "...这词组有两种可能的释义：" followed by prose weighing the
    // two readings, not a `<li>` list.
    ('51002015', 4),
    // 来10:39 — "...综合 HALOT 和 BDB，אֱמוּנָה 的释义有：" followed by prose.
    ('58010039', 6),
    // 约一2:27 — "...现译作'反基督'，原因有三：" followed by "第一，...",
    // "第二，..." as prose paragraphs, not our list markers.
    ('62002027', 1),
    // 犹1:23 — "...以下是一种更符合汉语遣词造句习惯的翻译：" followed by the
    // restated verse text itself, not a list node.
    ('65001023', 0),
  };

  List<Map<String, dynamic>> load(String path) =>
      (json.decode(File(path).readAsStringSync()) as List)
          .cast<Map<String, dynamic>>();

  for (final path in [
    'assets/biblexg-v2.json',
    'assets/biblexg-v2-tr.json',
    'assets/biblexg-v3.json',
    'assets/biblexg-v3-tr.json',
  ]) {
    test('$path: every colon-ending block note is followed by its list',
        () {
      final verses = load(path);
      final unexplained = <String>[];
      for (final v in verses) {
        final notes = (v['blockNotes'] as List?)?.cast<String>();
        if (notes == null) continue;
        for (var i = 0; i < notes.length; i++) {
          if (!colonEnd.hasMatch(notes[i].trim())) continue;
          final next = i + 1 < notes.length ? notes[i + 1].trim() : null;
          if (next != null && listStart.hasMatch(next)) continue;
          if (allowed.contains((v['id'] as String, i))) continue;
          unexplained.add('${v['book']} ${v['chapter']}:${v['verse']}'
              ' blockNotes[$i]: "${notes[i]}"');
        }
      }
      expect(unexplained, isEmpty, reason: unexplained.join('\n'));
    });
  }

  test('no verse in any edition carries an empty blockNotes array', () {
    // 2026-09-24: `tools/apply_ljk_2026_09_17.py` moved 路加福音 23:34a's
    // note onto 23:34 (the translator's own ruling — see ebea3499) but
    // left `"blockNotes":[]` on 23:38 instead of removing the key, the
    // convention every other note-less verse in these assets follows.
    // An empty array is inert in the reader (`VerseNotesBlock.build`
    // returns `SizedBox.shrink()` for `notes.isEmpty`), so this was
    // never visible — but it is downstream residue a future script
    // could reproduce the same way, so pin the convention.
    for (final path in [
      'assets/biblexg-v2.json',
      'assets/biblexg-v2-tr.json',
      'assets/biblexg-v3.json',
      'assets/biblexg-v3-tr.json',
    ]) {
      final verses = load(path);
      final empties = verses
          .where((v) => v['blockNotes'] is List && (v['blockNotes'] as List).isEmpty)
          .map((v) => v['id'] as String)
          .toList();
      expect(empties, isEmpty, reason: '$path has empty blockNotes at $empties');
    }
  });

  test('帖撒罗尼迦后书 2:4 carries the recovered three senses of θεοῦ', () {
    const wanted = {
      'assets/biblexg-v2.json': ['帖撒罗尼迦后书', '如林前8.5', '如林前8.6', '如出7.1'],
      'assets/biblexg-v2-tr.json': ['帖撒羅尼迦後書', '如林前8.5', '如林前8.6', '如出7.1'],
      // The September re-fetch (biblexg-v3*) dropped this same list —
      // see docs/autonomous-queue.md — and 2026-09-24 recovered it from
      // the publisher's own current source, additively, same as v2.
      'assets/biblexg-v3.json': ['帖撒罗尼迦后书', '如林前8.5', '如林前8.6', '如出7.1'],
      'assets/biblexg-v3-tr.json': ['帖撒羅尼迦後書', '如林前8.5', '如林前8.6', '如出7.1'],
    };
    wanted.forEach((path, want) {
      final verse = load(path).firstWhere((v) =>
          v['book'] == want[0] && v['chapter'] == '2' && v['verse'] == '4');
      final notes = (verse['blockNotes'] as List).cast<String>();
      final listNote = notes.firstWhere(
          (n) => n.startsWith('1.'),
          orElse: () => '');
      expect(listNote, isNotEmpty, reason: '$path — list note missing');
      for (final ref in want.skip(1)) {
        expect(listNote, contains(ref), reason: path);
      }
    });
  });
}
