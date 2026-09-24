#!/usr/bin/env python3
"""Fix 10 wrong-script characters in `biblexg-v3.json` / `-v3-tr.json` —
`docs/autonomous-queue.md` (P0, filed 2026-09-24).

The September re-fetch (`16633cad`) shipped these editions with a
handful of characters from the wrong script: Simplified glyphs inside
the Traditional edition, Traditional glyphs inside the Simplified one.
The existing guard in
`test/biblexg_verse_integrity_test.dart:579` never saw them — it scans
only the superseded `biblexg-v2-tr.json`, which these 10 verses do not
share a defect with (confirmed clean there; v2 was proofread against
the printed 註釋本, v3 was not).

Each of the 10 is a **publisher-side one-off typo**, not a conversion
miss of ours: every character below appears exactly once in the cached
upstream file it came from (`~/.cache/yswords/ljk-source/`), against
tens to hundreds of correctly-scripted instances of the same character
in the same file. `git log -S` on each confirms the character has been
wrong since the September fetch commit itself — nothing since has
touched it.

The 2 Traditional-side characters (門/給 at 太7.7, 路11.13) are also
confirmed against the printed 讀_繁_註釋本 (`tools/proofread_ljk_tr.py`'s
own text extraction): both print Traditional. The 8 Simplified-side
characters have **no printed witness at all** — the 註釋本 is
Traditional-only — so those 8 are repaired on internal-consistency
grounds alone (×1 against 70+ correct instances in the same upstream
file), not against print.

This is NOT the deferred one-to-many converter-hole class (蹟/跡,
鍊/鏈, 兇/凶, …). Every character here is one-to-one: the target verse
already contains no ambiguity, since the SAME upstream file uses the
correct form hundreds of times elsewhere. An enumerated map only —
never a blanket `opencc` sweep, which would also flag the deferred
class.

Run:
    python3 tools/repair_biblexg_v3_script_typos.py            # dry run
    python3 tools/repair_biblexg_v3_script_typos.py --write
"""
from __future__ import annotations

import argparse
import importlib.util
import json
import os

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def _load_line_breaks_module():
    spec = importlib.util.spec_from_file_location(
        'repair_biblexg_line_breaks',
        os.path.join(REPO_ROOT, 'tools', 'repair_biblexg_line_breaks.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


# (asset code, verse id) -> (wrong char, right char, gloss)
# `-tr` entries: printed 註釋本 confirms the Traditional form (see module
# docstring). Plain entries: no printed witness; repaired on
# internal-consistency grounds only — say so in the commit, not as a
# print match.
EDITS: dict[tuple[str, str], tuple[str, str]] = {
    ('biblexg-v3-tr', '40007007'): ('门', '門'),  # 太7.7 — print reads 敲門
    ('biblexg-v3-tr', '42011013'): ('给', '給'),  # 路11.13 — print reads 給
    ('biblexg-v3', '41002003'): ('來', '来'),      # 可2.3 — no print witness
    ('biblexg-v3', '42008027'): ('靈', '灵'),      # 路8.27 — no print witness
    ('biblexg-v3', '42022031'): ('說', '说'),      # 路22.31 — no print witness
    ('biblexg-v3', '44027036'): ('餅', '饼'),      # 徒27.36 — no print witness
    ('biblexg-v3', '47005021'): ('無', '无'),      # 林后5.21 — no print witness
    ('biblexg-v3', '49006011'): ('禦', '御'),      # 弗6.11 — no print witness
    ('biblexg-v3', '50003004'): ('別', '别'),      # 腓3.4 — no print witness
    ('biblexg-v3', '61001019'): ('話', '话'),      # 彼后1.19 — no print witness
}


def compute_repairs(code: str, rows: list[dict]) -> list[tuple[str, str, str]]:
    """`(id, old_text, new_text)` for the rows this script's map covers.

    Fails loudly (not silently skips) if a targeted row's wrong
    character has already changed count since the map was written —
    that means the asset moved under us and the map needs re-deriving,
    not a blind overwrite.
    """
    by_id = {r['id']: r for r in rows}
    out: list[tuple[str, str, str]] = []
    for (edit_code, vid), (wrong, right) in EDITS.items():
        if edit_code != code:
            continue
        row = by_id.get(vid)
        if row is None:
            raise SystemExit(f'{code}: id {vid!r} not found — asset changed shape')
        text = row['text']
        n = text.count(wrong)
        if n == 0:
            continue  # already repaired
        if n != 1:
            raise SystemExit(
                f'{code}/{vid}: expected exactly one {wrong!r}, found {n} — '
                'refusing to guess which one; re-derive the edit by hand')
        out.append((vid, text, text.replace(wrong, right, 1)))
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                  formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--write', action='store_true',
                    help='apply the repair (default: dry run, report only)')
    args = ap.parse_args()

    line_breaks = _load_line_breaks_module()
    total = 0
    for code in ('biblexg-v3', 'biblexg-v3-tr'):
        path = os.path.join(REPO_ROOT, 'assets', f'{code}.json')
        with open(path, encoding='utf-8') as f:
            raw = f.read()
        rows = json.loads(raw)
        edits = compute_repairs(code, rows)
        total += len(edits)
        for vid, old, new in edits:
            print(f'{code}/{vid}: {old!r} -> {new!r}')
        if args.write and edits:
            new_raw = line_breaks.apply_text_edits(raw, edits)
            with open(path, 'w', encoding='utf-8') as f:
                f.write(new_raw)
        verb = 'wrote' if args.write else 'would write'
        print(f'{code}: {verb} {len(edits)} row(s)')

    if not args.write:
        print('dry run — pass --write to apply')
    elif total == 0:
        print('already repaired — nothing to write')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
