#!/usr/bin/env python3
"""Sort 梁家鏗譯本 v2's bucket-(c) `blockNotes` ids into a verdict.

Background
----------
`docs/autonomous-queue.md` (2026-09-28) banked a sweep of every v2 verse
where `blockNotes` count disagrees between the Simplified (`biblexg-v2.json`)
and Traditional (`biblexg-v2-tr.json`) assets — 53 verses out of 7,924
common ids. Each was sorted into:

  (a) re-split within one verse — same content, different note boundaries
  (b) re-attached across verses — same content, a different anchor verse
  (c) content present in one edition, absent from the other — genuinely

12 rows (13 ids — 罗3:20/26 is one adjacent pair sharing a leftover gap)
landed in bucket (c); this script's own growth check (below) found a
14th, 45012008 (罗12:8), that the hand sweep missed. That sweep could
not say WHY a bucket-(c) gap exists at all: a bucket-(c) gap can
be "the publisher's own tw-*.json and cn-*.json pages already disagreed
here" (not ours to fix) or "our ingest dropped something the source page
had" (ours to fix, after `git log -S` confirms no deliberate repair did
it). Telling those apart needs the publisher's own source, which this
script reads — the same caches `tools/audit_biblexg_notes.py` and
`tools/audit_biblexg_v2_vs_tr.py` already populate at
`~/.cache/yswords/ljk-source` (`~/.cache/yswords/ljk-source-v3` for v3).

Restricted to v2 on purpose: per `audit_biblexg_v2_vs_tr.py`'s docstring
and commit `c6461080`, v3's assets carry footnotes adopted from the
translator's newer site while `SOURCE_DIRS` still points at the older,
thinner mattwhatsup snapshot, so a v3-vs-source comparison is not
like-for-like. v3's one count difference on this set (45010013 has an
extra SC note in v3 that v2 lacks) is noted in the queue, not chased here.

Method
------
Per pinned id-group, diff the group's own SC vs TR `blockNotes` text
(t2s-normalised) to isolate the extra chunk(s) one edition carries that
the other lacks (the same content already identified by hand in the
queue table). For each chunk, check whether it also appears in the
publisher's OWN page for the edition that lacks it:

  * found there too  -> our ingest dropped something the source had
                         (`our-ingest-dropped-it`)
  * absent there too  -> the publisher's own tw/cn pages already
                         disagreed (`publisher-disagreement`)
  * neither/ambiguous -> `inconclusive` (a fine answer; a guess is not)

Growth guard
------------
Before classifying, this script re-derives which v2 ids have a
blockNotes count mismatch at all, explains away everything foldable
into bucket (a) (whole-note-group text matches after t2s, ratio-based)
or bucket (b) (the extra content is found verbatim/near-verbatim
somewhere else in the same book, or failing that the same file, in the
other edition — i.e. reattached, not missing), and fails (exit 1) if
anything is left over that is not already in PENDING_CLASSIFICATION.
That is deliberately named PENDING_CLASSIFICATION, not ACCOUNTED_FOR:
being on the list means "known and tracked", not "cleared" — each
group still gets its own verdict below, and "inconclusive" does not
silently bless anything.

Read-only. Never writes to assets/. Exits 0 without doing anything if
`opencc` or the v2 source cache is unavailable — both are true on CI,
and this script must never be the reason `main` goes red for a missing
untracked directory.

Usage:  python3 tools/audit_biblexg_blocknote_parity.py
"""

import argparse
import difflib
import json
import os
import re
import shutil
import sys

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(REPO_ROOT, 'tools'))
from audit_biblexg_notes import BOOKS, EDITIONS  # noqa: E402
from audit_biblexg_v2_vs_tr import find_source_dir, t2s  # noqa: E402

TAG = re.compile(r'<[^>]+>')
WS = re.compile(r'\s+')

MIN_CHUNK = 20     # ignore diff opcodes shorter than this many characters —
                    # below this, a sentence relocated WITHIN one note
                    # (路9:17's "有别于旧译祝福" moves from the front of the
                    # sentence to the back between editions, same content)
                    # shows up as small same-length insert+delete pairs
                    # that are reordering noise, not missing content
FOLD_RATIO = 0.92  # same threshold the banked sweep used throughout
SUBSTR_RATIO = 0.85  # for near-verbatim (not exact) containment checks
BOOK_NUM_BASE = 40   # BOOKS[0] ('mt') is USFM/id book number 40 (Matthew)

# The 13 ids (12 rows) this hour's banked sweep found in bucket (c) for
# v2 — see docs/autonomous-queue.md, the "blockNotes has no SC-vs-TR
# parity guard" item, 2026-09-28 — plus one this script's own growth
# check (below) found that the hand sweep missed: 45012008 (罗12:8),
# where SC carries an unlabelled third note (on κατὰ τὴν ἀναλογίαν τῆς
# πίστεως) that TR lacks. Confirmed against the publisher source before
# adding it here, not just from the count mismatch: `cn-rom.json`
# chapter 12 has 3 comment nodes, `tw-rom.json` chapter 12 has 2 — the
# same "our ingest matches its own source, the sources disagree with
# each other" shape as the other 13, verified independently rather than
# assumed from the pattern.
PENDING_CLASSIFICATION = [
    (('41001027',), '可1:27'),
    (('41005001',), '可5:1'),
    (('42001055',), '路1:55'),
    (('42009017',), '路9:17'),
    (('42012021',), '路12:21'),
    (('45003020', '45003026'), '罗3:20,26'),
    (('45010013',), '罗10:13'),
    (('45012008',), '罗12:8'),
    (('46013003',), '林前13:3'),
    (('47005010',), '林后5:10'),
    (('52003005',), '腓3:5'),
    (('62003010',), '约一3:10'),
    (('66008012',), '启8:12'),
]
PENDING_IDS = {vid for group, _ in PENDING_CLASSIFICATION for vid in group}


def norm(text: str) -> str:
    return WS.sub(' ', text).strip()


def ratio(a: str, b: str) -> float:
    return difflib.SequenceMatcher(None, a, b, autojunk=False).ratio()


def load_our_notes(asset_path: str) -> dict:
    """id -> list[str] of blockNotes, whitespace-normalised, in order."""
    with open(os.path.join(REPO_ROOT, asset_path), encoding='utf-8') as f:
        rows = json.load(f)
    return {row['id']: [norm(n) for n in (row.get('blockNotes') or [])]
            for row in rows}


def load_publisher_comments(cache_dir: str, lang: str, abbr: str) -> dict:
    """{chapter_str: [comment_text, ...]} for one publisher book file.

    t2s-normalised so tw (Traditional) and cn (already Simplified)
    compare on equal footing — t2s of already-Simplified text is a
    no-op in practice, never a hand-rolled per-character map.
    """
    path = os.path.join(cache_dir, f'{lang}-{abbr}.json')
    with open(path, encoding='utf-8') as f:
        chapters = json.load(f)
    out: dict = {}
    for chap in chapters:
        chapter = None
        texts = []
        for node in chap.get('nodeData', []):
            if node.get('type') == 'chapter':
                chapter = str(node['chapterIndex'])
            elif node.get('type') == 'comment':
                raw = ''.join(
                    c if isinstance(c, str) else c.get('content', '')
                    for c in node.get('contents', []))
                texts.append(norm(t2s(TAG.sub('', raw))))
        if chapter is not None:
            out[chapter] = texts
    return out


LABEL = re.compile(r'^[“"]?(\d+(?:[-－]\d+)?)\s*[节節][注註]')


def label_of(note: str):
    m = LABEL.match(note)
    return m.group(1) if m else None


def same_chapter_has_label(notes_by_id: dict, vid: str, label: str) -> bool:
    """Does some OTHER verse in vid's own chapter carry a note whose
    leading "N节注:" label matches? If so, both editions are commenting
    on the identical verse-internal point (e.g. 可12:36's "36节注"
    appears attached to both id .036 and id .037 depending on edition) —
    a heavy editorial rewrite of the SAME annotated point, not content
    that is actually missing from one side. Scoped to the chapter (not
    the whole book) because note labels restart every chapter and a
    book-wide match on a bare number would pair up unrelated verses.
    """
    chapter_prefix = vid[:5]
    for other_id, notes in notes_by_id.items():
        if other_id == vid or other_id[:5] != chapter_prefix:
            continue
        if any(label_of(n) == label for n in notes):
            return True
    return False


def book_abbr_and_chapter(vid: str):
    book_num = int(vid[:2])
    chapter = str(int(vid[2:5]))
    abbr = BOOKS[book_num - BOOK_NUM_BASE][0]
    return abbr, chapter


def extra_chunks(a_text: str, b_text: str) -> list:
    """Substrings of b_text (length >= MIN_CHUNK) that a_text does not
    have, per difflib's opcodes. Call twice with arguments swapped to
    get both directions' extra content."""
    sm = difflib.SequenceMatcher(None, a_text, b_text, autojunk=False)
    chunks = []
    for tag, _i1, _i2, j1, j2 in sm.get_opcodes():
        if tag in ('insert', 'replace'):
            chunk = b_text[j1:j2].strip()
            if len(chunk) >= MIN_CHUNK:
                chunks.append(chunk)
    return chunks


def find_in_notes(chunk: str, notes: list, max_window: int = 3) -> bool:
    """Is chunk (near-)present as one note, or a short run of adjacent
    notes, somewhere in `notes`?

    Deliberately NOT a substring search over one big joined blob: this
    corpus's notes share a lot of boilerplate phrasing (e.g. "指以色列
    的神 יהוה") that recurs across many unrelated verses, so anchoring on
    "the largest matching run anywhere in the blob" latches onto a
    coincidental match elsewhere rather than the real counterpart, and a
    single wording choice inside the real match (this corpus's TR
    consistently writes 藉著 where SC writes 借着 for the same word —
    opencc's t2s leaves both alone, since 藉 and 著 are each valid
    Simplified characters on their own; verified with
    `echo 藉著 | opencc -c t2s` before relying on it) can split an exact
    match into pieces smaller than that coincidence. Comparing whole
    notes (or short adjacent runs, to catch a note re-split across two)
    with a full similarity ratio is discriminating enough for every
    case this corpus actually has today (see the 14 verdicts this
    script prints — each independently spot-checked against the raw
    publisher cache, not just this function's own say-so).

    Known remaining gap, found by an adversarial review before this
    landed rather than by this corpus tripping over it: two notes that
    are BOTH built from one of the translator's recurring templates
    (e.g. the standard πνεῦμα ἀκάθαρτον gloss) can clear SUBSTR_RATIO
    against each other even when they annotate different verses — one
    such pair (41005001's TR note against an unrelated SC note at
    41007030) scored 0.879, above the 0.85 threshold, purely on shared
    boilerplate. It did not change any verdict this run (41005001 is
    already pinned regardless of which bucket explains it), but a
    future short, templated, genuinely-missing note could in principle
    be waved through `check_growth` as "reattached" by this mechanism
    before ever reaching a human. Not fixed here — flagged so the next
    person tightening this knows why 0.85 was not raised on a hunch.
    """
    if not chunk or not notes:
        return False
    for size in range(1, max_window + 1):
        for i in range(len(notes) - size + 1):
            candidate = norm(' '.join(notes[i:i + size]))
            if not candidate:
                continue
            if chunk == candidate or chunk in candidate or candidate in chunk:
                return True
            if ratio(chunk, candidate) >= SUBSTR_RATIO:
                return True
    return False


def _book_indexes(sc_notes: dict, tr_notes: dict, common_ids: list):
    """Book-scoped note pools used by both the growth guard and the
    pending-set diagnostic, so the two never compute this differently."""
    sc_by_book: dict = {}
    tr_by_book: dict = {}
    for vid in common_ids:
        sc_by_book.setdefault(vid[:2], []).extend(sc_notes[vid])
        tr_by_book.setdefault(vid[:2], []).extend(
            [t2s(n) for n in tr_notes[vid]])
    sc_all = [n for notes in sc_by_book.values() for n in notes]
    tr_all = [n for notes in tr_by_book.values() for n in notes]
    return sc_by_book, tr_by_book, sc_all, tr_all


def _genuinely_missing_chunks(vid, sc_notes, tr_notes,
                               sc_by_book, tr_by_book, sc_all, tr_all):
    """Bucket-(a)/(b)-fold a single id's mismatch; return the chunks left
    over (empty if fully explained by (a) or (b)). Shared by check_growth
    (which gates on PENDING_IDS) and pending_id_status (which does not,
    since it exists precisely to inspect what PENDING_IDS hides)."""
    sc_text = norm(' '.join(sc_notes[vid]))
    tr_text = norm(' '.join(t2s(n) for n in tr_notes[vid]))
    if ratio(sc_text, tr_text) >= FOLD_RATIO:
        return []  # bucket (a) — re-split within one verse

    sc_book = sc_by_book.get(vid[:2], [])
    tr_book = tr_by_book.get(vid[:2], [])

    genuinely_missing = []
    for chunk in extra_chunks(tr_text, sc_text):   # SC extra vs TR
        if find_in_notes(chunk, tr_book) or find_in_notes(chunk, tr_all):
            continue  # bucket (b) — reattached elsewhere
        label = label_of(chunk)
        if label and same_chapter_has_label(tr_notes, vid, label):
            continue  # same annotated point, heavily reworded — not missing
        genuinely_missing.append(('sc_extra', chunk))
    for chunk in extra_chunks(sc_text, tr_text):   # TR extra vs SC
        if find_in_notes(chunk, sc_book) or find_in_notes(chunk, sc_all):
            continue
        label = label_of(chunk)
        if label and same_chapter_has_label(sc_notes, vid, label):
            continue
        genuinely_missing.append(('tr_extra', chunk))
    return genuinely_missing


def check_growth(sc_notes: dict, tr_notes: dict, edition: str = 'v2') -> list:
    """Return ids with a blockNotes mismatch not explained by bucket (a)
    or (b) and not already in PENDING_IDS — i.e. new bucket-(c) growth.
    """
    common_ids = sorted(set(sc_notes) & set(tr_notes))
    mismatches = [vid for vid in common_ids
                  if len(sc_notes[vid]) != len(tr_notes[vid])]
    print(f'{len(common_ids)} common ids ({edition}), {len(mismatches)} with '
          'a blockNotes count mismatch.')

    sc_by_book, tr_by_book, sc_all, tr_all = _book_indexes(
        sc_notes, tr_notes, common_ids)

    unexplained = []
    for vid in mismatches:
        genuinely_missing = _genuinely_missing_chunks(
            vid, sc_notes, tr_notes, sc_by_book, tr_by_book, sc_all, tr_all)
        if genuinely_missing and vid not in PENDING_IDS:
            unexplained.append((vid, genuinely_missing))

    return unexplained


def pending_id_status(sc_notes: dict, tr_notes: dict) -> list:
    """Diagnostic only, never gates exit status: for each id pinned in
    PENDING_CLASSIFICATION (a v2 finding), report whether THIS edition's
    sc_notes/tr_notes still show a count mismatch on it, and if so
    whether that mismatch survives bucket (a)/(b) folding here too —
    i.e. whether the id would independently land in bucket (c) for this
    edition, not just because v2 said so. Lets the growth guard's
    PENDING_IDS exclusion (necessary so v2's own known set doesn't
    trip check_growth) be cross-checked against a second edition
    instead of taken on faith.
    """
    common_ids = sorted(set(sc_notes) & set(tr_notes))
    sc_by_book, tr_by_book, sc_all, tr_all = _book_indexes(
        sc_notes, tr_notes, common_ids)

    rows = []
    for group, ref in PENDING_CLASSIFICATION:
        for vid in group:
            if vid not in sc_notes or vid not in tr_notes:
                rows.append((vid, ref, 'missing-id', None, None))
                continue
            sc_n, tr_n = len(sc_notes[vid]), len(tr_notes[vid])
            if sc_n == tr_n:
                rows.append((vid, ref, 'no-mismatch', sc_n, tr_n))
                continue
            missing = _genuinely_missing_chunks(
                vid, sc_notes, tr_notes, sc_by_book, tr_by_book,
                sc_all, tr_all)
            status = 'survives-bucket-c' if missing else 'folded-a-or-b'
            rows.append((vid, ref, status, sc_n, tr_n))
    return rows


def classify(sc_notes: dict, tr_notes: dict, src_dir: str) -> None:
    publisher_cache: dict = {}

    def publisher(lang: str, abbr: str) -> dict:
        key = (lang, abbr)
        if key not in publisher_cache:
            publisher_cache[key] = load_publisher_comments(src_dir, lang, abbr)
        return publisher_cache[key]

    print('== Publisher-source verdicts for the pinned bucket-(c) set ==\n')
    for group, ref in PENDING_CLASSIFICATION:
        abbr, chapter = book_abbr_and_chapter(group[0])
        sc_text = norm(' '.join(n for vid in group for n in sc_notes[vid]))
        tr_text = norm(' '.join(
            t2s(n) for vid in group for n in tr_notes[vid]))

        try:
            pub_cn = publisher('cn', abbr)
            pub_tw = publisher('tw', abbr)
        except FileNotFoundError:
            print(f'-- {ref} ({group}): publisher source missing for '
                  f'{abbr!r} — inconclusive\n')
            continue
        pub_cn_list = pub_cn.get(chapter, [])
        pub_tw_list = pub_tw.get(chapter, [])

        print(f'-- {ref}  (ids: {", ".join(group)}, chapter {chapter})')
        print(f'   our SC: {sc_text!r}')
        print(f'   our TR: {tr_text!r}')
        print(f'   publisher cn ch.{chapter}: {pub_cn_list!r}')
        print(f'   publisher tw ch.{chapter}: {pub_tw_list!r}')

        verdicts = []
        for chunk in extra_chunks(tr_text, sc_text):   # SC carries, TR lacks
            own_source_has_it = find_in_notes(chunk, pub_cn_list)
            other_source_has_it = find_in_notes(chunk, pub_tw_list)
            if not own_source_has_it:
                verdicts.append(('inconclusive', chunk,
                                  'not even in our own cn source — anomaly'))
            elif other_source_has_it:
                verdicts.append(('our-ingest-dropped-it', chunk,
                                  "publisher's own tw page has this too — "
                                  "TR's ingest dropped it"))
            else:
                verdicts.append(('publisher-disagreement', chunk,
                                  "publisher's own tw page lacks this — "
                                  'their tw/cn sources already disagree'))
        for chunk in extra_chunks(sc_text, tr_text):   # TR carries, SC lacks
            own_source_has_it = find_in_notes(chunk, pub_tw_list)
            other_source_has_it = find_in_notes(chunk, pub_cn_list)
            if not own_source_has_it:
                verdicts.append(('inconclusive', chunk,
                                  'not even in our own tw source — anomaly'))
            elif other_source_has_it:
                verdicts.append(('our-ingest-dropped-it', chunk,
                                  "publisher's own cn page has this too — "
                                  "SC's ingest dropped it"))
            else:
                verdicts.append(('publisher-disagreement', chunk,
                                  "publisher's own cn page lacks this — "
                                  'their tw/cn sources already disagree'))

        if not verdicts:
            overall = 'inconclusive'
            print('   (no chunk >= MIN_CHUNK chars isolated — inconclusive)')
        elif any(v[0] == 'our-ingest-dropped-it' for v in verdicts):
            overall = 'our-ingest-dropped-it'
        elif all(v[0] == 'publisher-disagreement' for v in verdicts):
            overall = 'publisher-disagreement'
        else:
            overall = 'inconclusive'

        for kind, chunk, why in verdicts:
            print(f'   [{kind}] {why}\n     {chunk!r}')
        print(f'   => VERDICT: {overall}\n')


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--edition', choices=sorted(EDITIONS), default='v2',
                         help='which of biblexg-v2*/v3* to check (default: '
                              'v2, matching this script\'s original scope)')
    args = parser.parse_args()
    edition = args.edition

    if shutil.which('opencc') is None:
        print('SKIP — opencc not on PATH. Expected on CI; this check needs '
              'the real converter, never a hand-rolled map.')
        return 0

    ed = EDITIONS[edition]
    src_dir = find_source_dir(edition)
    if src_dir is None:
        print(f'SKIP — no publisher source cache found for {edition} '
              f"({ed['cache_dir']!r}). Expected on CI; run "
              f'tools/audit_biblexg_notes.py --edition {edition} once to '
              'populate it.')
        return 0

    sc_notes = load_our_notes(ed['cn_asset'])
    tr_notes = load_our_notes(ed['tr_asset'])

    unexplained = check_growth(sc_notes, tr_notes, edition)
    if unexplained:
        print(f'\nGROWTH — {len(unexplained)} id(s) with genuinely missing '
              'blockNotes content not already in PENDING_CLASSIFICATION:')
        for vid, chunks in unexplained:
            print(f'  {vid}: {chunks}')
        print('\nDo not repair assets/ from this alone — pin the id(s) in '
              'PENDING_CLASSIFICATION only after running this script again '
              'to get their publisher-source verdict, same as the 13 '
              'already pinned.')
        return 1

    suffix = '' if edition == 'v2' else f' ({edition})'
    print(f'No growth beyond the pinned PENDING_CLASSIFICATION set{suffix}.\n')

    if edition != 'v2':
        print('== Pinned v2 bucket-(c) set, cross-checked against '
              f'{edition} ==\n')
        for vid, ref, status, sc_n, tr_n in pending_id_status(
                sc_notes, tr_notes):
            counts = f'SC {sc_n} / TR {tr_n}' if sc_n is not None else '?'
            print(f'  {ref:12s} {vid}: {status:18s} ({counts})')
        print(f'\nSkipping publisher-source verdicts for {edition}: this '
              "script's own docstring says its source cache "
              f"({ed['cache_dir']!r}) is not like-for-like with "
              f"{edition}'s assets — the assets carry footnotes adopted "
              'from the translator\'s newer site while the cached snapshot '
              'is the older, thinner one (see audit_biblexg_v2_vs_tr.py\'s '
              'docstring and commit c6461080). A verdict from a thinner '
              'snapshot would be a guess dressed as a finding, so this '
              'stops at the bucket level: every id above marked '
              "'survives-bucket-c' is inconclusive for this edition — "
              'cache not like-for-like with assets, not a confirmed '
              'publisher-disagreement/our-ingest-dropped-it verdict.')
        return 0

    classify(sc_notes, tr_notes, src_dir)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
