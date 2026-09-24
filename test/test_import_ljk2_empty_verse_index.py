#!/usr/bin/env python3
"""Unit test for `tools/import_ljk2.py`'s handling of a `verse` node whose
`verseIndex` is empty.

Found 2026-09-24 auditing the live source (`/tmp/ljk-source/`, 54 files,
15845 `verse` nodes): 4 carry an empty-string `verseIndex` rather than a
number or a range like `1-2`. Three are empty-content (harmless — blank
paragraph markers). The fourth, `cn-rom.json` chapter 3, between verse 10
and verse 11, carries real text — 「没有义人，一个也没有，」, the second
clause of Romans 3:10 — and `build_book_verses()`'s
`if verse_num == 0: continue` dropped it with no warning.

This is latent, not shipped: `assets/biblexg-v3.json`'s `45003010`
already reads the full two-clause verse (checked directly, 2026-09-24),
so no reader is missing text today. But the NEXT re-fetch from upstream
would silently ship Romans 3:10 as only its first clause — same failure
shape as `5420cda5` (`clean_comment_list`) and `b461ede8`
(`split_block_comment()`): a node type/shape the importer stops handling
and scripture vanishes with no log line.

Proven red against HEAD before the fix (`git stash` the fix, this exact
run, 2026-09-24) — 3 of 5 failed:

    FAIL: test_stray_text_at_start_of_new_chapter_fails_loudly
    AssertionError: ValueError not raised
    FAIL: test_stray_text_reattaches_to_preceding_verse
    AssertionError: '正如经上所记：' != '正如经上所记：没有义人，一个也没有，'
    FAIL: test_stray_text_with_no_preceding_verse_fails_loudly
    AssertionError: ValueError not raised
    Ran 5 tests in 0.004s
    FAILED (failures=3)

Green after `build_book_verses()` reattaches a non-empty-content,
empty-verseIndex verse node's text to the immediately preceding verse
(the same convention the `comment` branch already uses for its
`split_block_comment()` body) — guarded by BOTH "a preceding verse
exists" and "it's in the same chapter", since `out` spans the whole
book and a bare non-empty check would silently splice a stray node that
opens a new chapter onto the PREVIOUS chapter's last verse instead of
raising.

`test_stray_text_reattaches_to_preceding_verse`'s expected text was
updated 2026-09-24 (`docs/autonomous-queue.md:8943`) to include the
`\n` between the two clauses. The stray node here carries
`lineBreak: 'reference'` on its own first fragment, which
`assemble_verse_text()` used to drop entirely (same bug as :8943) —
this test's old expectation of no separator baked that bug in as
"correct". See `test/test_import_ljk2_line_breaks.py` for the fix and
why the splice needed its own change, not just `assemble_verse_text()`.

Run:
    python3 -m unittest discover -s test -p 'test_*.py' -v
    python3 test/test_import_ljk2_empty_verse_index.py    # same thing
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


def _verse_node(chapter_index, verse_index, text):
    return {
        'type': 'verse',
        'chapterIndex': str(chapter_index),
        'verseIndex': str(verse_index),
        'paragraph': 'paragraph',
        'contents': [{'content': text, 'lineBreak': 'inline'}],
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


class EmptyVerseIndexTest(unittest.TestCase):
    def test_stray_text_reattaches_to_preceding_verse(self):
        # The actual cn-rom.json ch3 shape, between verse 10 and verse 11.
        book_data = [{'nodeData': [
            _chapter_node(3),
            _verse_node(3, 10, '正如经上所记：'),
            _empty_index_verse_node([
                {'lineBreak': 'reference', 'content': '没有义人，一个也没有，'},
                {'lineBreak': 'line', 'content': ''},
            ]),
            _verse_node(3, 11, '没有一个人明白而寻求神。'),
        ]}]
        verses = ljk2.build_book_verses(
            book_data, book_id=45, book_name_cn='罗马书',
            book_name_tr='羅馬書', use_tr=False)

        self.assertEqual(len(verses), 2, f'stray node must not become its own verse: {verses!r}')
        self.assertEqual(verses[0]['verse'], '10')
        self.assertEqual(verses[0]['text'], '正如经上所记：\n没有义人，一个也没有，')
        self.assertEqual(verses[1]['verse'], '11')
        self.assertEqual(verses[1]['text'], '没有一个人明白而寻求神。')

    def test_empty_content_empty_index_node_still_dropped(self):
        # The other three known cases (tw-1ti ch1/ch5, tw-eph ch6): empty
        # verseIndex AND empty content. Stays silently dropped — nothing
        # to lose.
        book_data = [{'nodeData': [
            _chapter_node(1),
            _verse_node(1, 1, '起初有道。'),
            _empty_index_verse_node([{'lineBreak': 'line', 'content': ''}]),
            _verse_node(1, 2, '道成了肉身。'),
        ]}]
        verses = ljk2.build_book_verses(
            book_data, book_id=43, book_name_cn='约翰福音',
            book_name_tr='約翰福音', use_tr=False)

        self.assertEqual(len(verses), 2)
        self.assertEqual(verses[0]['text'], '起初有道。')
        self.assertEqual(verses[1]['text'], '道成了肉身。')

    def test_range_label_is_untouched(self):
        # '1-2' etc. must keep going through the normal numeric path,
        # not the empty-verseIndex path this test targets.
        book_data = [{'nodeData': [
            _chapter_node(5),
            _verse_node(5, '1-2', '并且我们藉着他，因信得进入现在所站的这恩典中，'),
        ]}]
        verses = ljk2.build_book_verses(
            book_data, book_id=45, book_name_cn='罗马书',
            book_name_tr='羅馬書', use_tr=False)

        self.assertEqual(len(verses), 1)
        self.assertEqual(verses[0]['verse'], '1')
        self.assertEqual(verses[0]['verseLabel'], '1-2')

    def test_stray_text_with_no_preceding_verse_fails_loudly(self):
        book_data = [{'nodeData': [
            _chapter_node(3),
            _empty_index_verse_node([
                {'lineBreak': 'reference', 'content': '没有义人，'},
            ]),
        ]}]
        with self.assertRaises(ValueError):
            ljk2.build_book_verses(
                book_data, book_id=45, book_name_cn='罗马书',
                book_name_tr='羅馬書', use_tr=False)

    def test_stray_text_at_start_of_new_chapter_fails_loudly(self):
        # `out` spans the whole book. A stray node opening a NEW chapter
        # (right after the `chapter` node, before that chapter's own
        # first verse) must NOT get silently spliced onto the PREVIOUS
        # chapter's last verse just because `out` happens to be
        # non-empty — it must raise, same as the true book-start case.
        book_data = [{'nodeData': [
            _chapter_node(1),
            _verse_node(1, 1, '起初有道。'),
            _chapter_node(2),
            _empty_index_verse_node([
                {'lineBreak': 'reference', 'content': '这道太初与神同在。'},
            ]),
            _verse_node(2, 1, '这道就是神。'),
        ]}]
        with self.assertRaises(ValueError):
            ljk2.build_book_verses(
                book_data, book_id=43, book_name_cn='约翰福音',
                book_name_tr='約翰福音', use_tr=False)


if __name__ == '__main__':
    unittest.main()
