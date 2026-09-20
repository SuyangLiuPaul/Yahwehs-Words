#!/usr/bin/env python3
"""Unit tests for tools/queue_open_items.py.

Run as `python3 test/test_queue_open_items.py` — CI runs the test/ files
one at a time on purpose, never `unittest discover` (most files under
test/ load gitignored, locally-staged corpora; see .github/workflows/
flutter-ci.yml:157-162 and the sibling test files' own comments for why).
This file uses only synthetic in-memory fixtures, no repo assets, so it
is safe to run unconditionally.
"""
import os
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))

import queue_open_items as qoi  # noqa: E402


def fixture(text):
    return text.splitlines(keepends=True)


class TestParse(unittest.TestCase):
    def test_depth_zero_open_item_is_open(self):
        lines = fixture(
            "## P2 — features the user asked for\n"
            "- [ ] a plain open item\n"
        )
        open_items, archived, max_depth, final_depth = qoi.parse(lines)
        self.assertEqual(len(open_items), 1)
        self.assertEqual(len(archived), 0)
        self.assertEqual(open_items[0]["line"], 2)
        self.assertEqual(final_depth, 0)

    def test_item_inside_details_is_archived(self):
        lines = fixture(
            "## P2 — features the user asked for\n"
            "<details><summary>original</summary>\n"
            "- [ ] archived item\n"
            "</details>\n"
        )
        open_items, archived, max_depth, final_depth = qoi.parse(lines)
        self.assertEqual(len(open_items), 0)
        self.assertEqual(len(archived), 1)
        self.assertEqual(archived[0]["line"], 3)
        self.assertEqual(final_depth, 0)

    def test_nested_details_still_archived_and_balances(self):
        lines = fixture(
            "## P0 — scripture accuracy\n"
            "<details><summary>outer</summary>\n"
            "- [ ] outer archived item\n"
            "<details><summary>inner</summary>\n"
            "- [ ] inner archived item\n"
            "</details>\n"
            "</details>\n"
            "- [ ] open again after both close\n"
        )
        open_items, archived, max_depth, final_depth = qoi.parse(lines)
        self.assertEqual(len(archived), 2)
        self.assertEqual(len(open_items), 1)
        self.assertEqual(max_depth, 2)
        self.assertEqual(final_depth, 0)
        self.assertEqual(open_items[0]["line"], 8)

    def test_backticked_prose_mention_does_not_change_depth(self):
        # This is the regression that matters most: a naive "line contains
        # <details>" counter would treat these two prose lines as
        # structural and hide the open item that follows them.
        lines = fixture(
            "## P3 — known but blocked or deferred\n"
            "      an entry inside `<details>` is archive, not backlog,\n"
            "      confirmed directly: the `<details>` block's original\n"
            "- [ ] a real open item that must NOT be hidden\n"
        )
        open_items, archived, max_depth, final_depth = qoi.parse(lines)
        self.assertEqual(max_depth, 0)
        self.assertEqual(final_depth, 0)
        self.assertEqual(len(open_items), 1)
        self.assertEqual(len(archived), 0)
        self.assertEqual(open_items[0]["line"], 4)

    def test_tier_attribution_across_headings(self):
        lines = fixture(
            "## BUGS — reported by the user from their own devices\n"
            "- [ ] a bug\n"
            "## P0 — scripture accuracy\n"
            "- [ ] a p0 item\n"
            "## P2 — features the user asked for\n"
            "- [ ] a p2 item\n"
        )
        open_items, archived, max_depth, final_depth = qoi.parse(lines)
        headings = {it["line"]: it["heading"] for it in open_items}
        self.assertEqual(
            headings[2], "BUGS — reported by the user from their own devices"
        )
        self.assertEqual(headings[4], "P0 — scripture accuracy")
        self.assertEqual(headings[6], "P2 — features the user asked for")

        ordered = qoi.ordered_by_tier(open_items)
        # Work order is BUGS, P2, P3, P1, P0 — not file order.
        self.assertEqual([it["line"] for it in ordered], [2, 6, 4])

    def test_unbalanced_open_tag_leaves_nonzero_final_depth(self):
        lines = fixture(
            "<details><summary>never closed</summary>\n"
            "- [ ] swallowed by the open tag\n"
        )
        open_items, archived, max_depth, final_depth = qoi.parse(lines)
        self.assertEqual(final_depth, 1)
        self.assertEqual(len(open_items), 0)
        self.assertEqual(len(archived), 1)


class TestCheck(unittest.TestCase):
    def _run_check(self, text):
        import io
        import tempfile

        with tempfile.NamedTemporaryFile(
            mode="w", suffix=".md", delete=False, encoding="utf-8"
        ) as f:
            f.write(text)
            path = f.name
        try:
            stderr = io.StringIO()
            stdout = io.StringIO()
            old_err, old_out = sys.stderr, sys.stdout
            sys.stderr, sys.stdout = stderr, stdout
            try:
                rc = qoi.main(["--check", "--path", path])
            finally:
                sys.stderr, sys.stdout = old_err, old_out
            return rc
        finally:
            os.unlink(path)

    def test_check_exits_zero_on_balanced_fixture(self):
        rc = self._run_check(
            "## P2 — features the user asked for\n"
            "<details><summary>x</summary>\n"
            "- [ ] archived\n"
            "</details>\n"
            "- [ ] open\n"
        )
        self.assertEqual(rc, 0)

    def test_check_exits_nonzero_on_unclosed_details(self):
        rc = self._run_check(
            "## P2 — features the user asked for\n"
            "<details><summary>x</summary>\n"
            "- [ ] never closed\n"
        )
        self.assertEqual(rc, 1)

    def test_check_exits_nonzero_on_stray_close_tag(self):
        rc = self._run_check(
            "## P2 — features the user asked for\n"
            "</details>\n"
            "- [ ] item\n"
        )
        self.assertEqual(rc, 1)


class TestAgainstRealQueue(unittest.TestCase):
    """Only non-drifting invariants — no pinned counts. Counts change every
    time an item is ticked; a pinned "20" here is how this queue has broken
    CI before (see docs/autonomous-queue.md's own audit-gate comments)."""

    def test_real_queue_depth_balances_and_no_open_item_is_archived(self):
        lines = qoi.load_lines()
        open_items, archived, max_depth, final_depth = qoi.parse(lines)
        self.assertEqual(final_depth, 0)
        open_line_numbers = {it["line"] for it in open_items}
        archived_line_numbers = {it["line"] for it in archived}
        self.assertEqual(open_line_numbers & archived_line_numbers, set())


if __name__ == "__main__":
    unittest.main()
