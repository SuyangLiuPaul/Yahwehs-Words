#!/usr/bin/env python3
"""Tests for `tools/audit_quote_bracket_style.py`'s pure detector functions.

stdlib `unittest`, synthetic fixtures only — never `assets/cuvs-yhwh.json`
or `assets/cuvs-yhwh-tr.json`, both FROZEN, and never the `7a2dc43` git
blob or the tagged corpus on disk — so this proves the LIFO scan and the
isolated/confounded split themselves, independent of whatever the two
frozen assets happen to measure on any given day. `main()` (asset I/O, the
witness blob, the pinned-set gate) is intentionally not exercised here, the
same split `test_audit_songs_snapshot_churn.py` uses for its module.
"""

import contextlib
import importlib.util
import io
import os
import unittest

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPT = os.path.join(REPO, "tools", "audit_quote_bracket_style.py")

_spec = importlib.util.spec_from_file_location("audit_quote_bracket_style", SCRIPT)
qbs = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(qbs)

PAIRS = {"「": "」", "『": "』"}


class ScanBook(unittest.TestCase):
    def test_correctly_styled_pair_is_not_reported(self):
        rows = [("001001001", "「你好」")]
        self.assertEqual(qbs.scan_book(rows, PAIRS), [])

    def test_cross_style_close_is_reported(self):
        """The queue:9248 shape itself: opens outer, closes inner."""
        rows = [("026033010", "「人子啊…消滅，怎能存活呢？』")]
        hits = qbs.scan_book(rows, PAIRS)
        self.assertEqual(len(hits), 1)
        self.assertEqual(hits[0]["open_char"], "「")
        self.assertEqual(hits[0]["close_char"], "』")
        self.assertEqual(hits[0]["expected_close"], "」")

    def test_cross_style_close_spans_multiple_verses(self):
        rows = [
            ("002012003", "『本月初十日"),
            ("002012004", "若是一家的人太少"),
            ("002012013", "這血要在你們所住的房屋上滅你們。」"),
        ]
        hits = qbs.scan_book(rows, PAIRS)
        self.assertEqual(len(hits), 1)
        self.assertEqual(hits[0]["open_key"], "002012003")
        self.assertEqual(hits[0]["close_key"], "002012013")

    def test_orphan_closer_with_nothing_open_is_not_reported(self):
        """A different, already-audited phenomenon
        (`audit_tagged_quote_balance.py`'s territory) — this file only
        reports a STYLE mismatch, never a bare unmatched closer."""
        rows = [("001001001", "沒有開口卻關了」")]
        self.assertEqual(qbs.scan_book(rows, PAIRS), [])

    def test_correct_nesting_pops_inner_before_outer(self):
        rows = [("001001001", "「外層『內層』外層結束」")]
        self.assertEqual(qbs.scan_book(rows, PAIRS), [])

    def test_unclosed_open_at_end_of_book_is_not_reported(self):
        """Matches the documented house style: 604 opens the tagged
        corpus never closes within their book. Not this file's signature —
        there is no close character at all to mismatch against."""
        rows = [("001001001", "「沒有關閉")]
        self.assertEqual(qbs.scan_book(rows, PAIRS), [])


class PerVerseMismatches(unittest.TestCase):
    def test_same_verse_pair_is_found(self):
        rows = [("026033010", "「人子啊…存活呢？』")]
        hits = qbs.per_verse_mismatches(rows, PAIRS)
        self.assertEqual(len(hits), 1)

    def test_cross_verse_pair_is_invisible_to_the_per_verse_pass(self):
        """This is the exact gap the book-scoped stack exists to close:
        resetting the stack every verse means an open in one verse and its
        (wrongly-styled) close in a later verse are each seen as a bare,
        unmatched mark — never as a pair, let alone a mismatched one."""
        rows = [
            ("002012003", "『本月初十日"),
            ("002012013", "災殃必不臨到你們身上滅你們。」"),
        ]
        self.assertEqual(qbs.per_verse_mismatches(rows, PAIRS), [])
        # ... while the book-scoped stack over the SAME rows does see it.
        self.assertEqual(len(qbs.scan_book(rows, PAIRS)), 1)


class SpanMarkTotals(unittest.TestCase):
    def test_isolated_pair_totals_to_two(self):
        by_id = {"026033010": "「人子啊…存活呢？』"}
        chars = set(PAIRS) | set(PAIRS.values())
        totals = qbs.span_mark_totals(by_id, "026033010", "026033010", chars)
        self.assertEqual(sum(totals.values()), 2)

    def test_confounded_span_totals_above_two(self):
        """An extra, unrelated bracket in the same span — e.g. a second
        inner quote whose own closer is missing — is the CONFOUNDED shape:
        the LIFO mismatch it produces describes that entanglement, not a
        clean wrong-glyph swap."""
        by_id = {
            "002008020": "「你清早起來，對他説：",
            "002008023": "明天必有這神蹟。』」",
        }
        chars = set(PAIRS) | set(PAIRS.values())
        totals = qbs.span_mark_totals(by_id, "002008020", "002008023", chars)
        self.assertGreater(sum(totals.values()), 2)


class GroupByBook(unittest.TestCase):
    def test_groups_by_the_first_three_id_digits_preserving_order(self):
        records = [
            {"id": "001001001", "text": "a"},
            {"id": "001001002", "text": "b"},
            {"id": "002001001", "text": "c"},
        ]
        books = qbs.group_by_book(records)
        self.assertEqual(set(books), {"001", "002"})
        self.assertEqual(books["001"], [("001001001", "a"), ("001001002", "b")])
        self.assertEqual(books["002"], [("002001001", "c")])


class ConfoundedClass(unittest.TestCase):
    """`CONFOUNDED_CLASS` is the classification `queue:9314` asked for —
    verified against synthetic fixtures here; verified against the real
    28/9/19 split (via `main()`'s own exit-code gate) only when the frozen
    assets are read, which this module deliberately does not do."""

    VALID_CATEGORIES = {
        "MISSING_INNER_OPENER",
        "MISSING_INNER_CLOSER",
        "EXTRA_INNER_OPENER",
        "UNPLACED",
    }

    def test_has_exactly_19_entries(self):
        self.assertEqual(len(qbs.CONFOUNDED_CLASS), 19)

    def test_every_category_is_one_of_the_four_named_buckets(self):
        self.assertTrue(set(qbs.CONFOUNDED_CLASS.values()) <= self.VALID_CATEGORIES)

    def test_every_key_is_a_span_id_shape(self):
        for span_id in qbs.CONFOUNDED_CLASS:
            open_key, close_key = span_id.split("-")
            self.assertEqual(len(open_key), 9)
            self.assertEqual(len(close_key), 9)
            self.assertLessEqual(open_key, close_key)


class PrintConfounded(unittest.TestCase):
    """`print_confounded` is the `--show-confounded` dump the acceptance
    criteria asked for: every verse in the span (not just the open/close
    endpoints), classified, for all three sources."""

    def test_prints_every_verse_in_the_span_and_the_category(self):
        by_id = {
            "002008020": "「你清早起來，對他説：",
            "002008021": "（中間一節，沒有標記）",
            "002008023": "明天必有這神蹟。』」",
        }
        tagged = {"002008020": "TAGGED-020", "002008023": "TAGGED-023"}
        witness = {"002008020": "WITNESS-020", "002008023": "WITNESS-023"}
        confounded = [
            {
                "open_key": "002008020",
                "close_key": "002008023",
                "open_char": "「",
                "close_char": "』",
                "expected_close": "」",
                "span_id": "002008020-002008023",
                "totals": {"「": 1, "」": 1, "『": 0, "』": 1},
            }
        ]

        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            qbs.print_confounded(confounded, by_id, tagged, witness)
        out = buf.getvalue()

        self.assertIn("002008020-002008023 [MISSING_INNER_OPENER]", out)
        # The middle verse (021) has no tagged/witness entry but must still
        # appear — the whole point of a span dump, not just the endpoints.
        self.assertIn("中間一節", out)
        self.assertIn("TAGGED-020", out)
        self.assertIn("WITNESS-023", out)

    def test_unclassified_span_is_labelled_rather_than_failing(self):
        by_id = {"099099099": "x"}
        confounded = [
            {
                "open_key": "099099099",
                "close_key": "099099099",
                "open_char": "「",
                "close_char": "』",
                "expected_close": "」",
                "span_id": "099099099-099099099",
                "totals": {},
            }
        ]
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            qbs.print_confounded(confounded, by_id, {}, {})
        self.assertIn("[UNCLASSIFIED]", buf.getvalue())


if __name__ == "__main__":
    unittest.main()
