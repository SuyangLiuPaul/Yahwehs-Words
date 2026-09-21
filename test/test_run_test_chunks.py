#!/usr/bin/env python3
"""Unit tests for tools/run_test_chunks.py.

Run as `python3 test/test_run_test_chunks.py` — CI runs the test/ files
one at a time on purpose, never `unittest discover` (most files under
test/ load gitignored, locally-staged corpora; see .github/workflows/
flutter-ci.yml and the sibling test files' own comments for why). This
file uses only synthetic in-memory fixtures (a fake `sizer` function, no
filesystem, no `flutter` invocation), so it is safe to run unconditionally.
"""
import os
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))

import run_test_chunks as rtc  # noqa: E402


def make_sizer(sizes):
    return lambda path: sizes[path]


class TestPartition(unittest.TestCase):
    def test_covers_every_file_exactly_once(self):
        files = [f"test/f{i}_test.dart" for i in range(10)]
        sizer = make_sizer({p: 100 for p in files})
        chunks = rtc.partition(files, 3, sizer=sizer)
        flat = [p for chunk in chunks for p in chunk]
        self.assertEqual(sorted(flat), sorted(files))
        self.assertEqual(len(flat), len(set(flat)))

    def test_deterministic_across_two_calls(self):
        files = [f"test/f{i}_test.dart" for i in range(37)]
        sizer = make_sizer({p: (i * 37) % 900 + 1 for i, p in enumerate(files)})
        first = rtc.partition(files, 6, sizer=sizer)
        second = rtc.partition(files, 6, sizer=sizer)
        self.assertEqual(first, second)

    def test_of_larger_than_file_count_leaves_empty_chunks(self):
        files = ["test/a_test.dart", "test/b_test.dart"]
        sizer = make_sizer({p: 10 for p in files})
        chunks = rtc.partition(files, 5, sizer=sizer)
        self.assertEqual(len(chunks), 5)
        non_empty = [c for c in chunks if c]
        self.assertEqual(sum(len(c) for c in non_empty), 2)
        self.assertEqual(sum(1 for c in chunks if not c), 3)

    def test_oversized_files_land_in_different_chunks(self):
        files = ["test/huge_a_test.dart", "test/huge_b_test.dart"] + [
            f"test/small{i}_test.dart" for i in range(8)
        ]
        sizes = {"test/huge_a_test.dart": 100_000, "test/huge_b_test.dart": 100_000}
        sizes.update({f"test/small{i}_test.dart": 10 for i in range(8)})
        chunks = rtc.partition(files, 4, sizer=make_sizer(sizes))
        chunk_of = {}
        for i, chunk in enumerate(chunks):
            for p in chunk:
                chunk_of[p] = i
        self.assertNotEqual(
            chunk_of["test/huge_a_test.dart"], chunk_of["test/huge_b_test.dart"]
        )

    def test_rejects_n_less_than_one(self):
        with self.assertRaises(ValueError):
            rtc.partition(["test/a_test.dart"], 0, sizer=make_sizer({"test/a_test.dart": 1}))


class TestCheckPartition(unittest.TestCase):
    def test_ok_on_full_coverage_no_duplication(self):
        files = ["test/a_test.dart", "test/b_test.dart"]
        chunks = [["test/a_test.dart"], ["test/b_test.dart"]]
        ok, _ = rtc.check_partition(files, chunks)
        self.assertTrue(ok)

    def test_fails_on_duplicate_file(self):
        files = ["test/a_test.dart", "test/b_test.dart"]
        chunks = [["test/a_test.dart"], ["test/a_test.dart", "test/b_test.dart"]]
        ok, message = rtc.check_partition(files, chunks)
        self.assertFalse(ok)
        self.assertIn("a_test.dart", message)

    def test_fails_on_missing_file(self):
        files = ["test/a_test.dart", "test/b_test.dart"]
        chunks = [["test/a_test.dart"]]
        ok, message = rtc.check_partition(files, chunks)
        self.assertFalse(ok)
        self.assertIn("missing", message)

    def test_fails_on_empty_chunk(self):
        files = ["test/a_test.dart"]
        chunks = [["test/a_test.dart"], []]
        ok, message = rtc.check_partition(files, chunks)
        self.assertFalse(ok)
        self.assertIn("empty", message)


class TestCli(unittest.TestCase):
    def _run(self, argv):
        import io

        stdout = io.StringIO()
        stderr = io.StringIO()
        old_out, old_err = sys.stdout, sys.stderr
        sys.stdout, sys.stderr = stdout, stderr
        try:
            rc = rtc.main(argv)
        finally:
            sys.stdout, sys.stderr = old_out, old_err
        return rc, stdout.getvalue(), stderr.getvalue()

    def test_check_against_real_tree_exits_zero(self):
        rc, out, err = self._run(["--check"])
        self.assertEqual(rc, 0, err)
        self.assertIn("OK", out)

    def test_list_against_real_tree_covers_every_file(self):
        files = rtc.discover()
        rc, out, err = self._run(["--list", "--of", "6"])
        self.assertEqual(rc, 0, err)
        for path in files:
            self.assertIn(path, out)

    def test_invalid_chunk_index_exits_nonzero(self):
        rc, out, err = self._run(["--chunk", "99", "--of", "6"])
        self.assertNotEqual(rc, 0)

    def test_invalid_of_exits_nonzero(self):
        rc, out, err = self._run(["--chunk", "0", "--of", "0"])
        self.assertNotEqual(rc, 0)

    def test_missing_chunk_flag_exits_nonzero(self):
        rc, out, err = self._run([])
        self.assertNotEqual(rc, 0)


if __name__ == "__main__":
    unittest.main()
