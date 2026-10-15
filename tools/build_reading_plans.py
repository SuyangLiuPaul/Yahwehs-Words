#!/usr/bin/env python3
"""Generate assets/reading_plans.json from the app's own KJV.

2026-10-15: reading plans come back (the owner asked for them; the old
feature was removed in v1.2.69). The old asset is NOT reused: its
"chronological" plan had the same first and last day as the canonical
one, and its M'Cheyne day 1 was not M'Cheyne's day 1. Every plan here is
derived from data in this repository, so a test can re-derive it:

  * the chapter list and verse counts come from assets/kjv.json;
  * each day is a run of whole chapters, cut so that every day carries
    about the same number of VERSES (not chapters - Psalm 119 is one
    chapter of 176 verses, Psalm 117 one of 2);
  * every chapter of a plan's range appears exactly once, in canonical
    order.

Two kinds of plan, and only these two, because both can be checked:

  * plans DERIVED from chapter and verse counts (whole Bible, OT+NT,
    NT, Gospels, Psalms+Proverbs) — no tradition is claimed;
  * Robert Murray M'Cheyne's 1842 calendar, public domain, from
    tools/data/mcheyne_1842.json, whose _meta records where it was
    transcribed from and the independent copies it was checked against.

A "chronological" order is NOT generated: no public-domain ordering is in
this repository to check one against.

Output shape (compact on purpose, the app bundles it):

  {"plans": [{"id": "bible-1y", "days": 365,
              "schedule": [[["Genesis", 1, 3]], ...]}, ...]}

Each day is a list of [book, firstChapter, lastChapter] segments, or
[book, firstChapter, lastChapter, firstVerse, lastVerse] where the
calendar cuts inside a chapter (null = the chapter's own first/last).

Usage:  python3 tools/build_reading_plans.py          # writes the asset
        python3 tools/build_reading_plans.py --check  # exit 1 if stale
"""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KJV = os.path.join(ROOT, 'assets', 'kjv.json')
OUT = os.path.join(ROOT, 'assets', 'reading_plans.json')
VERSES = os.path.join(ROOT, 'assets', 'chapter_verses.json')

BOOKS = [
    'Genesis', 'Exodus', 'Leviticus', 'Numbers', 'Deuteronomy',
    'Joshua', 'Judges', 'Ruth', '1 Samuel', '2 Samuel', '1 Kings',
    '2 Kings', '1 Chronicles', '2 Chronicles', 'Ezra', 'Nehemiah',
    'Esther', 'Job', 'Psalms', 'Proverbs', 'Ecclesiastes',
    'Song of Solomon', 'Isaiah', 'Jeremiah', 'Lamentations', 'Ezekiel',
    'Daniel', 'Hosea', 'Joel', 'Amos', 'Obadiah', 'Jonah', 'Micah',
    'Nahum', 'Habakkuk', 'Zephaniah', 'Haggai', 'Zechariah', 'Malachi',
    'Matthew', 'Mark', 'Luke', 'John', 'Acts', 'Romans',
    '1 Corinthians', '2 Corinthians', 'Galatians', 'Ephesians',
    'Philippians', 'Colossians', '1 Thessalonians', '2 Thessalonians',
    '1 Timothy', '2 Timothy', 'Titus', 'Philemon', 'Hebrews', 'James',
    '1 Peter', '2 Peter', '1 John', '2 John', '3 John', 'Jude',
    'Revelation',
]


def verse_counts():
    rows = json.load(open(KJV, encoding='utf-8'))
    counts = {}
    for r in rows:
        key = (r['book'], int(r['chapter']))
        counts[key] = counts.get(key, 0) + 1
    return counts


def chapters(counts, books):
    out = []
    for b in books:
        n = max(c for (bb, c) in counts if bb == b)
        out.extend((b, c, counts[(b, c)]) for c in range(1, n + 1))
    return out


def split(chs, days):
    """Cut [chs] into [days] runs of whole chapters with balanced verses.

    Day k ends at the first chapter whose running verse total reaches
    k/days of the whole, while leaving at least one chapter for every
    remaining day.
    """
    assert len(chs) >= days, (len(chs), days)
    total = sum(v for _, _, v in chs)
    out, i, run = [], 0, 0
    for k in range(1, days + 1):
        target = total * k / days
        start = i
        remaining_days = days - k
        while i < len(chs) - remaining_days:
            run += chs[i][2]
            i += 1
            if run >= target:
                # Step back one chapter when that lands nearer the target
                # (and the day keeps at least one chapter).
                if i - 1 > start and (run - target) > (target - (run - chs[i - 1][2])):
                    i -= 1
                    run -= chs[i][2]
                break
        if i == start:  # never leave a day empty
            run += chs[i][2]
            i += 1
        out.append(chs[start:i])
    assert i == len(chs), (i, len(chs))
    return out


def segments(day):
    segs = []
    for b, c, _ in day:
        if segs and segs[-1][0] == b and segs[-1][2] == c - 1:
            segs[-1][2] = c
        else:
            segs.append([b, c, c])
    return segs


MCHEYNE = os.path.join(ROOT, 'tools', 'data', 'mcheyne_1842.json')


def mcheyne(counts):
    """M'Cheyne's 1842 calendar, as transcribed and cross-checked in
    tools/data/mcheyne_1842.json (see its _meta). Day n is the n-th date
    of the printed calendar (it has no February 29), so a reader can
    start it on any day. Segments keep the calendar's verse windows
    (Psalm 119 in seven parts, Exodus 11:1-12:21 and so on)."""
    data = json.load(open(MCHEYNE, encoding='utf-8'))
    days = []
    for day in data['days']:
        segs = []
        for b, c1, c2, v1, v2 in day['refs']:
            assert (b, c1) in counts and (b, c2) in counts, (b, c1, c2)
            seg = [b, c1, c2]
            if v1 is not None or v2 is not None:
                seg += [v1, v2]
            segs.append(seg)
        days.append(segs)
    assert len(days) == 365
    return days


def psalms_proverbs(counts):
    """31 days: Proverbs chapter d, plus Psalms cut evenly into 31."""
    ps = split(chapters(counts, ['Psalms']), 31)
    return [segments(ps[d]) + [['Proverbs', d + 1, d + 1]] for d in range(31)]


def build():
    counts = verse_counts()
    plans = []

    def plan(pid, books, days):
        plans.append({
            'id': pid,
            'days': days,
            'schedule': [segments(d) for d in split(chapters(counts, books), days)],
        })

    plan('bible-1y', BOOKS, 365)
    # OT and NT side by side. The NT has 260 chapters — fewer than 365
    # days — so it cannot be cut into 365 non-empty runs of whole
    # chapters; it is cut into 260 (about one chapter a day) and ends on
    # day 260, while the OT runs the whole year.
    ot = split(chapters(counts, BOOKS[:39]), 365)
    nt = split(chapters(counts, BOOKS[39:]), 260)
    plans.append({
        'id': 'bible-1y-ot-nt',
        'days': 365,
        'schedule': [segments(ot[d]) + (segments(nt[d]) if d < len(nt) else [])
                     for d in range(365)],
    })
    plans.append({'id': 'mcheyne', 'days': 365, 'schedule': mcheyne(counts)})
    plan('nt-90', BOOKS[39:], 90)
    plan('gospels-30', BOOKS[39:43], 30)
    plans.append({'id': 'psalms-proverbs-31', 'days': 31,
                  'schedule': psalms_proverbs(counts)})
    return {
        '_meta': {
            'generator': 'tools/build_reading_plans.py',
            'source': 'assets/kjv.json chapter and verse counts',
            'rule': 'whole chapters, canonical order, each chapter once, '
                    'days balanced by verse count',
        },
        'plans': plans,
    }


def chapter_verses():
    """{book: [verses in chapter 1, chapter 2, ...]} in canonical order.

    The app cuts a reader's OWN plan (any books, any number of days) with
    the same algorithm as [split], on this table, so a custom "Bible in a
    year" is byte-for-byte the bundled one (a test holds the two together).
    """
    counts = verse_counts()
    return {
        b: [counts[(b, c)] for c in range(1, max(k[1] for k in counts if k[0] == b) + 1)]
        for b in BOOKS
    }


def main():
    text = json.dumps(build(), ensure_ascii=False, separators=(',', ':'))
    verses_text = json.dumps(chapter_verses(), ensure_ascii=False, separators=(',', ':'))
    if '--check' in sys.argv:
        current = open(OUT, encoding='utf-8').read() if os.path.exists(OUT) else ''
        cur_v = open(VERSES, encoding='utf-8').read() if os.path.exists(VERSES) else ''
        if current != text or cur_v != verses_text:
            print('assets/reading_plans.json or assets/chapter_verses.json is stale: '
                  'run tools/build_reading_plans.py')
            sys.exit(1)
        print('assets/reading_plans.json and assets/chapter_verses.json are current')
        return
    open(OUT, 'w', encoding='utf-8').write(text)
    open(VERSES, 'w', encoding='utf-8').write(verses_text)
    data = json.loads(text)
    for p in data['plans']:
        print(p['id'], p['days'], 'days')


if __name__ == '__main__':
    main()
