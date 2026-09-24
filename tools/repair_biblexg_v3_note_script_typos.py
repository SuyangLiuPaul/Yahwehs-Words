#!/usr/bin/env python3
"""Fix 46 wrong-script characters inside `<note:…>` footnote content in
`biblexg-v3.json` — `docs/autonomous-queue.md:10837`, the `-v3` half of
that item (Simplified edition only; `-v3-tr` is explicitly deferred).

`tools/repair_biblexg_v3_script_typos.py` fixed 10 wrong-script
characters in verse BODY text and its own guard strips `<note:…>`
before scanning, so it never saw this class. This script covers note
content instead, using the same shape (enumerated map, dry run by
default, `--write` to apply).

**Provenance: publisher-side, not import-side, for every character
below.** Each was checked against the cached upstream fetch
(`~/.cache/yswords/ljk-source-v3/cn-<book>.json`, the Simplified-edition
source `import_ljk2.py` built these two assets from) by locating the
exact note text — HTML `<mark>` tags stripped, whitespace collapsed —
and confirming the flagged character is already present there, verbatim,
in what the publisher's own Simplified-edition file calls Simplified
text. All 46 occurrences (31 characters, 20 verses) matched on that
basis; none required accepting a claim on frequency alone (穌 6, 參 3,
來 3, 羅 3, … down to 21 singletons — recomputed at HEAD, not copied
from the planning note that flagged this item, which used a different
counting method and got 37/52 because it also counted the deferred
class below).

The 31-character included set was cross-checked exhaustively, not just
assembled from the planning note's frequency table: every unique CJK
character appearing anywhere in any `-v3` note (1,761 of them) was run
through the same character-level `t2s` dictionary; only 37 differ from
their own conversion at all, and those 37 are exactly the union of this
script's 31 included characters and the 6 excluded ones below — nothing
outside that union needed a decision. (An earlier draft of this script
missed 數/数 — a real, publisher-side occurrence at 使徒行传 9:11's
「大數」 alongside 5 other flagged characters in the same note — because
it was manually transcribed from the planning note's list and dropped
in the process. The same review also caught a wrong mapping: 穌's
target was hand-typed as 苏 (U+82CF, the 江苏/苏联 character) instead of
稣 (U+7A23, the character the asset already uses 1,603 times in 耶稣) —
visually similar, semantically wrong, and would have shipped 耶苏 six
times had it not been caught. Both were found by an adversarial review
before commit, not before the first `--write` — this script's `EDITS`/
`CHAR_MAP` below are the corrected version.

**Deliberately excluded, all appear in the same notes:** 麽/麼 (the
么/麽/麼 Traditional-internal variant convention — even `s2t` char-level
round-trip disagrees on which one is canonical), 裡 (`s2t` round-trips
里→裏, not 裡: this is the same 里/裏/裡 one-to-many class the `-v3-tr`
guard already defers, and the sister item on that side names the same
class for the same reason), 慾 (`s2t` round-trips 欲→欲, i.e. 慾 is a
distinct Traditional nuance word — 情慾 vs 情欲 — not a simplification of
欲, the same kind of pair as 蹟/跡), 捱 (OpenCC's character dict maps it
to 挨, but 捱 is itself a valid, commonly used character in Simplified
text — 捱過/捱打 — so flagging it as "Traditional in Simplified" would be
a false positive), 註 (the 註/注 annotation-marker convention already
has its own dedicated, passing guard in
`test/biblexg_verse_integrity_test.dart`, "each edition writes the
annotation marker in its own script" — folding it in here would
duplicate and could conflict with that test).

Every included character was verified one-to-one: `TSCharacters.ocd2`
(character-level, no phrase dictionary) maps it to exactly one
Simplified form, and reversing that Simplified form with
`STCharacters.ocd2` returns the same character back (the one exception,
為→为→爲, is the 為/爲 Traditional-internal variant pair — irrelevant
here since this script only ever converts the direction found in the
Simplified asset, Traditional→Simplified, which is unambiguous
regardless of what the reverse conversion would pick).

Run:
    python3 tools/repair_biblexg_v3_note_script_typos.py            # dry run
    python3 tools/repair_biblexg_v3_note_script_typos.py --write
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
    '40027029': {'參': 1},
    '42001045': {'穌': 2},
    '42016009': {'譯': 1},
    '42016016': {'爭': 1},
    '43001001': {'詞': 1, '來': 1, '屢': 2, '這': 1, '時': 1, '兒': 1},
    '43003015': {'穌': 1},
    '44003021': {'須': 1},
    '44009011': {'羅': 2, '節': 1, '東': 1, '馬': 1, '亞': 1, '數': 1},
    '44013001': {'譯': 1},
    '44015013': {'為': 1, '領': 1},
    '45008019': {'熱': 1},
    '45008028': {'穌': 1, '針': 1},
    '45010015': {'鴻': 1},
    '48003011': {'參': 1, '來': 1, '羅': 1},
    '48004003': {'穌': 1, '屬': 1, '經': 1, '連': 1, '釘': 1, '異': 1},
    '49003018': {'寬': 1, '長': 1},
    '51003010': {'參': 1},
    '55004007': {'來': 1, '時': 1, '當': 1, '還': 1},
    '66003014': {'穌': 1},
    '66006012': {'鴻': 1},
}

# wrong -> right, derived from EDITS' keys (kept separate so the map
# above stays a pure provenance record: id, char, expected count).
CHAR_MAP: dict[str, str] = {
    '參': '参', '穌': '稣', '譯': '译', '爭': '争', '詞': '词', '來': '来',
    '屢': '屡', '這': '这', '時': '时', '兒': '儿', '須': '须', '羅': '罗',
    '節': '节', '東': '东', '馬': '马', '亞': '亚', '為': '为', '領': '领',
    '熱': '热', '針': '针', '鴻': '鸿', '屬': '属', '經': '经', '連': '连',
    '釘': '钉', '異': '异', '寬': '宽', '長': '长', '當': '当', '還': '还',
    '數': '数',
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
    path = os.path.join(REPO_ROOT, 'assets', 'biblexg-v3.json')
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
    print(f'biblexg-v3: {verb} {len(edits)} row(s)')
    if not args.write:
        print('dry run — pass --write to apply')
    elif not edits:
        print('already repaired — nothing to write')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
