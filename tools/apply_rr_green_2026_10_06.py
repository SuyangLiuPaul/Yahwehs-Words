#!/usr/bin/env python3
"""和合本雅偉版: the second round of Pastor Raymond's markup (2026-10-05/06).

    tools/apply_rr_green_2026_10_06.py [--write] [--assets assets]

He returned the combined report with the NEW remarks in green and the old
ones in yellow, and wrote that he had checked other printed Chinese Bibles,
found the wording differs between them, and "made some changes back". Read
from the docx run by run (highlight = green), that is eight verses:

  * 列王纪下 10:24   安派 -> 安排      (back: the ninth thaw had changed 排 to 派)
  * 以斯帖记 6:7     尊荣的 -> 尊荣的人 (back: keep 人)
  * 以西结书 23:44   茍合 -> 苟合      (back)
  * 路加福音 23:39   讥笑 -> 讥诮      (back)
  * 士师记 12:4      以法莲，人是 -> 以法莲人，是   (his own wording)
  * 使徒行传 26:16   站着，我 -> 站着！我          (his B row, new)
  * 使徒行传 28:17   做为囚犯…被交 -> 被锁绑…解    (his reply: B)
  * 哥林多后书 10:13 搆 -- already in the assets; checked, not changed.

Traditional gets the same edit, written out here rather than converted, so
no character with two Traditional forms is ever chosen by a script. The
tagged (Strong's) layer is edited at the same positions with a character
diff; where it already reads as the new text it is left alone.
Never guesses: an edit whose old text is not found exactly once is refused.
"""
import argparse, difflib, json, re, sys
from pathlib import Path

# (book id 3 digits, chapter, verse, simplified old, simplified new, traditional old, traditional new)
EDITS = [
    ('012', 10, 24, '耶户先安派八十人', '耶户先安排八十人', '耶戶先安派八十人', '耶戶先安排八十人'),
    ('017', 6, 7, '王所喜悦尊荣的，', '王所喜悦尊荣的人，', '王所喜悦尊榮的，', '王所喜悦尊榮的人，'),
    ('026', 23, 44, '二淫妇茍合', '二淫妇苟合', '二淫婦茍合', '二淫婦苟合'),
    ('042', 23, 39, '有一个讥笑他', '有一个讥诮他', '有一個譏笑他', '有一個譏誚他'),
    ('007', 12, 4, '击杀以法莲，人是因', '击杀以法莲人，是因', '擊殺以法蓮，人是因', '擊殺以法蓮人，是因'),
    ('044', 26, 16, '你起来站着，我特意', '你起来站着！我特意', '你起來站着，我特意', '你起來站着！我特意'),
    ('044', 28, 17, '却做为囚犯，从耶路撒冷被交在罗马人的手里', '却被锁绑，从耶路撒冷解在罗马人的手里',
     '卻做為囚犯，從耶路撒冷被交在羅馬人的手裏', '卻被鎖綁，從耶路撒冷解在羅馬人的手裏'),
]
FILES = ['genesis', 'exodus', 'leviticus', 'numbers', 'deuteronomy', 'joshua', 'judges', 'ruth', '1_samuel', '2_samuel',
         '1_kings', '2_kings', '1_chronicles', '2_chronicles', 'ezra', 'nehemiah', 'esther', 'job', 'psalms', 'proverbs',
         'ecclesiastes', 'song_of_solomon', 'isaiah', 'jeremiah', 'lamentations', 'ezekiel', 'daniel', 'hosea', 'joel',
         'amos', 'obadiah', 'jonah', 'micah', 'nahum', 'habakkuk', 'zephaniah', 'haggai', 'zechariah', 'malachi',
         'matthew', 'mark', 'luke', 'john', 'acts', 'romans', '1_corinthians', '2_corinthians', 'galatians', 'ephesians',
         'philippians', 'colossians', '1_thessalonians', '2_thessalonians', '1_timothy', '2_timothy', 'titus', 'philemon',
         'hebrews', 'james', '1_peter', '2_peter', '1_john', '2_john', '3_john', 'jude', 'revelation']


def tagged_edit(chunks, old, new):
    """Apply old -> new to the concatenated text of `chunks` (dicts with 'w'), one character op at a time.

    A replaced character stays in the chunk it was in (so its Strong's number keeps pointing at it);
    an inserted one joins the chunk before it.
    """
    text = ''.join(c['w'] for c in chunks)
    if old not in text:
        return False
    if text.count(old) != 1:
        raise SystemExit(f'tagged window not unique: {old}')
    start = text.index(old)

    def locate(pos):
        run = 0
        for i, c in enumerate(chunks):
            if pos < run + len(c['w']):
                return i, pos - run
            run += len(c['w'])
        raise SystemExit('position past the end')

    ops = difflib.SequenceMatcher(None, old, new, autojunk=False).get_opcodes()
    for tag, i1, i2, j1, j2 in reversed(ops):
        if tag == 'equal':
            continue
        a, b = start + i1, start + i2
        ins = new[j1:j2]
        if tag == 'insert':
            ci, off = locate(a - 1)
            chunks[ci]['w'] = chunks[ci]['w'][:off + 1] + ins + chunks[ci]['w'][off + 1:]
            continue
        ci, off = locate(a)
        for k in range(b - 1, a - 1, -1):
            c2, o2 = locate(k)
            chunks[c2]['w'] = chunks[c2]['w'][:o2] + chunks[c2]['w'][o2 + 1:]
        if ins:
            chunks[ci]['w'] = chunks[ci]['w'][:off] + ins + chunks[ci]['w'][off:]
    assert ''.join(c['w'] for c in chunks).count(new) == 1, (old, new)
    return True


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--write', action='store_true')
    ap.add_argument('--assets', default='assets')
    args = ap.parse_args()
    A = Path(args.assets)
    changed = 0
    for tr, fname, tdir in ((False, 'cuvs-yhwh.json', 'cuvs-yhwh'), (True, 'cuvs-yhwh-tr.json', 'cuvs-yhwh-tr')):
        data = json.load(open(A / fname, encoding='utf-8'))
        byid = {v['id']: v for v in data}
        raw = (A / fname).read_text(encoding='utf-8')
        for bk, ch, vs, so, sn, to, tn in EDITS:
            old, new = (to, tn) if tr else (so, sn)
            vid = '%s%03d%03d' % (bk, ch, vs)
            t = byid[vid]['text']
            if new in t and old not in t:
                print(f'{fname} {vid}: already reads {new!r}')
            else:
                if t.count(old) != 1:
                    raise SystemExit(f'{fname} {vid}: {old!r} found {t.count(old)} times')
                byid[vid]['text'] = t.replace(old, new)
                changed += 1
                print(f'{fname} {vid}: {old!r} -> {new!r}')
            # tagged layer
            tf = A / 'tagged' / tdir / (FILES[int(bk) - 1] + '.json')
            if tf.exists():
                tj = json.load(open(tf, encoding='utf-8'))
                key = f'{ch}:{vs}'
                if key in tj:
                    done = tagged_edit(tj[key], old, new)
                    cur = ''.join(c['w'] for c in tj[key])
                    state = 'edited' if done else ('already new' if new in cur else 'NOT FOUND')
                    print(f'   tagged {tdir}/{tf.name} {key}: {state}')
                    if done and args.write:
                        tf.write_text(json.dumps(tj, ensure_ascii=False, separators=(',', ':')), encoding='utf-8')
        if args.write:
            # keep the file's own formatting: re-dump the way it was written
            sample = raw[:200]
            indent = 2 if raw.startswith('[\n') else None
            out = json.dumps(data, ensure_ascii=False, indent=indent, separators=(',', ': ') if indent else (',', ':'))
            (A / fname).write_text(out + ('\n' if raw.endswith('\n') else ''), encoding='utf-8')
    print('edits applied:', changed, '(dry run)' if not args.write else '(written)')


if __name__ == '__main__':
    main()
