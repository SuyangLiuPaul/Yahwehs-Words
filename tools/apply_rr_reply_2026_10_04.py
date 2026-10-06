#!/usr/bin/env python3
"""和合本雅偉版: Pastor Raymond's reply of 2026-10-04 to our comparison sheet.

    tools/apply_rr_reply_2026_10_04.py [--write] [--assets assets]

THE NINTH THAW (see test/cuvs_yhwh_frozen_test.dart). The publisher side has
ruled, as in the eighth: he returned the sheet with a column "Use B" meaning
the printed 和合本 (信望爱) reading unless he wrote A. tools/rr_reply_2026_10_04.json
is that sheet, tables 0-2 of the docx, with his yellow highlights as ⟦ ⟧.

WHAT IS APPLIED
  * Table 3 rows (single-point differences, punctuation stripped) with the
    last column empty -> B. Marked "A" -> untouched. Marked 熔 (耶利米书 9:7)
    -> 熔, which is neither A (融) nor B (镕).
  * 简体 asset: B is read through opencc t2s, so a printed-edition variant
    glyph that has a simplified form (牠 → 它, 銲 → 焊) is NOT imported; only a
    change in wording, spelling or a missing/extra character is.
  * 繁體 asset: the same positions, B through opencc s2tw (printed glyphs such
    as 牠 銲 kept).
  * 耶和华 in a window is read as 雅伟 (this edition's divine-name notation);
    his yellow 耶和华 cells are the official DB's, not our text.
  * Table 1: 历代志下 10:6 简体 回覆 → 回复 (his suggestion; 繁體 keeps 回覆).
  * Table 0 (his 15 corrections) is already in the assets from earlier work;
    verified, not re-applied.

WHAT IS NOT APPLIED: any row whose B adds or removes a footnote (或译 / 原文是)
or whose window is not found exactly once. Those are printed, with the verse,
so a human can decide. Never guesses.
"""
import argparse, difflib, json, re, subprocess, sys
from pathlib import Path

NOTE = re.compile(r'<[^>]*>')
MARK = re.compile(r'\[(?:雅[伟偉]|耶[稣穌]|基督)\]')
PUN = set('，。、；：！？“”‘’「」『』（）〔〕…—·─ "\'()[]:;,.!?《》\n<>')
BOOKS = {'创世记': '创世纪', '創世記': '創世紀'}


def occ(cmd, texts):
    out = subprocess.run(['opencc', '-c', cmd], input='\n'.join(texts),
                         capture_output=True, text=True, check=True).stdout
    return out.split('\n')[:len(texts)]


# Printed-edition variant glyphs that opencc t2s leaves alone. Read as their
# plain forms when comparing, so they never count as a difference.
VARIANT = str.maketrans({'著': '着', '啣': '衔', '衞': '卫', '牠': '它', '銲': '焊',
                         '搧': '扇', '拚': '拼', '籐': '藤', '羢': '绒', '彷': '仿',
                         '倣': '仿', '舖': '铺', '僮': '童', '搥': '捶', '摀': '捂',
                         '嗐': '咳', '嗳': '哎', '铇': '刨', '逿': '趟', '毘': '毗',
                         '呵': '啊', '甚': '什'})   # 甚/什: his own 用字 table calls 什么/甚麼 a habit, not a fault


def kept(text):
    """Characters of `text` that a sheet window can contain, with their index."""
    chars, idx, i = [], [], 0
    while i < len(text):
        if text[i] == '<':
            j = text.find('>', i)
            if j != -1:
                i = j + 1
                continue
        m = MARK.match(text, i)
        if m:  # the marker is notation; 雅伟 itself stays visible text
            i = m.end()
            continue
        if text[i] not in PUN:
            chars.append(text[i]); idx.append(i)
        i += 1
    return ''.join(chars), idx


def rows(sheet, tr):
    out = []
    for r in sheet[2][1:]:
        m = re.match(r'(\S+?)\s*(\d+):(\d+)$', r[0].strip())
        bk = m.group(1)
        a = r[1].replace('⟦', '').replace('⟧', '')
        b = r[2].replace('⟦', '').replace('⟧', '')
        dec = (r[3] or '').replace('⟦', '').replace('⟧', '').strip()
        out.append(dict(book=bk, ch=int(m.group(2)), vs=int(m.group(3)), a=a, b=b, dec=dec))
    return out


# Rows whose window the sheet cut in a way a diff cannot follow; read by hand.
MANUAL = [
    ('使徒行传', 24, 2, '就开始控告他说', '就告他说'),         # B: 帖土罗就告他说
    ('使徒行传', 27, 33, '悬望一直挨饿不', '悬望忍饿不'),  # B: 悬望忍饿不吃甚么
    ('耶利米书', 9, 7, '融化熬炼', '熔化熬炼'),             # his own word 熔 (A 融, B 镕)
    ('使徒行传', 8, 27, '埃提阿伯<note', '衣索匹亚<note'),   # B prints the gloss inline; ours is the <note>
    ('使徒行传', 8, 27, '干大基', '甘大基'),
]


def norm_name(s, tr):
    return s.replace('耶和華' if tr else '耶和华', '雅偉' if tr else '雅伟')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--write', action='store_true')
    ap.add_argument('--assets', default='assets')
    ap.add_argument('--sheet', default=str(Path(__file__).with_name('rr_reply_2026_10_04.json')))
    args = ap.parse_args()
    sheet = json.load(open(args.sheet))
    R = rows(sheet, False)
    for tr, fname in ((False, 'cuvs-yhwh.json'), (True, 'cuvs-yhwh-tr.json')):
        path = Path(args.assets) / fname
        data = json.load(open(path))
        names = [v['book'] for v in data]
        PRINT = json.load(open(Path(__file__).with_name('rr_reply_2026_10_04_print.json')))
        order = list(dict.fromkeys(names))
        byref = {}
        for v in data:
            byref[(v['book'], int(v['chapter']), int(v['verse']))] = v
        # simplified book names in the sheet -> this asset's book names
        sbooks = list(dict.fromkeys(r['book'] for r in R))
        if tr:
            conv = {k: {'創世記': '創世紀', '啟示錄': '啓示錄'}.get(v, v) for k, v in zip(sbooks, occ('s2tw', sbooks))}
        else:
            conv = {b: BOOKS.get(b, b) for b in sbooks}
        HK = str.maketrans({'說': '説', '裡': '裏', '著': '着', '衛': '衞', '麽': '麼'})
        applied, skipped, same, kept_a = 0, [], 0, 0
        Bs = [x.translate(VARIANT) for x in occ('t2s', [r['b'] for r in R])]
        for r, b in zip(R, Bs):
            bk = conv[r['book']]
            v = byref.get((bk, r['ch'], r['vs']))
            if v is None:
                skipped.append((r, 'verse not found')); continue
            if r['dec'] == 'A':
                kept_a += 1; continue
            pk = f"{order.index(bk)}:{r['ch']}:{r['vs']}"
            printed = PRINT.get(pk)
            if not printed:
                skipped.append((r, 'no printed text')); continue
            text = v['text']
            ks, idx = kept(text)
            sk = occ('t2s', [ks])[0].translate(VARIANT) if tr else ks.translate(VARIANT)
            if len(sk) != len(ks):
                skipped.append((r, 't2s changed the length')); continue
            na, nb = (norm_name(''.join(c for c in x if c not in PUN), False).translate(VARIANT)
                      for x in (r['a'], b))
            if r['dec'] == '熔':
                nb = na.replace('融', '熔')
            if re.search(r'或译|原文是', nb) or re.search(r'或译|原文是', na):
                skipped.append((r, 'footnote differs')); continue
            if na == nb:
                same += 1; continue            # a variant glyph only
            # the printed verse, plain: no punctuation, divine name as this edition writes it
            pt = ''.join(c for c in printed.replace('耶和華', '雅偉') if c not in PUN)
            pskel = occ('t2s', [pt])[0].translate(VARIANT)
            if len(pskel) != len(pt):
                skipped.append((r, 'printed t2s changed the length')); continue
            if sk.count(na) != 1:
                if sk.count(nb[2:-2]) >= 1 and sk.count(na[2:-2]) == 0:
                    same += 1; continue        # already B
                skipped.append((r, f'window found {sk.count(na)}x')); continue
            lo = sk.index(na)
            hi = lo + len(na)
            sm = difflib.SequenceMatcher(None, sk, pskel, autojunk=False)
            ops = [o for o in sm.get_opcodes() if o[0] != 'equal'
                   and o[1] < hi and (o[2] > lo or (o[0] == 'insert' and o[1] >= lo))]
            if not ops:
                same += 1; continue
            new = text
            ok = True
            for t, i1, i2, j1, j2 in reversed(ops):
                rep_s = pskel[j1:j2]
                # an op must be something the sheet itself shows: what goes in is in B,
                # what comes out is in A
                if len(rep_s) > 4 or len(sk[i1:i2]) > 4:
                    ok = False; break      # a footnote printed inline, not a wording change
                if (rep_s and rep_s not in nb) or (sk[i1:i2] and sk[i1:i2] not in na):
                    ok = False; break
                rep = pt[j1:j2]
                if not tr:
                    rep = rep_s
                else:
                    rep = rep.translate(HK)
                if t == 'insert':
                    pos = idx[i1] if i1 < len(idx) else len(new)
                    new = new[:pos] + rep + new[pos:]
                else:
                    a0, a1 = idx[i1], idx[i2 - 1] + 1
                    if a1 - a0 != i2 - i1:
                        ok = False; break
                    new = new[:a0] + rep + new[a1:]
            if not ok:
                skipped.append((r, 'printed differs from the sheet here — not guessed')); continue
            v['text'] = new
            applied += 1
            print(f"{'繁' if tr else '简'} {r['book']} {r['ch']}:{r['vs']}\n   {text}\n → {new}")
        for bk0, ch, vs, old, new_ in MANUAL:
            v = byref[(conv.get(bk0, bk0), ch, vs)]
            o, n_ = ((occ('s2t', [old])[0].translate(HK).replace('捱', '挨'), occ('s2t', [new_])[0].translate(HK).replace('捱', '挨')) if tr else (old, new_))
            if o in v['text']:
                print(f"{'繁' if tr else '简'} {bk0} {ch}:{vs} {o} → {n_}")
                v['text'] = v['text'].replace(o, n_, 1); applied += 1
            elif n_ in v['text']:
                pass
            else:
                skipped.append(({'book': bk0, 'ch': ch, 'vs': vs}, 'manual: old text not found'))
        if not tr:
            v = byref[('历代志下', 10, 6)]
            if '回覆' in v['text']:
                print('简 历代志下 10:6 回覆→回复'); v['text'] = v['text'].replace('回覆', '回复'); applied += 1
        print(f'[{fname}] applied {applied}, already-B or variant-only {same}, kept A {kept_a}, skipped {len(skipped)}')
        for r, why in skipped:
            print(f"   SKIP {r['book']} {r['ch']}:{r['vs']} ({why}): {byref.get((conv[r['book']], r['ch'], r['vs']), {}).get('text','')}")
        if args.write:
            path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
            print('WROTE', path)
    return 0


if __name__ == '__main__':
    sys.exit(main())
