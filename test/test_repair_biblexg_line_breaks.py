#!/usr/bin/env python3
"""Unit test for `tools/repair_biblexg_line_breaks.py`'s `compute_repairs()`
— the guard that decides which asset rows the newline-insertion repair is
allowed to touch.

Proven red against a version of `compute_repairs()` that skips the
newline-equality check entirely (i.e. writes `new_by_id[row['id']]`
whenever it differs at all from `row['text']`): the "later repair pass
reshaped this row" and "a real character differs, refuse" tests below
would both pass a row through that must NOT be touched — the whole
point of the guard is that it is structurally impossible for this
script to change a character of scripture, or even a space.

Also proven red against the FIRST version of this guard, which stripped
ALL whitespace (`re.sub(r'\\s+', '', …)`) rather than only `'\n'`:
`test_a_stray_space_inside_a_note_tag_is_refused_not_written` reproduces
the actual defect that guard let through on a real `--write` run —
`<note:犹太人>` gained spaces to become `<note: 犹太人 >` on 8 rows
(Romans 3:9 among them) from an unrelated quirk of re-running
`html_to_inline()`, and the loose guard could not tell that apart from
a genuine `\n` insertion.

Run:
    python3 -m unittest discover -s test -p 'test_*.py' -v
    python3 test/test_repair_biblexg_line_breaks.py       # same thing
"""
import importlib.util
import os
import unittest

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def _load(name, relpath):
    spec = importlib.util.spec_from_file_location(name, os.path.join(REPO, relpath))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


repair = _load('repair_biblexg_line_breaks', 'tools/repair_biblexg_line_breaks.py')


class ComputeRepairsTest(unittest.TestCase):
    def test_newline_only_difference_is_written(self):
        rows = [{'id': '45003010', 'text': '正如经上所记：没有义人，一个也没有，'}]
        new_by_id = {'45003010': '正如经上所记：\n没有义人，一个也没有，'}
        to_write, mismatch, missing = repair.compute_repairs(rows, new_by_id)
        self.assertEqual(to_write, [(0, '45003010', '正如经上所记：\n没有义人，一个也没有，')])
        self.assertEqual(mismatch, 0)
        self.assertEqual(missing, 0)

    def test_identical_text_is_left_alone(self):
        rows = [{'id': '40001001', 'text': '亚伯拉罕的后裔，大卫的子孙，耶稣基督的家谱：'}]
        new_by_id = {'40001001': '亚伯拉罕的后裔，大卫的子孙，耶稣基督的家谱：'}
        to_write, mismatch, missing = repair.compute_repairs(rows, new_by_id)
        self.assertEqual(to_write, [])
        self.assertEqual(mismatch, 0)

    def test_row_reshaped_by_a_later_repair_pass_is_skipped_not_written(self):
        # A later repair pass (repair_biblexg splitting a merged verse,
        # repair_biblexg_v2_tr fixing a 繁体 glyph, carry_forward filling
        # a gap) changes an actual CHARACTER, not just whitespace. The
        # guard must refuse this even though the freshly rebuilt text
        # differs from the current asset text.
        rows = [{'id': '41001023', 'text': '在他們的會堂裡有一個'}]
        new_by_id = {'41001023': '在他們的會堂里有一個'}  # pre-repair spelling
        to_write, mismatch, missing = repair.compute_repairs(rows, new_by_id)
        self.assertEqual(to_write, [])
        self.assertEqual(mismatch, 1)
        self.assertEqual(missing, 0)

    def test_id_absent_from_fresh_rebuild_is_skipped_not_written(self):
        # repair_verse_numbering.py re-keys some ids after import; the
        # fresh rebuild (straight from upstream, no re-keying) will not
        # have every id the current asset does. Not a failure.
        rows = [{'id': '99999999', 'text': '不存在的经文'}]
        new_by_id = {}
        to_write, mismatch, missing = repair.compute_repairs(rows, new_by_id)
        self.assertEqual(to_write, [])
        self.assertEqual(mismatch, 0)
        self.assertEqual(missing, 1)

    def test_a_real_character_difference_disguised_by_whitespace_is_refused(self):
        # Adversarial case: the two strings look similar but a real
        # character actually differs (没 vs 沒 substituted, not just a
        # newline added) — the guard must NOT treat this as equal.
        rows = [{'id': '45003010', 'text': '正如经上所记：没有义人，一个也没有，'}]
        new_by_id = {'45003010': '正如经上所记：\n沒有义人，一个也没有，'}
        to_write, mismatch, missing = repair.compute_repairs(rows, new_by_id)
        self.assertEqual(to_write, [])
        self.assertEqual(mismatch, 1)

    def test_a_stray_space_inside_a_note_tag_is_refused_not_written(self):
        # The actual regression on the real assets (Romans 3:9 among 8
        # rows): re-running html_to_inline() added spaces around a
        # <note:> tag's content, unrelated to line breaks. A guard that
        # strips ALL whitespace (not just '\n') would wrongly call this
        # a newline-only difference and write the spaces in.
        rows = [{'id': '45003009', 'text': '我们<note:犹太人>比他们强吗？'}]
        new_by_id = {'45003009': '我们<note: 犹太人 >比他们强吗？'}
        to_write, mismatch, missing = repair.compute_repairs(rows, new_by_id)
        self.assertEqual(to_write, [])
        self.assertEqual(mismatch, 1)

    def test_multiple_rows_independent(self):
        rows = [
            {'id': 'A', 'text': 'ab'},
            {'id': 'B', 'text': 'cd'},
            {'id': 'C', 'text': 'ef'},
        ]
        new_by_id = {'A': 'a\nb', 'B': 'cd', 'C': 'zz'}
        to_write, mismatch, missing = repair.compute_repairs(rows, new_by_id)
        self.assertEqual(to_write, [(0, 'A', 'a\nb')])
        self.assertEqual(mismatch, 1)  # C
        self.assertEqual(missing, 0)


class ExpandDivMergedNodeTest(unittest.TestCase):
    """`expand_div_merged_node()` — the second pass, for upstream nodes
    that glue several verses' poetry lines together with
    `<div class="div">` HTML instead of `lineBreak` markers
    (`docs/autonomous-queue.md:9012`). Fixture is 1 Peter 3:10-12's own
    cached `tw-1pe.json` contents, trimmed to the fields the function
    reads (`content`) — real upstream markup, not invented for the test.
    """

    def _contents(self):
        return [
            {'lineBreak': 'inline', 'content': '因為：\n      '},
            {'lineBreak': 'inline', 'content': '<div class="div">誰想享受人生，</div>'},
            {'lineBreak': 'inline', 'content': '<div class="div">過好日子，</div>'},
            {'lineBreak': 'inline', 'content': '<div class="div">就得勒住舌頭不出惡言，</div>'},
            {'lineBreak': 'inline', 'content': '<div class="div">管住嘴唇不沾詭詐。</div>'},
            {'lineBreak': 'inline', 'content': '<div class="div"><sup>11</sup>還要避惡行善，</div>'},
            {'lineBreak': 'inline', 'content': '<div class="div">覓求和睦，</div>'},
            {'lineBreak': 'inline', 'content': '<div class="div">緊追不捨。</div>'},
            {'lineBreak': 'inline', 'content': '<div class="div"><sup>12</sup>因為主慈目眷顧義人，</div>'},
            {'lineBreak': 'inline', 'content': '<div class="div">側耳俯聽他們的呼聲，</div>'},
            {'lineBreak': 'inline',
             'content': '<div class="div">但主跟造孽者作對。<cite>詩34.12-16</cite></div>'},
        ]

    def test_splits_the_merged_node_into_three_verses_at_the_sup_markers(self):
        ljk2 = repair._load_import_ljk2()
        result = repair.expand_div_merged_node(ljk2, self._contents(), 10)
        self.assertEqual(set(result), {10, 11, 12})

    def test_each_verse_gets_the_cn_twin_line_structure(self):
        ljk2 = repair._load_import_ljk2()
        result = repair.expand_div_merged_node(ljk2, self._contents(), 10)
        self.assertEqual(
            result[10],
            '因為：\n誰想享受人生，\n過好日子，\n就得勒住舌頭不出惡言，\n管住嘴唇不沾詭詐。')
        self.assertEqual(result[11], '還要避惡行善，\n覓求和睦，\n緊追不捨。')

    def test_a_cite_inside_the_last_div_becomes_a_note_tag(self):
        # <cite> handling must survive being nested inside a <div> — this
        # is the same <note:…> conversion html_to_inline() always does,
        # not a special case for div-wrapped content.
        ljk2 = repair._load_import_ljk2()
        result = repair.expand_div_merged_node(ljk2, self._contents(), 10)
        self.assertEqual(
            result[12],
            '因為主慈目眷顧義人，\n側耳俯聽他們的呼聲，\n但主跟造孽者作對。<note:詩34.12-16>')

    def test_no_div_content_returns_empty(self):
        ljk2 = repair._load_import_ljk2()
        contents = [{'lineBreak': 'inline', 'content': '如果你們熱心行善，誰能傷害你們？'}]
        result = repair.expand_div_merged_node(ljk2, contents, 13)
        self.assertEqual(result, {13: '如果你們熱心行善，誰能傷害你們？'})


class ApplyTextEditsTest(unittest.TestCase):
    """`apply_text_edits()` must do a surgical, byte-level replacement of
    only the named `text` values — the first version of this script
    instead round-tripped the whole file through `json.dumps()`, which
    silently reformatted `biblexg-v3-tr.json` (pretty-printed, 1-space
    indent) into `biblexg-v3.json`'s compact style: 81,483 lines touched
    for what should have been ~212 (`git diff --stat` after the first,
    wrong, `--write` run, reverted before committing). These tests pin
    that every byte OUTSIDE the edited `text` values is preserved
    exactly, in both formatting styles this repo's two assets actually
    use.
    """

    def test_compact_style_untouched_outside_edited_value(self):
        raw = ('[{"book":"罗马书","chapter":"3","verse":"10",'
               '"text":"正如经上所记：没有义人，一个也没有，",'
               '"id":"45003010"},'
               '{"book":"罗马书","chapter":"3","verse":"11",'
               '"text":"没有一个人明白而寻求神。","id":"45003011"}]')
        edits = [('45003010', '正如经上所记：没有义人，一个也没有，',
                  '正如经上所记：\n没有义人，一个也没有，')]
        out = repair.apply_text_edits(raw, edits)
        self.assertEqual(
            out,
            '[{"book":"罗马书","chapter":"3","verse":"10",'
            '"text":"正如经上所记：\\n没有义人，一个也没有，",'
            '"id":"45003010"},'
            '{"book":"罗马书","chapter":"3","verse":"11",'
            '"text":"没有一个人明白而寻求神。","id":"45003011"}]')

    def test_pretty_printed_style_untouched_outside_edited_value(self):
        raw = (
            '[\n'
            ' {\n'
            '  "book": "羅馬書",\n'
            '  "text": "正如經上所記：沒有義人，一個也沒有，",\n'
            '  "id": "45003010"\n'
            ' }\n'
            ']'
        )
        edits = [('45003010', '正如經上所記：沒有義人，一個也沒有，',
                  '正如經上所記：\n沒有義人，一個也沒有，')]
        out = repair.apply_text_edits(raw, edits)
        self.assertEqual(
            out,
            '[\n'
            ' {\n'
            '  "book": "羅馬書",\n'
            '  "text": "正如經上所記：\\n沒有義人，一個也沒有，",\n'
            '  "id": "45003010"\n'
            ' }\n'
            ']'
        )

    def test_stale_text_in_file_is_refused_not_overwritten(self):
        raw = '[{"text":"甲","id":"1"}]'
        # The edit was computed against 'old', but the file actually has
        # '甲' — must refuse rather than blindly write the new value in.
        edits = [('1', 'old', 'new')]
        with self.assertRaises(ValueError):
            repair.apply_text_edits(raw, edits)

    def test_missing_id_is_refused(self):
        raw = '[{"text":"甲","id":"1"}]'
        edits = [('2', '甲', '乙')]
        with self.assertRaises(ValueError):
            repair.apply_text_edits(raw, edits)


if __name__ == '__main__':
    unittest.main()
