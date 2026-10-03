#!/usr/bin/env python3
"""Mirror the 2026-10-04 reading-text edits into the Simplified tagged layer.

    tools/mirror_rr_reply_to_tagged.py <old-cuvs-yhwh.json> [--write]

`assets/tagged/cuvs-yhwh/` is a separate import of the same translation; when
tools/apply_rr_reply_2026_10_04.py changes a reading verse, the Originals
sheet's guard (TaggedTextService.coversVerse) hides the tagged line unless the
runs still say everything the verse says. This replays each character edit
(old reading text -> new reading text) onto the runs, so the line stays.

Only a verse whose tagged runs equalled the OLD reading text (punctuation and
notes aside) is touched; one that already differed is printed and left alone.
Only `w` is edited; Strong's numbers are never touched. An inserted character
joins the run of the character before it; a run emptied by a deletion is
dropped only if it carries no number, else kept empty-free is impossible, so
the verse is reported instead. After this, run tools/derive_tagged_traditional.py.
"""
import argparse, difflib, json, re, sys
from pathlib import Path

NOTE = re.compile(r'<[^>]*>')
MARK = re.compile(r'\[(?:雅[伟偉]|耶[稣穌]|基督)\]')
PUN = set('，。、；：！？“”‘’「」『』（）〔〕…—·─ "\'()[]:;,.!?《》\n<>')
BOOK_FILES = None


def ks(text):
    return ''.join(c for c in MARK.sub('', NOTE.sub('', text)) if c not in PUN)


def style_of(text):
    """How a tagged file is serialised: (indent or None, trailing newline)."""
    obj = json.loads(text)
    for indent in (None, 2, 1, 4):
        seps = (',', ':') if indent is None else None
        out = json.dumps(obj, ensure_ascii=False, indent=indent, separators=seps)
        for nl in ('', '\n'):
            if out + nl == text:
                return indent, nl
    sys.exit('unrecognised tagged file formatting')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('old')
    ap.add_argument('--write', action='store_true')
    ap.add_argument('--assets', default='assets')
    a = ap.parse_args()
    old = {v['id']: v['text'] for v in json.load(open(a.old))}
    new = {v['id']: v for v in json.load(open(Path(a.assets) / 'cuvs-yhwh.json'))}
    changed = [i for i in new if old.get(i) != new[i]['text']]
    # book file per verse id: files are named by book; find through the id's book number
    order = list(dict.fromkeys(v['book'] for v in new.values()))
    files = sorted((Path(a.assets) / 'tagged' / 'cuvs-yhwh').glob('*.json'))
    byname = {}
    for f in files:
        byname[f.stem] = f
    data, touched, skipped, done, styles = {}, set(), [], 0, {}
    # map book index -> file by reading each file's first key? files are keyed "ch:vs" only,
    # so use canonical order of the file stems.
    CANON = ['genesis', 'exodus', 'leviticus', 'numbers', 'deuteronomy', 'joshua', 'judges', 'ruth', '1_samuel', '2_samuel', '1_kings', '2_kings', '1_chronicles', '2_chronicles', 'ezra', 'nehemiah', 'esther', 'job', 'psalms', 'proverbs', 'ecclesiastes', 'song_of_solomon', 'isaiah', 'jeremiah', 'lamentations', 'ezekiel', 'daniel', 'hosea', 'joel', 'amos', 'obadiah', 'jonah', 'micah', 'nahum', 'habakkuk', 'zephaniah', 'haggai', 'zechariah', 'malachi', 'matthew', 'mark', 'luke', 'john', 'acts', 'romans', '1_corinthians', '2_corinthians', 'galatians', 'ephesians', 'philippians', 'colossians', '1_thessalonians', '2_thessalonians', '1_timothy', '2_timothy', 'titus', 'philemon', 'hebrews', 'james', '1_peter', '2_peter', '1_john', '2_john', '3_john', 'jude', 'revelation']
    missing = [c for c in CANON if c not in byname]
    if missing:
        sys.exit(f'unknown file stems: {missing} among {sorted(byname)}')
    for vid in changed:
        b, ch, vs = int(vid[:3]) - 1, int(vid[3:6]), int(vid[6:])
        stem = CANON[b]
        if stem not in data:
            txt = open(byname[stem], encoding='utf-8').read()
            styles[stem] = style_of(txt)
            data[stem] = json.loads(txt)
        runs = data[stem].get(f'{ch}:{vs}')
        if not runs:
            skipped.append((vid, 'no tagged verse')); continue
        so, sn = ks(old[vid]), ks(new[vid]['text'])
        # per kept char: (run, index in w)
        pos = []
        depth = 0
        for ri, r in enumerate(runs):
            w = r['w']
            for ci, c in enumerate(w):
                if c == '〔':
                    depth += 1
                elif c == '〕':
                    depth = max(0, depth - 1)
                elif c not in PUN and depth == 0:
                    pos.append((ri, ci))
        tag = ''.join(runs[ri]['w'][ci] for ri, ci in pos)
        # a note printed inline as 〔…〕 contributes its text to `tag`; drop it for comparison
        tag_plain = ''.join(c for c in re.sub(r'〔[^〕]*〕', '', ''.join(r['w'] for r in runs)) if c not in PUN)
        if tag_plain == sn:
            continue
        if tag_plain != so or tag != so:
            skipped.append((vid, 'tagged runs differ from the old reading text' if tag_plain != so else 'inline note in the runs')); continue
        sm = difflib.SequenceMatcher(None, so, sn, autojunk=False)
        ops = [o for o in sm.get_opcodes() if o[0] != 'equal']
        ws = [list(r['w']) for r in runs]
        ok = True
        for t, i1, i2, j1, j2 in reversed(ops):
            rep = sn[j1:j2]
            if t == 'insert':
                if i1 == 0:
                    ri, ci = pos[0]; ws[ri].insert(ci, rep)
                else:
                    ri, ci = pos[i1 - 1]; ws[ri].insert(ci + 1, rep)
            else:
                cells = pos[i1:i2]
                for k, (ri, ci) in enumerate(cells):
                    ws[ri][ci] = rep if k == 0 else ''
                    # a single character cell holds the whole replacement (may be 0..n chars)
                if t == 'replace' and not rep:
                    pass
        new_w = [''.join(x) for x in ws]
        dropped = [r for w, r in zip(new_w, runs) if not w and r.get('s')]
        if dropped:
            # the printed text no longer has the word, so its number goes with it; say so
            print('  DROPPED run(s)', vid, [(r['s']) for r in dropped])
        for r, w in zip(runs, new_w):
            r['w'] = w
        out = []
        for r in runs:
            if r['w'] and not any('\u3400' <= c <= '\u9fff' for c in r['w']) and r.get('s') and out:
                out[-1]['w'] += r['w']      # only punctuation is left: it joins the word before
                continue
            if r['w']:
                out.append(r)
        data[stem][f'{ch}:{vs}'] = out
        touched.add(stem)
        done += 1
    print(f'changed reading verses {len(changed)}; tagged edited {done}; skipped {len(skipped)}')
    for vid, why in skipped:
        print('  SKIP', vid, why)
    if a.write:
        for stem in touched:
            indent, nl = styles[stem]
            seps = (',', ':') if indent is None else None
            byname[stem].write_text(json.dumps(data[stem], ensure_ascii=False, indent=indent, separators=seps) + nl, encoding='utf-8')
            print('WROTE', byname[stem])


if __name__ == '__main__':
    main()
