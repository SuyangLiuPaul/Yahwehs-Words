#!/usr/bin/env python3
"""Fix 20 wrong-script (Simplified) characters inside `<note:…>` footnote
content in `biblexg-v3-tr.json` — `docs/autonomous-queue.md:10838`, the
`-v3-tr` half of the item `tools/repair_biblexg_v3_note_script_typos.py`
fixed for `-v3` (Simplified edition) and explicitly deferred here.

`biblexg-v3-tr.json` was imported verbatim from the publisher's own
Traditional files (`~/.cache/yswords/ljk-source-v3/tw-<book>.json`), not
converted from `-v3` by us — this is NOT the deferred Traditional-glyph /
converter-hole class (tier 7 in the loop's brief). It is the same class
`repair_biblexg_v3_note_script_typos.py` fixed on the Simplified side:
one-off Simplified characters that reached an otherwise-Traditional note,
publisher-side.

**Measurement.** Every unique CJK character in `<note:…>` content across
`-v3-tr.json` (1,782 of them) was run through OpenCC's character-level
`STCharacters.ocd2` dictionary (no phrase dictionary — a custom config
built to isolate character-level conversion the way the CLI's stock
`s2t.json` does not, since it chains `STPhrases.ocd2` first). 39 characters
differ from their own conversion, 134 occurrences total. Of those, 21
characters / 34 occurrences / 25 verses are included below; the other 18
are excluded, each for a documented reason (see below) — nothing outside
that 39-character union needed a decision.

**Adversarial re-review before `--write` overturned one exclusion.**
The stage that first drafted this script excluded 兹 (8 occurrences,
7 verses, all in Revelation 2–3's city-location notes — 伊兹密爾/Izmir
and 代尼兹利/Denizli) on "asset's own settled convention" grounds, the
same reasoning that correctly excludes 里/群/秘/吃/床/伙/etc below. It
does not hold for 兹: unlike those, 茲 (its correct Traditional target)
occurs **zero** times anywhere else in the entire asset — 兹 has no
independent Traditional-Chinese usage of its own here to be "the
convention," it appears exclusively as this leak. The cached publisher
source (`tw-rev.json`) itself has 兹×8 / 茲×0 in exactly those seven
notes — same publisher-side-leak shape as the other 20 — and
zh-TW references (e.g. Chinese Wikipedia) write both place names with
茲 (伊茲密爾, 代尼茲利/德尼茲利), not 兹. Re-filed as included; see
`EDITS`/`CHAR_MAP` below.

**Provenance: publisher-side, not import-side, for every occurrence.**
All 34 occurrences (not just a feasibility grep) were matched — `<mark>`
tags stripped, per-book character counts compared exactly — against the
cached upstream fetch (`~/.cache/yswords/ljk-source-v3/tw-<book>.json`,
the Traditional-edition source `import_ljk2.py` built this asset from).
Every one of the 21 characters is already present there, at the exact
same per-book count as this file, in what the publisher's own file calls
its Traditional text; one occurrence (43008023, 与) only matched after
normalising a newline the asset's importer had already collapsed to a
space — not a defect, a whitespace difference.

**Target character: the asset's own dominant Traditional form, not
OpenCC's naive pick.** For 20 of the 21 characters, OpenCC's
`STCharacters.ocd2` target already matches the asset's overwhelming
existing usage (checked: each target form appears from 8 to 2,344 times
elsewhere in the asset, 0 times for a Traditional-internal alternate).
The one exception is 为: `STCharacters.ocd2` naively maps it to 爲, which
this asset never uses (0 occurrences) — it uses 為 exclusively (2,344
occurrences), the same 為/爲 Traditional-internal-variant trap the `-v3`
script's docstring already names. `CHAR_MAP` below maps 为 to 為, the
asset's own convention, not OpenCC's default.

**Deliberately excluded — 18 characters, each for a stated reason:**

*OpenCC's target itself would ship a misspelling* — checked against
context, not accepted on the dictionary's word alone:
  - 征→徵: both occurrences are `或作征服`; 征服 is the correct Traditional
    word, 徵服 is not.
  - 占→佔: both occurrences are transliterations (占星術, 拜占庭); 占 is
    kept in Traditional for these, 佔 is not used for them.
  - 划→劃: the single occurrence is `律法書的一點一划`, echoing Matthew
    5:18 — the printed idiom is 一點一畫 (jot and tittle), not 一點一劃.
    Neither 划 nor 劃 is the correct character; this needs a different
    fix, not a script-conversion one, so it stays out of this script's
    scope entirely.
  - 台→臺: the single occurrence is 帕台農神殿 (Parthenon), a
    transliteration nobody renders 帕臺農.

*The edition's own settled convention already IS the flagged form*
(checked: the "correct" Traditional form appears rarely-to-never
elsewhere in this same asset, so "fixing" it would fight the edition's
own usage, not align with it — unlike 兹 above, each of these DOES have
independent usage elsewhere in the asset): 里 (45 occurrences; 裏 0 — the
deferred 里/裏/裡 one-to-many class this item's own filing already
names; spot-checked: all uses in `-v3-tr` notes are 公里/克里特/底格里斯
-style measure/proper-noun readings, never the "inside" 裡/裏 sense),
群 (11; 羣 0), 秘 (9; 祕 0), 吃 (3; 喫 0), 床 (2; 牀 0), 伙 (1, 伙伴 in a
Greek-grammar note; 伙 elsewhere in the asset 27, 夥 5 — unlike 兹, 伙
has substantial independent usage here), 托 (7; 託 46 vs
托 8 — mixed usage, not a settled 0), 准 (准 and 準 are different words —
准許 vs 標準 — not a script pair), 岳 (1; the compound 岳父 is written
with 岳 in this asset's other Traditional father-in-law references too),
吁 (勸吁 vs 籲 — different words, not a script pair), 游 (游手好閒 is the
idiom; 遊 is a different sense of the word).

*Named glyph-convention pair, excluded by the existing test guards:*
内→內 (8 occurrences) — `docs/autonomous-queue.md:10838`'s own filing
groups 内/內 with 说/説 and 着/著, the editions'-own-choice class the
`-v3`/`-v3-tr` body guard in `biblexg_verse_integrity_test.dart` already
carves out.

*Traditional-internal variant, not a wrong-script character at all:*
麽→麼 (2 occurrences; 么 is the Simplified form, so 麽 is not a script
error — the `-v3` script excluded the identical pair on the Simplified
side for the identical reason).

*Different word, not a script pair:* 采→採 (1 occurrence, 風采 — 采 is the
correct character for this sense; 採 is for 採摘/採用).

Run:
    python3 tools/repair_biblexg_v3_tr_note_script_typos.py            # dry run
    python3 tools/repair_biblexg_v3_tr_note_script_typos.py --write
"""
from __future__ import annotations

import argparse
import importlib.util
import json
import os
import re

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
NOTE_RE = re.compile(r'<note:[^>]*>')


def _load_line_breaks_module():
    spec = importlib.util.spec_from_file_location(
        'repair_biblexg_line_breaks',
        os.path.join(REPO_ROOT, 'tools', 'repair_biblexg_line_breaks.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


# id -> {wrong char: expected occurrence count}. Every character here
# occurs ONLY inside <note:…> content for its row (verified: 0
# occurrences in the body once notes are stripped) and every occurrence
# is confirmed publisher-side — see module docstring.
EDITS: dict[str, dict[str, int]] = {
    '40006033': {'条': 1},
    '40024015': {'猪': 1},
    '41007016': {'删': 1},
    '42013011': {'气': 1},
    '42017001': {'词': 1},
    '42024050': {'词': 1, '组': 1},
    '43001001': {'没': 3},
    '43001042': {'语': 1},
    '43008023': {'与': 1},
    '44020015': {'爱': 1},
    '45008028': {'标': 1, '为': 2, '参': 1},
    '47003018': {'镜': 1},
    '48004003': {'愿': 1},
    '50003011': {'两': 1},
    '51002008': {'于': 1},
    '51003005': {'强': 1},
    '55004007': {'条': 1},
    '62002018': {'详': 1, '况': 1},
    '66002001': {'兹': 1},
    '66002008': {'爱': 1, '兹': 1},
    '66002012': {'兹': 1},
    '66002018': {'兹': 1},
    '66003001': {'兹': 1},
    '66003007': {'兹': 1},
    '66003014': {'兹': 2},
}

# wrong -> right, derived from EDITS' keys (kept separate so the map
# above stays a pure provenance record: id, char, expected count). Every
# target is the asset's own dominant Traditional form — see the 为/為/爲
# note in the module docstring for the one case where that differs from
# OpenCC's naive STCharacters.ocd2 pick.
CHAR_MAP: dict[str, str] = {
    '条': '條', '猪': '豬', '删': '刪', '气': '氣', '词': '詞', '组': '組',
    '没': '沒', '语': '語', '与': '與', '爱': '愛', '标': '標', '为': '為',
    '参': '參', '镜': '鏡', '愿': '願', '两': '兩', '于': '於', '强': '強',
    '详': '詳', '况': '況', '兹': '茲',
}


def compute_repairs(rows: list[dict]) -> list[tuple[str, str, str]]:
    """`(id, old_text, new_text)` for every row in `EDITS`.

    Fails loudly if a targeted row's note content has moved since this
    map was written — either the character count no longer matches, or
    the character has leaked into the body (outside `<note:…>`), which
    would mean this script's body-untouched guarantee no longer holds.
    """
    by_id = {r['id']: r for r in rows}
    out: list[tuple[str, str, str]] = []
    for vid, char_counts in EDITS.items():
        row = by_id.get(vid)
        if row is None:
            raise SystemExit(f'id {vid!r} not found — asset changed shape')
        text = row['text']
        body = NOTE_RE.sub('', text)
        new_text = text
        for wrong, expected in char_counts.items():
            n = text.count(wrong)
            if n == 0:
                continue  # already repaired
            if n != expected:
                raise SystemExit(
                    f'{vid}: expected {expected} of {wrong!r}, found {n} — '
                    're-derive the edit by hand')
            if body.count(wrong) != 0:
                raise SystemExit(
                    f'{vid}: {wrong!r} now appears outside <note:…> — '
                    'this script only touches note content, re-derive by hand')
            new_text = new_text.replace(wrong, CHAR_MAP[wrong])
        if new_text != text:
            out.append((vid, text, new_text))
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                  formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--write', action='store_true',
                    help='apply the repair (default: dry run, report only)')
    args = ap.parse_args()

    line_breaks = _load_line_breaks_module()
    path = os.path.join(REPO_ROOT, 'assets', 'biblexg-v3-tr.json')
    with open(path, encoding='utf-8') as f:
        raw = f.read()
    rows = json.loads(raw)
    edits = compute_repairs(rows)
    for vid, old, new in edits:
        print(f'{vid}: repaired')
    if args.write and edits:
        new_raw = line_breaks.apply_text_edits(raw, edits)
        with open(path, 'w', encoding='utf-8') as f:
            f.write(new_raw)
    verb = 'wrote' if args.write else 'would write'
    print(f'biblexg-v3-tr: {verb} {len(edits)} row(s)')
    if not args.write:
        print('dry run — pass --write to apply')
    elif not edits:
        print('already repaired — nothing to write')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
