#!/usr/bin/env python3
"""Unit tests for the `--edition` flag added to
`tools/audit_biblexg_v2_vs_tr.py` (docs/autonomous-queue.md, the
2026-09-27 item measuring biblexg-v3's note-apparatus drift).

Before this flag the script hardcoded `assets/biblexg-v2.json` /
`biblexg-v2-tr.json` and `~/.cache/yswords/ljk-source`, so it had never
been pointed at the reader-selectable v3 pair. These tests exercise the
plumbing only — asset-path/cache-dir selection and the
`ACCOUNTED_FOR_TEXT` lookup key — with no real file or opencc I/O,
mirroring test_audit_biblexg_notes.py's style.
"""
import contextlib
import importlib.util
import io
import os
import unittest
from unittest import mock

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def _load(name, relpath):
    spec = importlib.util.spec_from_file_location(name, os.path.join(REPO, relpath))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


v2vstr = _load('audit_biblexg_v2_vs_tr', os.path.join('tools', 'audit_biblexg_v2_vs_tr.py'))


class SourceDirsForTest(unittest.TestCase):
    def test_v2_includes_the_gitignored_webapp_fallback(self):
        dirs = v2vstr.source_dirs_for('v2')
        self.assertEqual(dirs[0], v2vstr.EDITIONS['v2']['cache_dir'])
        self.assertTrue(any('ljk-nt-bible-webapp' in d for d in dirs))

    def test_v3_has_its_own_cache_dir_and_no_webapp_fallback(self):
        dirs = v2vstr.source_dirs_for('v3')
        self.assertEqual(dirs, [v2vstr.EDITIONS['v3']['cache_dir']])
        self.assertFalse(any('ljk-nt-bible-webapp' in d for d in dirs))
        self.assertNotEqual(v2vstr.EDITIONS['v3']['cache_dir'],
                             v2vstr.EDITIONS['v2']['cache_dir'])


class EditionAssetSelectionTest(unittest.TestCase):
    """main() must read the edition's OWN asset pair, not v2's, when
    --edition v3 is passed — this is the exact defect the flag fixes."""

    def setUp(self):
        self._orig_load_ours = v2vstr.load_ours
        self._orig_find_source_dir = v2vstr.find_source_dir
        self.addCleanup(self._restore)
        self.requested_paths = []

        def fake_load_ours(path):
            self.requested_paths.append(path)
            return {}

        v2vstr.load_ours = fake_load_ours
        v2vstr.find_source_dir = lambda edition: None  # short-circuit to SKIP

    def _restore(self):
        v2vstr.load_ours = self._orig_load_ours
        v2vstr.find_source_dir = self._orig_find_source_dir

    def _run_main(self, argv):
        with mock.patch.object(v2vstr.sys, 'argv', argv), \
                contextlib.redirect_stdout(io.StringIO()):
            v2vstr.main()

    def test_default_edition_reads_v2_assets(self):
        # find_source_dir is stubbed to None, so main() SKIPs before any
        # load_ours() call — this only proves argparse's default is 'v2'
        # and that a bare invocation doesn't error.
        self._run_main(['audit_biblexg_v2_vs_tr.py'])
        self.assertEqual(self.requested_paths, [])

    def test_v3_edition_reads_v3_assets_not_v2(self):
        v2vstr.find_source_dir = lambda edition: '/fake/cache/' + edition
        self._run_main(['audit_biblexg_v2_vs_tr.py', '--edition', 'v3'])
        self.assertEqual(self.requested_paths, [
            v2vstr.EDITIONS['v3']['cn_asset'],
            v2vstr.EDITIONS['v3']['tr_asset'],
        ])

    def test_v2_edition_reads_v2_assets(self):
        v2vstr.find_source_dir = lambda edition: '/fake/cache/' + edition
        self._run_main(['audit_biblexg_v2_vs_tr.py', '--edition', 'v2'])
        self.assertEqual(self.requested_paths, [
            v2vstr.EDITIONS['v2']['cn_asset'],
            v2vstr.EDITIONS['v2']['tr_asset'],
        ])


class AccountedForTextKeyTest(unittest.TestCase):
    """ACCOUNTED_FOR_TEXT lookups must key on the requested edition, not
    a hardcoded 'v2' — otherwise a v2-verified reason would silently
    also suppress an unverified v3 divergence (the same bug class fixed
    upstream in audit_biblexg_notes.py, commit 2a6f5702)."""

    def test_v3_only_entry_does_not_leak_under_v2_lookup(self):
        marker = {'reason': 'v3-only, should not explain a v2 verse'}
        v2vstr.ACCOUNTED_FOR_TEXT[('v3', 'tw', '馬太福音', '1')] = marker
        try:
            self.assertIsNone(
                v2vstr.ACCOUNTED_FOR_TEXT.get(('v2', 'tw', '馬太福音', '1')))
            self.assertIs(
                v2vstr.ACCOUNTED_FOR_TEXT.get(('v3', 'tw', '馬太福音', '1')),
                marker)
        finally:
            del v2vstr.ACCOUNTED_FOR_TEXT[('v3', 'tw', '馬太福音', '1')]


if __name__ == '__main__':
    unittest.main()
