#!/usr/bin/env python3
"""Import newly available Yahwehdehua editions without changing existing texts.

Reads the exported SQLite read-only. Canonical IDs and book names come from
this app's KJV witness, not translated source labels. Publisher notes remain
separate <note: ...> apparatus. English NET is text only. See permissions.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import sqlite3

EDITIONS = {
    'cnet': ('cnets', 31102, 3, 66, 26835),
    'cnet-tr': ('cnett', 31102, 3, 66, 26835),
    'net': ('nets', 31102, 17, 66, 0),
    'ogt': ('ogts', 7957, 12, 27, 1621),
    'sblgnt': ('sblgnts', 7957, 0, 27, 6901),
}
NOTE = re.compile(r'<(?:fnote|note)>(.*?)</(?:fnote|note)>', re.S)
TOKEN = re.compile(r'<note: [^>]*>|<W([HG])(\d+)(x?)>|<WT([^>]+)>')


def convert(raw, tagged):
    def note(m):
        body = m[1]
        if '<' in body or '>' in body:
            raise ValueError('nested markup in publisher note requires review')
        return '<note: ' + body + '>'
    text = NOTE.sub(note, raw)
    unknown = re.sub(TOKEN, '', text)
    if '<' in unknown or '>' in unknown:
        raise ValueError('unrecognised source markup')
    runs, pending, cursor = [], '', 0
    for m in TOKEN.finditer(text):
        pending += text[cursor:m.start()]
        cursor = m.end()
        if m[0].startswith('<note: '):
            if pending:
                runs.append({'w': pending, 's': '', 'i': [], 'g': []})
                pending = ''
            runs.append({'w': m[0], 's': '', 'i': [], 'g': []})
        elif m[1]:
            sid = m[1] + str(int(m[2]))
            if not (0 < int(m[2]) <= (5624 if m[1] == 'G' else 8674)):
                raise ValueError('Strong number outside lemma range')
            if pending.strip():
                runs.append({'w': pending, 's': '' if m[3] else sid,
                             'i': [sid] if m[3] else [], 'g': []})
                pending = ''
            elif runs and not runs[-1]['w'].startswith('<note: '):
                runs[-1]['w'] += pending
                pending = ''
                runs[-1]['i'].append(sid)
            else:
                raise ValueError('Strong marker with no scripture word')
        elif m[4]:
            if not runs or runs[-1]['w'].startswith('<note: '):
                raise ValueError('morphology with no scripture word')
            runs[-1]['g'].append(m[4])
    pending += text[cursor:]
    if pending:
        runs.append({'w': pending, 's': '', 'i': [], 'g': []})
    cleaned = ''.join(r['w'] for r in runs).strip()
    if tagged and runs:
        runs[0]['w'] = runs[0]['w'].lstrip()
        runs[-1]['w'] = runs[-1]['w'].rstrip()
        runs = [r for r in runs if r['w']]
        if ''.join(r['w'] for r in runs) != cleaned:
            raise ValueError('tagged / reading text mismatch')
    return cleaned, runs


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--db', type=Path, default=Path.home() / 'Documents/CodingProject/Yahwehdehua/app/build/bible.db')
    ap.add_argument('--project', type=Path, default=Path(__file__).resolve().parents[1])
    args = ap.parse_args()
    db = sqlite3.connect('file:' + str(args.db.resolve()) + '?mode=ro', uri=True)
    books = db.execute('select seq,code,name_en from books order by seq').fetchall()
    witness = json.loads((args.project / 'assets/kjv.json').read_text())
    names = list(dict.fromkeys(r['book'] for r in witness))
    if names != [r[2] for r in books]:
        raise ValueError('book order differs from KJV witness')
    mapping = {code: (seq, name) for seq, code, name in books}
    existing_ids = {r['id'] for r in witness}
    cjk_names = {}
    for suffix in ('', '-tr'):
        cjk = json.loads((args.project / f'assets/cuvs-yhwh{suffix}.json').read_text())
        cjk_names[suffix] = {int(r['id'][:3]): r['book'] for r in cjk}
    report = {'source_sha256': hashlib.sha256(args.db.read_bytes()).hexdigest(), 'editions': {}}
    payloads = {}
    for code, (source, expected, empty_expected, book_expected, note_expected) in EDITIONS.items():
        rows = db.execute('select book,chapter,verse,text from verses where version=?', (source,)).fetchall()
        rows.sort(key=lambda r: (mapping[r[0]][0], r[1], r[2]))
        if len(rows) != expected or sum(not r[3].strip() for r in rows) != empty_expected:
            raise ValueError(f'{source}: source row / absence count changed; review before import')
        notes = sum(len(NOTE.findall(r[3])) for r in rows)
        if notes != note_expected:
            raise ValueError(f'{source}: publisher apparatus count changed; review before import')
        out, tagged = [], {}
        for book, chapter, verse, raw in rows:
            if not raw.strip():
                continue
            seq, name = mapping[book]
            vid = f'{seq:03d}{chapter:03d}{verse:03d}'
            if vid not in existing_ids:
                raise ValueError(f'{source}: non-canonical reference {vid}')
            body, runs = convert(raw, code == 'sblgnt')
            out.append({'book': cjk_names['-tr' if code.endswith('-tr') else ''][seq] if code.startswith('cnet') else name, 'chapter': str(chapter), 'verse': str(verse), 'text': body, 'id': vid})
            if code == 'sblgnt':
                tagged.setdefault(name, {})[f'{chapter}:{verse}'] = runs
        if len(set(r['id'] for r in out)) != len(out) or len(set(r['book'] for r in out)) != book_expected:
            raise ValueError(f'{source}: duplicate IDs / wrong book coverage')
        report['editions'][code] = {'source': source, 'verses': len(out), 'books': book_expected,
                                  'notes': notes, 'source_empty_references': [
              f'{mapping[b][0]:03d}{c:03d}{v:03d}' for b,c,v,t in rows if not t.strip()]}
        payloads[code] = (out, tagged)
    # Validate the entire source before writing anything.
    for code, (out, tagged) in payloads.items():
        (args.project / f'assets/{code}.json').write_text(json.dumps(out, ensure_ascii=False, separators=(',', ':')) + '\n')
        for book, verses in (tagged.items() if 'assets/tagged/sblgnt/' in (args.project / 'pubspec.yaml').read_text() else []):
            folder = args.project / 'assets/tagged/sblgnt'
            folder.mkdir(parents=True, exist_ok=True)
            slug = book.lower().replace(' ', '_')
            (folder / f'{slug}.json').write_text(json.dumps(verses, ensure_ascii=False, separators=(',', ':')) + '\n')
    doc = args.project / 'docs/yahwehdehua-edition-import.json'
    doc.write_text(json.dumps(report, indent=2, ensure_ascii=False) + '\n')
    print(json.dumps(report['editions'], ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
