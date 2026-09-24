#!/usr/bin/env python3
"""Insert the `reference`/`paragraph` line break `assemble_verse_text()`
used to drop — `docs/autonomous-queue.md:8943`.

Before this fix, `import_ljk2.py`'s `assemble_verse_text()` treated the
upstream's `lineBreak: 'reference'` and `lineBreak: 'paragraph'` markers
as if they were `'inline'`: no separator at all, fragments glued
together. Both are block-level in the publisher's own React renderer
(`BibleDisplay.tsx:72-110` — `reference` opens a new `<Box
className="ot-refs">`, `paragraph` opens a new `<Text as="p">`), so the
missing separator is a defect, not a rendering choice. Reader-visible:
`biblexg-v2.json`'s 45003010 (Romans 3:10) reads
`正如经上所记：\n没有义人，\n一个也没有，`; its replacement
`biblexg-v3.json` — the version the app actually ships, `biblexg-v2` was
superseded in `bible_versions.dart:401-402` — reads the same verse with
the two clauses run together with no break at all.

`assemble_verse_text()` itself is fixed (treats `reference`/`paragraph`
like `line`, emits a single `\n`). This script is the one-time repair
for the two assets that were already built with the old, wrong version:
`assets/biblexg-v3.json` and `assets/biblexg-v3-tr.json`.

**Why not just re-run `import_ljk2.py --force`:** its own printed output
says a five-step repair chain must follow a fresh import
(`repair_biblexg` splits verses, `repair_verse_numbering` re-keys ids,
`repair_biblexg_v2_tr` fixes 30 named 繁体 sites, `carry_forward_ljk`
fills remaining gaps). Re-running that whole chain unattended risks
undoing hand-repairs already layered on top of these assets. This
script instead re-assembles each verse from the SAME cached upstream
source the current assets were built from (`/tmp/ljk-source/`, never
re-fetched — see `import_ljk2.fetch()`; a re-fetch can silently pull a
newer upstream revision, confirmed by hand: `/tmp/ljk-source/cn-mt.json`
and the `ljk-nt-bible-webapp` checkout already disagree on Matthew
1:21 — 应给 vs 应要给 — and only the cached copy matches the current
asset), and only ever inserts '\n' characters.

**The guard that makes this mechanical:** a row is touched only if the
freshly assembled text equals the current asset text once every `'\n'`
— and *only* `'\n'` — is stripped from both. That makes it structurally
impossible to change a character of scripture, or even a space:  the
first version of this guard stripped ALL whitespace (`re.sub(r'\\s+',
'', …)`), which is a real difference of kind, not degree — it also
matched 8 rows where a `<note:...>` tag's content gained stray spaces
around it (`<note:犹太人>` → `<note: 犹太人 >`, Romans 3:9 among them) from
an unrelated quirk of re-running `html_to_inline()`, and a `--write` run
with that guard silently wrote all 8 in. Caught by diffing the write
against the current asset by hand before committing, not by a test —
which is why `test_a_real_character_difference_disguised_by_whitespace_is_refused`
now asserts specifically against a whitespace-only false match, not just
a differing-character one. Every verse reshaped by the five-step repair
chain (split rows, re-keyed ids, carried-forward wording, fixed 繁体
glyphs) — and every row like the 8 above — fails this guard and is left
untouched, by construction, not by exclusion list.

Measured 2026-09-24, walking `/tmp/ljk-source/` (the cached snapshot
these assets were built from): 269 `reference` + 189 `paragraph` = 458
break fragments inside verse `contents` arrays (457 mid-verse, 1 at
index 0 — the leading-fragment guard in `assemble_verse_text()` keeps
that one from emitting a spurious leading `\n`). Simulating the new
assembler over that same source and comparing row-for-row against the
current assets, with the `'\n'`-only guard: 207 rows in
`biblexg-v3.json` and 203 in `biblexg-v3-tr.json` — 410 total — are the
rows this script actually writes. (An earlier, looser whitespace-equality
guard counted 427; the 17-row difference is exactly the 8 + 9 rows the
tighter guard now correctly refuses — see above.)

Run:
    python3 tools/repair_biblexg_line_breaks.py            # dry run
    python3 tools/repair_biblexg_line_breaks.py --write
"""
from __future__ import annotations

import argparse
import importlib.util
import json
import os
import re
import sys

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

_ID_KEY_RE = re.compile(r'"id"\s*:\s*"')
_TEXT_KEY_RE = re.compile(r'"text"\s*:\s*"')


def _scan_json_string(s: str, quote_pos: int) -> tuple[int, int]:
    """`s[quote_pos]` is a JSON string's opening `"`. Return `(start, end)`
    spanning the whole literal, quotes included, respecting `\\`-escapes."""
    i = quote_pos + 1
    n = len(s)
    while i < n:
        if s[i] == '\\':
            i += 2
            continue
        if s[i] == '"':
            return quote_pos, i + 1
        i += 1
    raise ValueError('unterminated JSON string')


def apply_text_edits(raw: str, edits: list[tuple[str, str, str]]) -> str:
    """Replace each named row's `text` VALUE ONLY, byte-for-byte, leaving
    every other byte of the file untouched — including whichever of the
    two formatting styles these two assets happen to use (`biblexg-v3.json`
    is compact, `-tr.json` is pretty-printed with a 1-space indent). A
    full `json.dump()` round trip would reformat whichever file does not
    already match that dump's own style, burying 427 real edits inside a
    whole-file diff — found the hard way, the first version of this
    script did exactly that to `-tr.json` (81,483 lines touched for what
    should have been ~212).

    `edits` is `(id, old_text, new_text)`. Each row's OWN previous
    `text` value is verified byte-for-byte against the file before it is
    replaced — this is the second, independent copy of the same guard
    `compute_repairs()` already applied to the parsed JSON, so a caller
    that skipped that guard, or a file that changed between the read
    and this write, fails loudly instead of silently overwriting the
    wrong row.
    """
    remaining = {vid: (old, new) for vid, old, new in edits}
    positions: list[tuple[str, int]] = (
        [('text', m.end() - 1) for m in _TEXT_KEY_RE.finditer(raw)]
        + [('id', m.end() - 1) for m in _ID_KEY_RE.finditer(raw)])
    positions.sort(key=lambda p: p[1])

    replacements: list[tuple[int, int, str]] = []
    last_text_span: tuple[int, int] | None = None
    for kind, qpos in positions:
        start, end = _scan_json_string(raw, qpos)
        if kind == 'text':
            last_text_span = (start, end)
            continue
        vid = json.loads(raw[start:end])
        if vid not in remaining:
            continue
        old_text, new_text = remaining.pop(vid)
        if last_text_span is None:
            raise ValueError(f'no "text" field precedes id {vid!r}')
        t_start, t_end = last_text_span
        actual_old_literal = raw[t_start:t_end]
        if json.loads(actual_old_literal) != old_text:
            raise ValueError(
                f'id {vid!r}: file text does not match the text this '
                'edit was computed against — refusing to write')
        replacements.append((t_start, t_end, json.dumps(new_text, ensure_ascii=False)))

    if remaining:
        raise ValueError(f'ids not found in raw file: {sorted(remaining)}')

    replacements.sort(key=lambda r: r[0])
    out: list[str] = []
    cursor = 0
    for t_start, t_end, literal in replacements:
        out.append(raw[cursor:t_start])
        out.append(literal)
        cursor = t_end
    out.append(raw[cursor:])
    return ''.join(out)


def _load_import_ljk2():
    spec = importlib.util.spec_from_file_location(
        'import_ljk2', os.path.join(REPO_ROOT, 'tools', 'import_ljk2.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _nl_strip(s: str) -> str:
    """Strip ONLY '\\n' — never a general whitespace strip.

    A general `\\s+` strip also matches a real, unrelated character
    change that happens to be a space (`<note:X>` → `<note: X >`), which
    this script must refuse, not paper over. See the module docstring.
    """
    return s.replace('\n', '')


def load_cached_source(cache_dir: str, lang: str, abbr: str) -> list[dict]:
    """Read one upstream book file from the cache — never the network.

    Fails loudly rather than falling back to a fetch: a fetch can return
    a different upstream revision than the one these assets were built
    from (confirmed by hand, see module docstring), which would make the
    whitespace-equality guard below compare against the wrong source.
    """
    path = os.path.join(cache_dir, f'{lang}-{abbr}.json')
    if not os.path.exists(path):
        raise SystemExit(
            f'FAIL: no cached upstream source at {path}. This repair must '
            'run against the SAME snapshot the asset was built from, not '
            'a fresh fetch — see the module docstring.')
    with open(path, encoding='utf-8') as f:
        return json.load(f)


def rebuild_verse_map(ljk2, cache_dir: str, use_tr: bool) -> dict[str, str]:
    """Re-assemble every verse's text from the cached upstream source."""
    lang = 'tw' if use_tr else 'cn'
    by_id: dict[str, str] = {}
    for abbr, _en, cn, tr, bid in ljk2.BOOKS:
        data = load_cached_source(cache_dir, lang, abbr)
        for v in ljk2.build_book_verses(data, bid, cn, tr, use_tr=use_tr,
                                        lang=lang, abbr=abbr, log=[]):
            by_id[v['id']] = v['text']
    return by_id


def compute_repairs(
    rows: list[dict], new_by_id: dict[str, str],
) -> tuple[list[tuple[int, str, str]], int, int]:
    """Decide, for each asset row, what this script may do to it.

    Returns `(to_write, skipped_mismatch, skipped_missing)` where
    `to_write` is `(row_index, id, new_text)` for rows whose freshly
    assembled text differs from the current text ONLY in `'\\n'`
    characters — the sole case this script is allowed to touch.
    `skipped_mismatch` counts rows where a real, non-newline character
    differs — either a later repair pass reshaped the row (split, fixed
    a 繁体 glyph, carried-forward wording) or re-running `html_to_inline()`
    produced an unrelated difference (a stray space inside a `<note:>`
    tag, seen on 8 rows) — left alone by construction either way.
    `skipped_missing` counts ids the fresh rebuild has no match for
    (typically re-keyed by `repair_verse_numbering.py` since import).
    """
    to_write: list[tuple[int, str, str]] = []
    skipped_mismatch = 0
    skipped_missing = 0
    for i, row in enumerate(rows):
        new = new_by_id.get(row['id'])
        if new is None:
            skipped_missing += 1
            continue
        if new == row['text']:
            continue
        if _nl_strip(new) != _nl_strip(row['text']):
            skipped_mismatch += 1
            continue
        to_write.append((i, row['id'], new))
    return to_write, skipped_mismatch, skipped_missing


def repair_asset(ljk2, cache_dir: str, path: str, use_tr: bool, *,
                  write: bool) -> tuple[int, int, int]:
    with open(path, encoding='utf-8') as f:
        raw = f.read()
    rows = json.loads(raw)
    new_by_id = rebuild_verse_map(ljk2, cache_dir, use_tr)
    to_write, skipped_mismatch, skipped_missing = compute_repairs(rows, new_by_id)

    if write and to_write:
        edits = [(rows[i]['id'], rows[i]['text'], new_text)
                 for i, _vid, new_text in to_write]
        new_raw = apply_text_edits(raw, edits)
        with open(path, 'w', encoding='utf-8') as f:
            f.write(new_raw)

    return len(to_write), skipped_mismatch, skipped_missing


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                  formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--write', action='store_true',
                    help='apply the repair (default: dry run, report only)')
    ap.add_argument('--cache-dir', default=None,
                    help='override the cached upstream source directory '
                         '(default: import_ljk2.CACHE_DIR, i.e. /tmp/ljk-source)')
    args = ap.parse_args()

    ljk2 = _load_import_ljk2()
    cache_dir = args.cache_dir or ljk2.CACHE_DIR

    total_written = 0
    for code, use_tr in (('biblexg-v3', False), ('biblexg-v3-tr', True)):
        path = os.path.join(REPO_ROOT, 'assets', f'{code}.json')
        written, skipped_mismatch, skipped_missing = repair_asset(
            ljk2, cache_dir, path, use_tr, write=args.write)
        total_written += written
        verb = 'wrote' if args.write else 'would write'
        print(f'{code}: {verb} {written} rows; skipped {skipped_mismatch} '
              f'reshaped by a later repair pass, {skipped_missing} with no '
              f'matching id in the fresh rebuild (expected, not a failure)')

    if not args.write:
        print('dry run — pass --write to apply')
    elif total_written == 0:
        print('already repaired — nothing to write')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
