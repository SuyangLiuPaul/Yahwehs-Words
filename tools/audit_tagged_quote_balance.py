#!/usr/bin/env python3
"""Where the word-tap corpus opens a quotation and does not close it.

`assets/tagged/cuvs-yhwh/` carries 6,435 `“` against 5,840 `”`. The raw
surplus reads like 595 lost marks; almost none of it is.

THE PREMISE, because five different premises give five different numbers and
the queue entry that opened this item quoted one of them without stating it:

  * `“` and `”` ONLY. `‘`/`’` is this edition's level-2 mark and balances on
    its own books (269 verses, a separate population); `「」`/`『』` do not
    occur in the Simplified corpus at all.
  * `〔…〕` note markup stripped from the tagged line first. The corpus inlines
    a translator note where the reading asset writes `<note: …>`, and one of
    those notes carries a quotation mark of its own (西 1:23).
  * A running stack PER BOOK, verse order. Not per verse — this edition
    routinely opens a quotation in one verse and closes it in another, so a
    per-verse test measures the house style rather than a defect. Not
    corpus-wide either: a corpus-wide stack has 595 unmatched opens sitting on
    it and swallows every orphan closer that follows.

On that premise, as of 2026-09-08 (`ece056b7`), over 31,102 verses:

    2,487  verses hold more `“` than `”`
       33  of 66 books never reconcile (unclosed opens, or an orphan closer)
        4  close-before-open events — a `”` arriving with nothing open
      604  opens still on the stack at the end of their book
            (deuteronomy 115, leviticus 90, luke 83, ezekiel 70, exodus 60)

Re-run 2026-09-22: unchanged, all four figures. This block is the only part
of the script's output gated by its exit code, and it has held since
`a1406c21`.

The queue entry said 2,480. It is not reproducible at any commit: the figure
was 2,485 (35 books, 9 events) from `d03c81d2` through the parent of
`a1406c21`, and became 2,487 (33 books, 4 events) AT `a1406c21` itself, which
closed three orphan closers — the docstring this script shipped with (in that
same commit) described the state its own repair left behind incorrectly,
quoting the pre-repair figures instead. It has held at 2,487 since. The
unclosed-opens count (604) and the top-five book list never moved.

WHAT THE 2,490 VERSES ACTUALLY ARE. Take every `“` that does not close in its
own verse — 1,886 that close in a LATER verse of the same book, 604 that never
close — and ask what the FROZEN reading asset does at the same reference, as
of 2026-09-22 (`ece056b7` is stale here; see below):

    2,476  the reading asset punctuates the verse identically. This edition's
           own text, in a file this repo is not allowed to edit. Not an import
           artifact of any kind.
        9  the reading asset carries no quotation mark in that verse at all.
           The tagged corpus is a separate transcription line; there is no
           second reading to compare against, so there is nothing to repair
           towards.
        5  the reading asset punctuates the verse DIFFERENTLY. All five
           marks the `50dcc102` adoption (2026-09-09, "Adopt the
           publisher's current text") placed or moved in the reading asset
           on 2026-09-08's parent commit — checked against `50dcc102^`, the
           tagged corpus, and the independent Traditional witness `7a2dc43`
           one verse at a time, since the three don't move together here
           the way `docs/autonomous-queue.md`'s `queue:8768` item found for
           `010002023`:

             amos 9:13          reading reads `说：”日子将到` — a CLOSING
                                 mark opening the sentence, which no
                                 Chinese quotation convention produces; that
                                 much holds regardless of any witness.
                                 `50dcc102^` and the witness agree with each
                                 other (neither has a mark here at all — the
                                 tagged corpus is the one with a pre-existing
                                 mark, and normally-so, per the 9-bare class
                                 above). The tagged corpus's own EXPLAINED
                                 entry below already calls this exact `说：”`
                                 shape REPAIRED on its own side. The adoption
                                 put the same broken shape onto the reading
                                 side, where it is now reader-visible in the
                                 frozen pane. Filed as its own P0 item
                                 alongside `010002023` — see
                                 docs/autonomous-queue.md.
             deuteronomy 27:26  reading reads `阿们。’”`; `50dcc102^`, the
                                 witness and the tagged corpus all three read
                                 `阿们！’` with the outer `“` left open (this
                                 edition's own running-speech convention,
                                 the same one named at `ruth 1:17` below). A
                                 true 3-way match broken only by the
                                 adoption, which also changed `！`→`。` in the
                                 same edit — a real copy-edit, not obviously
                                 a mechanical slip, so this is filed as a
                                 disagreement for the asset's owner to rule
                                 on, not asserted as a bug. Filed alongside
                                 amos 9:13.
             matthew 17:26      reading closes `...免税了。”`; `50dcc102^`,
                                 the witness and the tagged corpus all three
                                 leave it open (`(2,1)` opens/closes on all
                                 three). A true 3-way match broken only by
                                 the adoption. Filed alongside amos 9:13.
             psalms 39:1        reading closes `...勒住我的口。”`.
                                 `50dcc102^` and the tagged corpus agree
                                 with each other (both open, unclosed,
                                 `(1,0)`) — the witness is silent here (no
                                 mark at all, `(0,0)`, the normal 9-bare
                                 pattern), so this is a 2-way match plus a
                                 non-contradicting third source, weaker
                                 evidence than deuteronomy 27:26 or matthew
                                 17:26 but still only the adoption changed
                                 it. Filed alongside amos 9:13.

           The fifth, amos 3:12, is the opposite shape and is NOT filed as a
           defect: `50dcc102` gave the reading asset both `“` and `”`,
           matching witness `7a2dc43` exactly (`…不過如此。」`), where
           `50dcc102^` had had no mark at all. The tagged corpus is the one
           behind here — it has the opener but never picked up the closer
           the publisher's edit added. Not reader-visible (the frozen pane
           is correct); a tagged-corpus repair, not swept this pass.

           詩篇 11:1, the sole "differs" verse at the 2026-09-08 pin, left
           the set for an unrelated reason: `50dcc102` moved the READING
           side onto the tagged corpus's own punctuation (closing the taunt
           at 11:1 instead of running it to 11:3), so the two lines now
           agree there and it no longer appears here. Nothing was repaired
           in the sense of either line moving to match a third source; the
           2026-09-08 disagreement simply stopped existing.

So the 2,480-verse headline is not a defect population at all, and the queue
was right to say "do not sweep it". The great majority is the frozen
edition's own house style or punctuation only the tagged corpus carries; the
five-verse residue is four verses where the 2026-09-09 adoption alone moved
the frozen reading's punctuation (filed for the owner, not swept — see
above) and one verse where the tagged corpus, not the frozen reading, is
behind.

THE TRACTABLE CUT the queue named — the close-before-open events — is real,
and it splits cleanly down the same line. Four of the nine are marks the FROZEN
reading asset carries identically, so repairing them in the corpus alone would
make the word-tap sheet disagree with the pane behind it; five were the tagged
corpus's alone and three verses carried them.

`repair_tagged_orphan_close_quote.py` applies those three. This file refuses
(exit 1) on any orphan closer that is not in EXPLAINED below, so a re-import
that brings one back is reported rather than absorbed.
"""
import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
OURS = REPO / "assets/cuvs-yhwh.json"
TAGGED = REPO / "assets/tagged/cuvs-yhwh"

OPEN, CLOSE = "“", "”"
TAGGED_NOTE = re.compile(r"〔[^〕]*〕")
OUR_NOTE = re.compile(r"<note:[^>]*>")

BOOKS = """genesis exodus leviticus numbers deuteronomy joshua judges ruth
1_samuel 2_samuel 1_kings 2_kings 1_chronicles 2_chronicles ezra nehemiah
esther job psalms proverbs ecclesiastes song_of_solomon isaiah jeremiah
lamentations ezekiel daniel hosea joel amos obadiah jonah micah nahum
habakkuk zephaniah haggai zechariah malachi matthew mark luke john acts
romans 1_corinthians 2_corinthians galatians ephesians philippians
colossians 1_thessalonians 2_thessalonians 1_timothy 2_timothy titus
philemon hebrews james 1_peter 2_peter 1_john 2_john 3_john jude
revelation""".split()

# Orphan closers this file has read one at a time. Anything else is a hit.
#
# The four kept ones are all carried IDENTICALLY by the frozen reading asset,
# which is what disqualifies them: the corpus would have to be edited away from
# the edition it is a transcription of. Blob `7a2dc43` (the plain 和合本
# Traditional) shows three of the four are genuine losses in this edition —
# they are the publisher's to fix, not ours.
EXPLAINED = {
    "exodus 3:5": (
        "`神说：不要近前来…是圣地。”` — no opener. The witness reads "
        "`神說：「不要近前來…是聖地」；`, so this edition lost the opening mark. "
        "The FROZEN reading asset reads exactly as the corpus does, so the loss "
        "is upstream of both imports. Publisher."
    ),
    "ruth 1:17": (
        "Ruth's speech closes at the end of 1:16 AND again at the end of 1:17 "
        "without reopening. The frozen reading asset and the witness both do "
        "the same. This edition's own convention for a speech that runs on."
    ),
    "ezekiel 3:9": (
        "REPAIRED — `repair_tagged_orphan_close_quote.py` restores the opener "
        "at 結 3:4. Kept here so a re-import that drops it again is reported."
    ),
    "1_samuel 23:7": (
        "REPAIRED (twice over) — `说：”` at the second speech colon was a "
        "closing mark where an opening one belongs."
    ),
    "amos 9:13": (
        "REPAIRED — the same `说：”` shape. The FROZEN reading asset carries "
        "the same shape again as of the 2026-09-09 `50dcc102` adoption "
        "(`说：”日子将到`, a closer opening the sentence) — that is a separate, "
        "reader-visible defect on the reading side, filed as its own P0 item "
        "alongside `010002023` (see docs/autonomous-queue.md), not fixed by "
        "this line's own repair."
    ),
    "amos 9:15": "REPAIRED by 9:13's substitution; the closer now has its open.",
    "mark 5:34": (
        "`耶稣对她说：‘女儿…痊愈了。”` — a level-2 opener closed by a level-1 "
        "mark. The witness reads `說：「女兒…痊癒了。」`, so the opener is the "
        "wrong mark, not the closer. Carried identically by the frozen reading "
        "asset. Publisher."
    ),
    "colossians 1:23": (
        "The note itself is mangled: `失去〔原文是“离开〕”福音的盼望` puts the "
        "opener inside the bracket and leaves the closer outside it, where it "
        "prints as scripture. The frozen reading asset carries the same split "
        "(`<note: 原文是“离开>”福音的盼望`) and the witness's note has no "
        "quotation marks at all. Publisher."
    ),
}


def load_tagged():
    out = {}
    for n, slug in enumerate(BOOKS, 1):
        book = json.loads((TAGGED / f"{slug}.json").read_text(encoding="utf-8"))
        rows = []
        for key, runs in book.items():
            chapter, verse = (int(p) for p in key.split(":"))
            rows.append(
                (
                    chapter,
                    verse,
                    key,
                    f"{n:03d}{chapter:03d}{verse:03d}",
                    "".join(r.get("w", "") for r in runs),
                )
            )
        rows.sort(key=lambda r: (r[0], r[1]))
        out[slug] = rows
    return out


def main():
    ours = {row["id"]: row["text"] for row in json.loads(
        OURS.read_text(encoding="utf-8"))}
    tagged = load_tagged()

    events = []
    unclosed = {}
    per_verse_surplus = 0
    opens_closed_later = set()
    opens_never_closed = set()

    for slug, rows in tagged.items():
        stack = []
        for _, _, key, _vid, raw in rows:
            line = TAGGED_NOTE.sub("", raw)
            if line.count(OPEN) > line.count(CLOSE):
                per_verse_surplus += 1
            for ch in line:
                if ch == OPEN:
                    stack.append(key)
                elif ch == CLOSE:
                    if stack:
                        opened = stack.pop()
                        if opened != key:
                            opens_closed_later.add((slug, opened))
                    else:
                        events.append(f"{slug} {key}")
        if stack:
            unclosed[slug] = len(stack)
            for key in stack:
                opens_never_closed.add((slug, key))

    reconciled = sum(
        1
        for slug in BOOKS
        if slug not in unclosed
        and not any(e.startswith(slug + " ") for e in events)
    )

    print(f"verses with more {OPEN} than {CLOSE} : {per_verse_surplus}")
    print(f"books that never reconcile        : {len(BOOKS) - reconciled}"
          f" of {len(BOOKS)}")
    print(f"close-before-open events          : {len(events)}")
    print(f"opens never closed in their book  : {sum(unclosed.values())}")
    top = sorted(unclosed.items(), key=lambda kv: -kv[1])[:5]
    print("    " + ", ".join(f"{slug} {n}" for slug, n in top))

    # What the frozen reading asset says about each verse that carries an open
    # it does not close.
    population = opens_closed_later | opens_never_closed
    agrees = bare = differs = 0
    different = []
    index = {slug: {r[2]: r for r in rows} for slug, rows in tagged.items()}
    for slug, key in sorted(population):
        row = index[slug][key]
        line = TAGGED_NOTE.sub("", row[4])
        theirs = OUR_NOTE.sub("", ours.get(row[3], ""))
        pair_t = (line.count(OPEN), line.count(CLOSE))
        pair_r = (theirs.count(OPEN), theirs.count(CLOSE))
        if pair_t == pair_r:
            agrees += 1
        elif pair_r == (0, 0):
            bare += 1
        else:
            differs += 1
            different.append(f"{slug} {key} tagged={pair_t} reading={pair_r}")

    print()
    print(f"verses carrying an open that closes elsewhere or never: "
          f"{len(population)}")
    print(f"    reading asset punctuates identically : {agrees}")
    print(f"    reading asset has no marks at all    : {bare}")
    print(f"    reading asset punctuates DIFFERENTLY : {differs}")
    for line in different:
        print(f"        {line}")

    print()
    unexplained = [e for e in events if e not in EXPLAINED]
    for event in sorted(set(events)):
        print(f"  {event}: {EXPLAINED.get(event, 'UNEXPLAINED')}")
    if unexplained:
        print()
        print(f"FAIL: {len(unexplained)} orphan closer(s) this file has never "
              f"read: {sorted(set(unexplained))}")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
