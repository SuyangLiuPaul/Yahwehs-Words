#!/usr/bin/env python3
"""Unit tests for `tools/audit_biblexg_blocknote_parity.py`'s matching
primitives — the parts that do not need `opencc` or the publisher source
cache, so these always run on CI (which has neither).

Run:
    python3 test/test_audit_biblexg_blocknote_parity.py
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


parity = _load('audit_biblexg_blocknote_parity',
                'tools/audit_biblexg_blocknote_parity.py')


class ExtraChunksTest(unittest.TestCase):
    def test_pure_insertion_is_one_chunk(self):
        a = '相同的开头。'
        b = '相同的开头。这一段是新增的、超过二十个字符长的额外内容。'
        chunks = parity.extra_chunks(a, b)
        self.assertEqual(chunks, ['这一段是新增的、超过二十个字符长的额外内容。'])

    def test_short_difference_below_min_chunk_is_dropped(self):
        a = '这句话很长而且相同除了一个字不同啊'
        b = '这句话很长而且相同除了两个字不同啊'
        self.assertEqual(parity.extra_chunks(a, b), [])

    def test_identical_text_has_no_chunks(self):
        text = '完全相同的一句话，长度也足够长了。'
        self.assertEqual(parity.extra_chunks(text, text), [])


class FindInNotesTest(unittest.TestCase):
    def setUp(self):
        self.notes = [
            '1节注：第一条注释，内容是关于创世记的一些背景说明文字。',
            '2节注：第二条注释，内容是关于摩西五经的一些背景说明文字。',
            '3节注：第三条注释，内容是关于先知书的一些背景说明文字。',
        ]

    def test_exact_note_is_found(self):
        self.assertTrue(parity.find_in_notes(self.notes[1], self.notes))

    def test_near_duplicate_single_char_variant_is_found(self):
        # Same content as notes[1] but one wording choice changed, the
        # same shape as this corpus's 藉著/借着 or 稣/穌 variants.
        near = '2节注：第二条注释，内容是关于摩西五经的一些背景說明文字。'
        self.assertTrue(parity.find_in_notes(near, self.notes))

    def test_split_across_two_adjacent_notes_is_found_via_window(self):
        combined = parity.norm(' '.join(self.notes[1:3]))
        self.assertTrue(parity.find_in_notes(combined, self.notes,
                                              max_window=3))

    def test_genuinely_absent_content_is_not_found(self):
        absent = '9节注：这是一条完全不同的、关于但以理书异象的注释内容。'
        self.assertFalse(parity.find_in_notes(absent, self.notes))

    def test_empty_chunk_or_notes_is_not_found(self):
        self.assertFalse(parity.find_in_notes('', self.notes))
        self.assertFalse(parity.find_in_notes(self.notes[0], []))


class LabelTest(unittest.TestCase):
    def test_label_of_simplified_and_traditional(self):
        self.assertEqual(parity.label_of('36节注：“主对我主说”……'), '36')
        self.assertEqual(parity.label_of('36節註：“主對我主說”……'), '36')

    def test_label_of_verse_range(self):
        self.assertEqual(parity.label_of('4-5节注：“部位、手足”……'), '4-5')

    def test_label_of_no_label_is_none(self):
        self.assertIsNone(parity.label_of('“与自己的信心成比例”意译自……'))

    def test_same_chapter_has_label_matches_within_chapter_only(self):
        notes_by_id = {
            '41012036': ['36节注：本注在这一节。'],
            '41012037': ['36節註：同一个36号注，换了个动词。'],
            '42012036': ['36节注：另一卷书恰好也有36号注，不该被算作同一个点。'],
        }
        self.assertTrue(parity.same_chapter_has_label(
            notes_by_id, '41012036', '36'))
        # Different book/chapter sharing the same bare label number must
        # not count — labels restart every chapter, so a book-wide match
        # would pair up unrelated verses.
        self.assertFalse(parity.same_chapter_has_label(
            notes_by_id, '42012036', '36'))


class BookAbbrAndChapterTest(unittest.TestCase):
    def test_mark_1_27(self):
        abbr, chapter = parity.book_abbr_and_chapter('41001027')
        self.assertEqual(abbr, 'mk')
        self.assertEqual(chapter, '1')

    def test_romans_12_8(self):
        abbr, chapter = parity.book_abbr_and_chapter('45012008')
        self.assertEqual(abbr, 'rom')
        self.assertEqual(chapter, '12')

    def test_revelation_8_12(self):
        abbr, chapter = parity.book_abbr_and_chapter('66008012')
        self.assertEqual(abbr, 'rev')
        self.assertEqual(chapter, '8')


class PendingClassificationShapeTest(unittest.TestCase):
    """The pinned set is what makes non-zero exit mean something. Guard
    its shape so a future edit can't silently turn it into a no-op."""

    def test_ids_are_eight_digit_or_suffixed_strings(self):
        for group, ref in parity.PENDING_CLASSIFICATION:
            for vid in group:
                self.assertRegex(vid, r'^\d{8}[a-z]?$', msg=f'{vid} ({ref})')

    def test_no_duplicate_ids_across_groups(self):
        seen = []
        for group, _ref in parity.PENDING_CLASSIFICATION:
            seen.extend(group)
        self.assertEqual(len(seen), len(set(seen)), seen)

    def test_pending_ids_matches_flattened_groups(self):
        expected = {vid for group, _ in parity.PENDING_CLASSIFICATION
                    for vid in group}
        self.assertEqual(parity.PENDING_IDS, expected)


if __name__ == '__main__':
    unittest.main()
