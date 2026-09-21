#!/usr/bin/env python3
"""Unit tests for `tools/audit_biblexg_notes.py`'s two edition-scoping /
per-note-matching rules added by the fix filed at
docs/autonomous-queue.md:8815 ("ACCOUNTED_FOR_TEXT is chapter-granular
and edition-agnostic").

Before the fix, both ACCOUNTED_FOR and ACCOUNTED_FOR_TEXT were keyed
without an edition, and ACCOUNTED_FOR_TEXT matched an entire chapter as
soon as ANY reason existed for it — so a reason verified against v2
would also silence an unrelated, unverified difference in the same
chapter under v3, and a reason that explained one note pair would
silently cover a second, different note pair in the same chapter too.

Neither `fetch()` nor `publisher_cites()`'s real network/cache path is
touched: `audit()`/`audit_text()` are exercised with `fetch` and
`publisher_cites` monkeypatched to return small synthetic per-book data,
and `ours()` monkeypatched to avoid reading assets/. Only the book
`mt`/`馬太福音`/`马太福音` carries any synthetic data; every other of the
27 BOOKS rows resolves to an empty dict, so the loop over BOOKS is inert
for them and the test is isolated to the one row under test.

Run:
    python3 -m unittest discover -s test -p 'test_*.py' -v
    python3 test/test_audit_biblexg_notes.py        # same thing
"""
import contextlib
import importlib.util
import io
import os
import unittest

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def _load(name, relpath):
    spec = importlib.util.spec_from_file_location(name, os.path.join(REPO, relpath))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


notes = _load('audit_biblexg_notes', os.path.join('tools', 'audit_biblexg_notes.py'))


class _NotesFixture(unittest.TestCase):
    """Common monkeypatch scaffolding: replace fetch()/publisher_cites()
    with a per-abbr lookup table keyed by a string tag instead of the
    real chapters list, and ours() with a fixed dict — no file or
    network I/O for either audit() or audit_text()."""

    def setUp(self):
        self._orig_fetch = notes.fetch
        self._orig_publisher_cites = notes.publisher_cites
        self._orig_ours = notes.ours
        self._orig_accounted_for = dict(notes.ACCOUNTED_FOR)
        self._orig_accounted_for_text = dict(notes.ACCOUNTED_FOR_TEXT)
        self.addCleanup(self._restore)

    def _restore(self):
        notes.fetch = self._orig_fetch
        notes.publisher_cites = self._orig_publisher_cites
        notes.ours = self._orig_ours
        notes.ACCOUNTED_FOR = self._orig_accounted_for
        notes.ACCOUNTED_FOR_TEXT = self._orig_accounted_for_text

    def _stub_publisher(self, cites_by_abbr):
        """cites_by_abbr: {abbr: {(chapter, label): [cite, …]}}. fetch()
        just tags which abbr was asked for; publisher_cites() reads the
        tag back out of the lookup table, so no real chapter payload is
        ever built or parsed."""
        notes.fetch = lambda lang, abbr, refresh, cache_dir: abbr
        notes.publisher_cites = lambda abbr: cites_by_abbr.get(abbr, {})

    def _run(self, fn, *args):
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            result = fn(*args)
        return result, buf.getvalue()


# --- audit(): edition-scoped ACCOUNTED_FOR ----------------------------------

class AuditEditionScoping(_NotesFixture):
    """A count mismatch on 馬太福音 1:1, with a reason registered only
    under 'v2'. audit() must silence it for edition='v2' and NOT for
    edition='v3' — proving ACCOUNTED_FOR no longer matches across
    editions just because (lang, ref) matches."""

    def setUp(self):
        super().setUp()
        notes.ours = lambda asset: {('馬太福音', '1', '1'): ['x']}
        self._stub_publisher({'mt': {('1', '1'): ['a', 'b']}})
        notes.ACCOUNTED_FOR = {
            ('v2', 'tw', '馬太福音 1:1'): 'test-only reason, v2 only'}

    def test_v2_reason_silences_v2_mismatch(self):
        unexplained, out = self._run(
            notes.audit, 'v2', 'tw', 'dummy-asset', 2, False, 'dummy-cache')
        self.assertEqual(unexplained, 0)
        self.assertIn('ok  馬太福音 1:1', out)

    def test_same_reason_does_not_silence_v3_mismatch(self):
        unexplained, out = self._run(
            notes.audit, 'v3', 'tw', 'dummy-asset', 2, False, 'dummy-cache')
        self.assertEqual(unexplained, 1)
        self.assertIn('** 馬太福音 1:1', out)
        self.assertNotIn('ok  馬太福音 1:1', out)


# --- audit_text(): edition-scoped, per-note ACCOUNTED_FOR_TEXT -------------

class AuditTextEditionScoping(_NotesFixture):
    """Same edition-isolation proof as above, for the text pass."""

    def setUp(self):
        super().setUp()
        notes.ours = lambda asset: {('馬太福音', '1', '1'): ['x']}
        self._stub_publisher({'mt': {('1', '1'): ['x', 'a']}})
        notes.ACCOUNTED_FOR_TEXT = {
            ('v2', 'tw', '馬太福音', '1'): {
                'missing': ['a'], 'extra': [], 'reason': 'test-only, v2'}}

    def test_v2_reason_silences_v2_chapter(self):
        unexplained, out = self._run(
            notes.audit_text, 'v2', 'tw', 'dummy-asset', 2, False, 'cache')
        self.assertEqual(unexplained, 0)
        self.assertIn('ok  馬太福音 1', out)

    def test_same_reason_does_not_silence_v3_chapter(self):
        unexplained, out = self._run(
            notes.audit_text, 'v3', 'tw', 'dummy-asset', 2, False, 'cache')
        self.assertEqual(unexplained, 1)
        self.assertIn('** 馬太福音 1', out)


class AuditTextPerNoteMatching(_NotesFixture):
    """The other half of the fix: a reason that names an exact
    missing/extra multiset must not cover a DIFFERENT multiset that
    happens to fall in the same chapter. Both cases here are keyed
    identically (v2/tw/馬太福音/1) — only the observed difference
    changes between the two tests."""

    def setUp(self):
        super().setUp()
        notes.ours = lambda asset: {('馬太福音', '1', '1'): ['x']}
        notes.ACCOUNTED_FOR_TEXT = {
            ('v2', 'tw', '馬太福音', '1'): {
                'missing': ['a'], 'extra': [], 'reason': 'covers only "a"'}}

    def test_exact_match_is_ok(self):
        self._stub_publisher({'mt': {('1', '1'): ['x', 'a']}})
        unexplained, out = self._run(
            notes.audit_text, 'v2', 'tw', 'dummy-asset', 2, False, 'cache')
        self.assertEqual(unexplained, 0)
        self.assertIn('ok  馬太福音 1: covers only "a"', out)

    def test_different_missing_set_is_not_covered_by_same_chapter_reason(self):
        """Same chapter, same reason key — but the publisher's actual
        difference is 'b', not the 'a' the reason was checked against.
        Before the fix this printed 'ok' anyway because a reason existed
        for (lang, book, chapter) at all; the fix requires the exact
        multiset."""
        self._stub_publisher({'mt': {('1', '1'): ['x', 'b']}})
        unexplained, out = self._run(
            notes.audit_text, 'v2', 'tw', 'dummy-asset', 2, False, 'cache')
        self.assertEqual(unexplained, 1)
        self.assertIn('** 馬太福音 1', out)
        self.assertNotIn('ok  馬太福音 1', out)

    def test_matching_missing_but_extra_note_present_is_not_covered(self):
        """The reason covers a chapter where we are MISSING 'a' and have
        no extra note. Here we are missing 'a' as expected but ALSO
        carry an unrelated extra note 'y' the reason never mentioned —
        that must still fall through, not be waved through by the
        'missing' half matching."""
        self._stub_publisher({'mt': {('1', '1'): ['a']}})
        notes.ours = lambda asset: {('馬太福音', '1', '1'): ['x', 'y']}
        unexplained, out = self._run(
            notes.audit_text, 'v2', 'tw', 'dummy-asset', 2, False, 'cache')
        self.assertEqual(unexplained, 1)
        self.assertIn('** 馬太福音 1', out)


if __name__ == '__main__':
    unittest.main()
