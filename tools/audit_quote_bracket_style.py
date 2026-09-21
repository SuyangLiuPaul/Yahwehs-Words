#!/usr/bin/env python3
"""Where a quotation opens with one bracket style and closes with the other.

`docs/autonomous-queue.md`'s `queue:9248` filed one verse, 結 33:10, whose
Traditional text opens `「` (outer) and closes `』` (the INNER closer)
instead of `」`. It asked for a wider scan of both frozen reading assets —
`assets/cuvs-yhwh.json` (`“”`/`‘’`) and `assets/cuvs-yhwh-tr.json`
(`「」`/`『』`) — for the same cross-style pattern, to answer "one verse or a
class?" before anyone decides what, if anything, to do about it. This file
answers that question. It never writes an asset; both are FROZEN (publisher
declined corrections, 2026-09-02).

THE PREMISE, because `tools/audit_tagged_quote_balance.py` already found that
five different premises give five different numbers for this corpus:

  * A running bracket STACK per book, verse order — not per verse. This
    edition routinely opens a quotation in one verse and does not close it
    until a later one (`audit_tagged_quote_balance.py` catalogued 604 such
    opens in the tagged corpus alone), so a per-verse-only check can only
    ever see same-verse pairs and silently misses every cross-verse one.
    That is exactly what happened at the planning stage for this item: a
    per-verse model found 4 hits. The book-scoped stack below finds 28 raw
    LIFO mismatches for the SAME 28 ids in both files (`assets/cuvs-yhwh.json`
    and `assets/cuvs-yhwh-tr.json` are positionally identical — one is a
    mechanical `“”/‘’` ⟷ `「」/『』` re-encoding of the other, verified by
    the exact bracket counts matching 1:1 across every one of the four
    marks) — a class six times the planning estimate, not four.
  * Of those 28, only some are a clean "one open, one close, wrong style"
    event with NOTHING else unresolved in the verse span between them. The
    rest carry an extra, unrelated bracket in the same span (usually a
    second inner quote whose own opener or closer is missing) — the LIFO
    stack pairs the outer/inner marks it has left over AFTER that, and the
    resulting "mismatch" describes the entanglement, not a wrong glyph.
    Splitting on "exactly 2 bracket characters total inside the span" keeps
    the 9 SINGLE-CAUSE events separate from the 19 CONFOUNDED ones (both
    counts re-verified 2026-09-22 against `ece056b7`):

        028 raw book-scoped LIFO mismatches (14 books, same 28 ids in both
            `assets/cuvs-yhwh.json` and `assets/cuvs-yhwh-tr.json`)
         09 of those are ISOLATED: exactly one open + one close bracket
            character in the whole verse span, no other mark to entangle
            with — the shape `queue:9248` actually described
         19 of those are CONFOUNDED: a second, unrelated bracket sits
            somewhere in the same span; the LIFO "mismatch" is a symptom of
            THAT, not a same-shape sibling of `queue:9248`. Left unclassified
            here — untangling which bracket is actually missing or
            miskeyed needs the same verse-by-verse reading this file's
            sibling `audit_speaker_attribution.py` used for its own 141-id
            backlog, and is out of scope for a scan whose job was "how big
            is the class", not "read all 19".
         04 of the 9 isolated hits are same-verse (what the per-verse model
            already found); the other 5 span 2-11 verses and only the
            book-scoped stack sees them.

  * `<note:...>` spans are NOT stripped before scanning. Unlike
    `audit_tagged_quote_balance.py`'s `“`/`”` balance (where a translator
    note is known to carry a stray mark, 西 1:23), no isolated hit here
    falls inside a note — checked by hand, not assumed — so stripping would
    not have changed the isolated set and this file does not carry the
    complexity for no measured benefit.

WHAT THE 9 ISOLATED HITS ARE, checked against the tagged word-tap corpus
(`assets/tagged/cuvs-yhwh{,-tr}/`) and the independent Traditional witness
(git blob `7a2dc43`, the plain 和合本 Traditional):

  * All 9: the tagged corpus carries the IDENTICAL bracket-style pattern at
    both the open and close verse, checked for every one of the 9, not
    sampled. Two independent transcriptions of this edition agree, so this
    is not an import-side artifact of either line — it is (at minimum) this
    edition's own text, matching how `audit_tagged_quote_balance.py`
    classifies same-shaped reading/tagged agreement elsewhere.
  * The witness disagrees with our structure at every one of the 9, but not
    uniformly: sometimes it has no mark at all where we open (結 15:26 opens
    bare, no 『), sometimes it closes the inner quote within the SAME verse
    where we run it on for several more (結 33:26 closes `。』` at once,
    ours runs to 結 33:28), and at **結 33:10 itself — the verse this item
    was filed FOR** — the witness has an inner `『` before 我們的過犯罪惡
    that ours and the tagged corpus both lack entirely. That means 結
    33:10's real shape, per the witness, is a MISSING inner opener with an
    outer `「` that (per this edition's own cross-verse convention) simply
    stays open — not a `「`-opened-`』`-closed swap at all. The two read
    identically as bracket characters (one `「`, one `』`, nothing else in
    the verse) but they are different underlying defects, and nothing
    mechanical here can tell them apart for the other 8 either. **This is
    why the isolated bucket cannot be asserted as "8 more of the same
    defect `queue:9248` named" — it can only be asserted as "8 more
    verses/spans with the same LIFO signature", which is a narrower, true
    claim.** Disambiguating needs the owner's edition or an editorial call
    neither import is positioned to make, exactly the position
    `queue:8768`/`queue:9217` were already left in for the same reason.

EXIT CODE: gated on the ISOLATED set only (the 19 confounded ones are
informational, not gated — untangling them is not this file's job). Exits 1
if the isolated id set drifts from the 9 pinned in `PINNED_ISOLATED` below
(grown, shrunk, or different members) — the frozen assets are not expected
to change, so any drift means either a re-import or a bug in this file, and
either way the next run should say so rather than silently re-measuring a
different number. Exits 0 if the isolated set matches exactly. Never writes
`assets/cuvs-yhwh.json` or `assets/cuvs-yhwh-tr.json`.
"""
import json
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent

EDITIONS = (
    ("assets/cuvs-yhwh-tr.json", "assets/tagged/cuvs-yhwh-tr", {"「": "」", "『": "』"}),
    ("assets/cuvs-yhwh.json", "assets/tagged/cuvs-yhwh", {"“": "”", "‘": "’"}),
)

WITNESS_BLOB = "7a2dc43"

BOOKS = """genesis exodus leviticus numbers deuteronomy joshua judges ruth
1_samuel 2_samuel 1_kings 2_kings 1_chronicles 2_chronicles ezra nehemiah
esther job psalms proverbs ecclesiastes song_of_solomon isaiah jeremiah
lamentations ezekiel daniel hosea joel amos obadiah jonah micah nahum
habakkuk zephaniah haggai zechariah malachi matthew mark luke john acts
romans 1_corinthians 2_corinthians galatians ephesians philippians
colossians 1_thessalonians 2_thessalonians 1_timothy 2_timothy titus
philemon hebrews james 1_peter 2_peter 1_john 2_john 3_john jude
revelation""".split()

# The isolated set as of 2026-09-22 (`ece056b7`), both files, same ids.
# Re-verify before trusting: see the module docstring for why this is a
# narrower claim than "the queue:9248 defect, 9 times over".
PINNED_ISOLATED = frozenset(
    [
        "002012003-002012013",
        "006007013-006007015",
        "010015026-010015026",
        "013022008-013022016",
        "024007023-024007028",
        "024015003-024015004",
        "026003027-026003027",
        "026033010-026033010",
        "041005034-041005034",
    ]
)


def scan_book(rows, pairs):
    """Book-scoped LIFO bracket scan, the primary detector.

    `rows`: `[(verse_key, text), ...]` in reading order for ONE book.
    `pairs`: `{open_char: expected_close_char, ...}`.

    Returns a mismatch dict per event where a close character arrives and
    does not match the style of the innermost still-open bracket. An orphan
    closer (nothing open at all) is a different, already-audited phenomenon
    (`audit_tagged_quote_balance.py`'s territory) and is not reported here.
    """
    opens = set(pairs)
    closes = set(pairs.values())
    stack = []
    mismatches = []
    for key, text in rows:
        for ch in text:
            if ch in opens:
                stack.append((ch, key))
            elif ch in closes:
                if not stack:
                    continue
                open_ch, open_key = stack.pop()
                expected = pairs[open_ch]
                if ch != expected:
                    mismatches.append(
                        {
                            "open_key": open_key,
                            "open_char": open_ch,
                            "close_key": key,
                            "close_char": ch,
                            "expected_close": expected,
                        }
                    )
    return mismatches


def per_verse_mismatches(rows, pairs):
    """The cross-check: the same detector, stack reset every verse.

    Only ever sees a mismatch when the open and close are IN THE SAME
    verse — it cannot see a pair the book-scoped stack finds across a
    verse boundary. The difference between the two is itself the finding
    that answers whether cross-verse spans matter here.
    """
    out = []
    for key, text in rows:
        out.extend(scan_book([(key, text)], pairs))
    return out


def span_mark_totals(rows_by_id, open_key, close_key, chars):
    """Total count of each bracket char across the verse span [open_key,
    close_key] inclusive. Used to split ISOLATED (exactly one open + one
    close character total, nothing else to entangle with) from CONFOUNDED
    (a second, unrelated bracket sits in the same span)."""
    ids_sorted = sorted(rows_by_id)
    span = [i for i in ids_sorted if open_key <= i <= close_key]
    text = "".join(rows_by_id[i] for i in span)
    return {ch: text.count(ch) for ch in chars}


def group_by_book(records):
    """Records are already sorted by id (verified); group by the book
    number encoded in the first 3 digits, preserving order."""
    books = {}
    for r in records:
        books.setdefault(r["id"][:3], []).append((r["id"], r["text"]))
    return books


def load_tagged(dirpath):
    idx = {}
    for n, slug in enumerate(BOOKS, 1):
        path = REPO / dirpath / f"{slug}.json"
        if not path.exists():
            continue
        book = json.loads(path.read_text(encoding="utf-8"))
        for key, runs in book.items():
            ch, vs = (int(x) for x in key.split(":"))
            vid = f"{n:03d}{ch:03d}{vs:03d}"
            idx[vid] = "".join(r.get("w", "") for r in runs)
    return idx


def load_witness():
    result = subprocess.run(
        ["git", "-C", str(REPO), "cat-file", "-p", WITNESS_BLOB],
        capture_output=True,
        text=True,
    )
    if not result.stdout.strip():
        return {}
    return {v["id"]: v["text"] for v in json.loads(result.stdout)}


def main():
    tagged_by_edition = {}
    isolated_by_edition = {}
    confounded_by_edition = {}
    per_verse_by_edition = {}

    for asset, tagged_dir, pairs in EDITIONS:
        records = json.loads((REPO / asset).read_text(encoding="utf-8"))
        ids = [r["id"] for r in records]
        assert ids == sorted(ids), f"{asset}: not id-sorted, group_by_book needs order"
        by_id = {r["id"]: r["text"] for r in records}
        books = group_by_book(records)

        book_hits = []
        verse_hits = []
        for rows in books.values():
            book_hits.extend(scan_book(rows, pairs))
            verse_hits.extend(per_verse_mismatches(rows, pairs))

        chars = set(pairs) | set(pairs.values())
        isolated, confounded = [], []
        for m in book_hits:
            totals = span_mark_totals(by_id, m["open_key"], m["close_key"], chars)
            span_id = f"{m['open_key']}-{m['close_key']}"
            entry = dict(m, span_id=span_id, totals=totals)
            if sum(totals.values()) == 2:
                isolated.append(entry)
            else:
                confounded.append(entry)

        tagged_by_edition[asset] = load_tagged(tagged_dir)
        isolated_by_edition[asset] = isolated
        confounded_by_edition[asset] = confounded
        per_verse_by_edition[asset] = {
            f"{m['open_key']}-{m['close_key']}" for m in verse_hits
        }

        print(f"=== {asset} ===")
        print(f"  book-scoped raw mismatches : {len(book_hits)}")
        print(f"  isolated (single pair)     : {len(isolated)}")
        print(f"  confounded (other marks in span): {len(confounded)}")
        print(f"  per-verse-only mismatches  : {len(verse_hits)}")
        print()

    tr_asset, simple_asset = EDITIONS[0][0], EDITIONS[1][0]
    tr_ids = {e["span_id"] for e in isolated_by_edition[tr_asset]}
    simple_ids = {e["span_id"] for e in isolated_by_edition[simple_asset]}
    print(f"isolated span ids match between both editions: {tr_ids == simple_ids}")
    if tr_ids != simple_ids:
        print(f"  only in {tr_asset}: {sorted(tr_ids - simple_ids)}")
        print(f"  only in {simple_asset}: {sorted(simple_ids - tr_ids)}")
    print()

    witness = load_witness()
    tagged_tr = tagged_by_edition[tr_asset]
    reading_tr = {
        r["id"]: r["text"]
        for r in json.loads((REPO / tr_asset).read_text(encoding="utf-8"))
    }
    print("=== isolated hits (Traditional), classified ===")
    for e in sorted(isolated_by_edition[tr_asset], key=lambda x: x["span_id"]):
        ok, ck = e["open_key"], e["close_key"]
        print(f"  {e['span_id']}: opens {e['open_char']!r} closes {e['close_char']!r}"
              f" (expected {e['expected_close']!r})")
        print(f"    ours   @{ok}: {reading_tr.get(ok, '')}")
        if ck != ok:
            print(f"    ours   @{ck}: {reading_tr.get(ck, '')}")
        print(f"    tagged @{ok}: {tagged_tr.get(ok, '???')}")
        if ck != ok:
            print(f"    tagged @{ck}: {tagged_tr.get(ck, '???')}")
        if witness:
            print(f"    witness@{ok}: {witness.get(ok, '???')}")
            if ck != ok:
                print(f"    witness@{ck}: {witness.get(ck, '???')}")
    print()

    verse_only = per_verse_by_edition[tr_asset]
    book_only_ids = tr_ids - verse_only
    print(f"isolated hits ALSO found by the per-verse cross-check: "
          f"{len(tr_ids & verse_only)} of {len(tr_ids)}")
    print(f"isolated hits ONLY the book-scoped stack sees (cross-verse span): "
          f"{sorted(book_only_ids)}")
    print()

    if tr_ids != PINNED_ISOLATED:
        print(
            f"FAIL: isolated set drifted from the {len(PINNED_ISOLATED)} pinned in "
            f"PINNED_ISOLATED. Now: {sorted(tr_ids)}"
        )
        return 1
    print(f"isolated set matches the {len(PINNED_ISOLATED)} pinned ids. OK.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
