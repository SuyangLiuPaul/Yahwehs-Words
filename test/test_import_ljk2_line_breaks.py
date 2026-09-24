#!/usr/bin/env python3
"""Unit test for `assemble_verse_text()`'s `reference` / `paragraph`
`lineBreak` handling — `docs/autonomous-queue.md:8943`.

Before this fix, `assemble_verse_text()` only ever emitted a `'\\n'` for
`lineBreak: 'line'`; `'reference'` and `'paragraph'` fell through the
same path as `'inline'` — glued to the previous fragment with no
separator at all. Both are block-level in the publisher's own React
renderer (`ljk-nt-bible-webapp/src/components/BibleDisplay/
BibleDisplay.tsx:72-110`: `reference` opens a new `<Box
className="ot-refs">`, `paragraph` opens a new `<Text as="p">`), so the
missing separator was a defect. Reader-visible on the shipped version:
`biblexg-v3.json`'s 45003010 (Romans 3:10) read the OT quotation's two
clauses run together; `biblexg-v2.json` — the edition it replaced,
`bible_versions.dart:401-402` — kept them apart.

Proven red against the pre-fix `assemble_verse_text()` (`git stash` the
fix, this exact run, 2026-09-24):

    FAIL: test_reference_break_becomes_newline
    FAIL: test_paragraph_break_becomes_newline
    FAIL: test_empty_content_reference_break_becomes_newline

Run:
    python3 -m unittest discover -s test -p 'test_*.py' -v
    python3 test/test_import_ljk2_line_breaks.py          # same thing
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


ljk2 = _load('import_ljk2', 'tools/import_ljk2.py')


class AssembleVerseTextBreaksTest(unittest.TestCase):
    def test_reference_break_becomes_newline(self):
        # The real Romans 3:10 shape (cn-rom.json): the second clause
        # carries lineBreak='reference' after the first.
        contents = [
            {'lineBreak': 'inline', 'content': '正如经上所记：'},
            {'lineBreak': 'reference', 'content': '没有义人，一个也没有，'},
        ]
        self.assertEqual(
            ljk2.assemble_verse_text(contents),
            '正如经上所记：\n没有义人，一个也没有，')

    def test_paragraph_break_becomes_newline(self):
        contents = [
            {'lineBreak': 'inline', 'content': '第一句。'},
            {'lineBreak': 'paragraph', 'content': '第二句另起一段。'},
        ]
        self.assertEqual(
            ljk2.assemble_verse_text(contents),
            '第一句。\n第二句另起一段。')

    def test_empty_content_reference_break_becomes_newline(self):
        # Upstream sometimes marks the break as its own empty-content
        # fragment (the same convention 'line' already uses) rather than
        # attaching it to the next fragment's own lineBreak.
        contents = [
            {'lineBreak': 'inline', 'content': '第一句。'},
            {'lineBreak': 'reference', 'content': ''},
            {'lineBreak': 'inline', 'content': '第二句。'},
        ]
        self.assertEqual(
            ljk2.assemble_verse_text(contents),
            '第一句。\n第二句。')

    def test_line_break_still_works(self):
        # Not the class this fix touches — must keep working exactly as
        # before.
        contents = [
            {'lineBreak': 'inline', 'content': '第一行。'},
            {'lineBreak': 'line', 'content': '第二行。'},
        ]
        self.assertEqual(
            ljk2.assemble_verse_text(contents),
            '第一行。\n第二行。')

    def test_leading_reference_fragment_gets_no_leading_newline(self):
        # A fragment at index 0 is the verse's own start, already
        # recorded via isParagraphStart/paragraphType — not a break from
        # something before it. Explicit, not incidental: this asserts
        # the i == 0 guard directly, not just its usual side effect of
        # `parts` being empty.
        contents = [
            {'lineBreak': 'reference', 'content': '没有义人，一个也没有，'},
        ]
        self.assertEqual(
            ljk2.assemble_verse_text(contents),
            '没有义人，一个也没有，')

    def test_leading_paragraph_fragment_gets_no_leading_newline(self):
        contents = [
            {'lineBreak': 'paragraph', 'content': '这是这节的全部内容。'},
        ]
        self.assertEqual(
            ljk2.assemble_verse_text(contents),
            '这是这节的全部内容。')

    def test_inline_break_unaffected(self):
        contents = [
            {'lineBreak': 'inline', 'content': '第一句'},
            {'lineBreak': 'inline', 'content': '第二句。'},
        ]
        self.assertEqual(
            ljk2.assemble_verse_text(contents),
            '第一句第二句。')


def _verse_node(chapter_index, verse_index, contents, paragraph='inline'):
    return {
        'type': 'verse',
        'chapterIndex': str(chapter_index),
        'verseIndex': str(verse_index),
        'paragraph': paragraph,
        'contents': contents,
    }


def _chapter_node(chapter_index):
    return {'type': 'chapter', 'chapterIndex': str(chapter_index)}


def _empty_index_verse_node(contents):
    return {
        'type': 'verse',
        'chapterIndex': '3',
        'verseIndex': '',
        'paragraph': 'reference',
        'contents': contents,
    }


class StrayNodeReattachBreakTest(unittest.TestCase):
    """The stray-node reattach splice (build_book_verses, the
    verse_num == 0 branch) assembles the stray node's own contents in
    isolation, so its break marker sits at index 0 of THAT list and gets
    swallowed by the leading-fragment guard. Without recovering it at
    the splice point, Romans 3:10 itself would stay broken even after
    assemble_verse_text() is fixed — this is the case the acceptance
    criteria names directly.
    """

    def test_stray_reference_break_survives_the_splice(self):
        book_data = [{'nodeData': [
            _chapter_node(3),
            _verse_node(3, 10, [{'lineBreak': 'inline', 'content': '正如经上所记：'}],
                       paragraph='paragraph'),
            _empty_index_verse_node([
                {'lineBreak': 'reference', 'content': '没有义人，一个也没有，'},
                {'lineBreak': 'line', 'content': ''},
            ]),
            _verse_node(3, 11, [{'lineBreak': 'inline', 'content': '没有一个人明白而寻求神。'}]),
        ]}]
        verses = ljk2.build_book_verses(
            book_data, book_id=45, book_name_cn='罗马书',
            book_name_tr='羅馬書', use_tr=False)

        self.assertEqual(len(verses), 2)
        self.assertEqual(verses[0]['verse'], '10')
        self.assertEqual(
            verses[0]['text'], '正如经上所记：\n没有义人，一个也没有，')


if __name__ == '__main__':
    unittest.main()
