#!/usr/bin/env python3
"""Unit test for `tools/import_ljk2.py`'s `split_block_comment()`.

Commit 16633cad (2026-09-14, "The 梁家鏗譯本 is the September fetch…")
replaced the importer wholesale with a copy predating 9a3c5cac
(2026-08-11, "two half-verses were being read as the editor's notes"),
reverting it. `clean_block_comment()` went back to folding a `comment`
node's `{lineBreak, content}` dict items into the footnote string —
those dicts are the PRECEDING VERSE'S OWN BODY, not the note quoting a
verse, so half a verse (約翰福音 12:36b, 約翰一書 4:16b) reads as the
editor's aside instead of scripture.

This test feeds a synthetic `comment` node whose `contents` mixes a
plain footnote string with a `{lineBreak, content}` dict through
`build_book_verses()` and asserts the dict's text is appended to the
PRECEDING verse's `text`, while only the plain string ends up in
`blockNotes` — proven red against the HEAD that read both as footnote,
green once `split_block_comment()` is restored.

Run:
    python3 -m unittest discover -s test -p 'test_*.py' -v
    python3 test/test_import_ljk2_split_block_comment.py   # same thing
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


class SplitBlockCommentTest(unittest.TestCase):
    def test_dict_segment_is_appended_to_preceding_verse_body(self):
        book_data = [{'nodeData': [
            _chapter_node(12),
            _verse_node(12, 36, '使你們成為光明之子。'),
            {
                'type': 'comment',
                'contents': [
                    '36节注：约翰福音结束语。',
                    {'content': '耶穌說完了這些話，便離開他們，隱藏起來了。',
                     'lineBreak': 'inline'},
                ],
            },
        ]}]
        verses = ljk2.build_book_verses(
            book_data, book_id=43, book_name_cn='约翰福音',
            book_name_tr='約翰福音', use_tr=False)

        self.assertEqual(len(verses), 1)
        verse = verses[0]
        self.assertEqual(
            verse['text'],
            '使你們成為光明之子。耶穌說完了這些話，便離開他們，隱藏起來了。')

        notes = verse.get('blockNotes', [])
        self.assertEqual(len(notes), 1, f'expected one note, got {notes!r}')
        self.assertIn('约翰福音结束语', notes[0])
        self.assertNotIn('耶穌說完了這些話', notes[0])

    def test_plain_string_only_comment_is_unaffected(self):
        book_data = [{'nodeData': [
            _chapter_node(1),
            _verse_node(1, 1, '起初有道。'),
            {
                'type': 'comment',
                'contents': ['1节注：道，即逻各斯。'],
            },
        ]}]
        verses = ljk2.build_book_verses(
            book_data, book_id=43, book_name_cn='约翰福音',
            book_name_tr='約翰福音', use_tr=False)

        verse = verses[0]
        self.assertEqual(verse['text'], '起初有道。')
        notes = verse.get('blockNotes', [])
        self.assertEqual(len(notes), 1)
        self.assertIn('道，即逻各斯', notes[0])


if __name__ == '__main__':
    unittest.main()
