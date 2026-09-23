#!/usr/bin/env python3
"""Unit test for `tools/import_ljk2.py`'s `comment-list` / `ul-comment-list`
handling in `build_book_verses()`.

Commit 16633cad (2026-09-14, "The 梁家鏗譯本 is the September fetch…")
deleted `clean_comment_list()` and the `elif t in ('comment-list',
'ul-comment-list')` branch that 21bd0308 (2026-08-31) had added, reverting
that fix. `build_book_verses()` silently dropped every enumerated /
bulleted block-note list again — 22 verses per edition, 0 gained, across
both `biblexg-v3` and `biblexg-v3-tr` (measured over the shipped assets;
see docs/autonomous-queue.md). This test feeds a synthetic `comment-list`
node through `build_book_verses()` and asserts the numbered list survives
into `blockNotes` — proven red against the HEAD that only handled
`chapter`/`verse`/`comment`, green once the branch is restored.

Run:
    python3 -m unittest discover -s test -p 'test_*.py' -v
    python3 test/test_import_ljk2_comment_list.py        # same thing
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


class CommentListTest(unittest.TestCase):
    def test_ordered_comment_list_becomes_numbered_block_note(self):
        book_data = [{'nodeData': [
            _chapter_node(1),
            _verse_node(1, 1, '起初有道。'),
            {
                'type': 'comment-list',
                'contents': [
                    '<li>泛指任何神明；（如林前8.5）</li>'
                    '<li>特指以色列的神耶和华</li>'
                    '<li>指耶稣基督本身</li>'
                ],
            },
        ]}]
        verses = ljk2.build_book_verses(
            book_data, book_id=43, book_name_cn='约翰福音',
            book_name_tr='約翰福音', use_tr=False)

        self.assertEqual(len(verses), 1)
        notes = verses[0].get('blockNotes', [])
        self.assertEqual(len(notes), 1, f'expected one list note, got {notes!r}')
        list_note = notes[0]
        self.assertIn('1. 泛指任何神明', list_note)
        self.assertIn('2. 特指以色列的神耶和华', list_note)
        self.assertIn('3. 指耶稣基督本身', list_note)

    def test_unordered_comment_list_becomes_bulleted_block_note(self):
        book_data = [{'nodeData': [
            _chapter_node(1),
            _verse_node(1, 1, '起初有道。'),
            {
                'type': 'ul-comment-list',
                'contents': ['<li>甲</li><li>乙</li>'],
            },
        ]}]
        verses = ljk2.build_book_verses(
            book_data, book_id=43, book_name_cn='约翰福音',
            book_name_tr='約翰福音', use_tr=False)

        notes = verses[0].get('blockNotes', [])
        self.assertEqual(len(notes), 1)
        self.assertIn('• 甲', notes[0])
        self.assertIn('• 乙', notes[0])


if __name__ == '__main__':
    unittest.main()
