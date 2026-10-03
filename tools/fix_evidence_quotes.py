#!/usr/bin/env python3
"""Make the scripture quotations inside assets/bible_evidence.json exact.

2026-10-03, 圣经证据 audit (owner: 「经文一定要准确」). The evidence text quotes
scripture in 'single quotes' (English) and 「…」 (Chinese). Measured on the
Words copy: 311 of 392 English quotes matched no English Bible the app ships —
they are NIV wording (NIV was removed from the app for licensing) and say
"the LORD" where the app's own editions say "Yahweh"; 155 of 288 Chinese quotes
differed from 和合本 (e.g. 以赛亚书 40:8 凋谢 vs 和合本 凋残).

What this does, per quote: find the verse range of the CITED chapter(s) that the
quote is closest to, and replace the quoted span with that range's exact text
from the app's own edition (English: bsb-yhwh.json; 简体: cuvs-yhwh.json; 繁體:
cuvs-yhwh-tr.json of the SAME repo, so each app keeps its own orthography).

It only rewrites when it is safe — the guard is deliberate, because a fuzzy
match to the wrong verse would put wrong scripture in a Bible app:
  * similarity >= MIN_SCORE,
  * every number in the old quote is in the new one and vice versa,
  * the new text has no editor's <note:…> markup,
  * length within 0.6x–1.6x of the old.
Anything else is LEFT AS IS and listed in the report for a human to judge
(many are not scripture at all: inscriptions, Josephus, translations of seals).
A quote that is already exact in ANY shipped English edition is left alone.
Idempotent: a second run changes nothing.

Usage:
    tools/fix_evidence_quotes.py            # dry run, prints counts + report path
    tools/fix_evidence_quotes.py --write
"""
import difflib
import json
import os
import re
import sys
from collections import Counter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, 'assets')
TARGET = os.path.join(ASSETS, 'bible_evidence.json')
REPORT = os.path.join(ROOT, 'build', 'evidence_quote_report.json')
MIN_SCORE_EN = 0.80
MIN_SCORE_ZH = 0.85

BOOKS = ("Genesis,Exodus,Leviticus,Numbers,Deuteronomy,Joshua,Judges,Ruth,1 Samuel,2 Samuel,"
         "1 Kings,2 Kings,1 Chronicles,2 Chronicles,Ezra,Nehemiah,Esther,Job,Psalms,Proverbs,"
         "Ecclesiastes,Song of Solomon,Isaiah,Jeremiah,Lamentations,Ezekiel,Daniel,Hosea,Joel,"
         "Amos,Obadiah,Jonah,Micah,Nahum,Habakkuk,Zephaniah,Haggai,Zechariah,Malachi,Matthew,"
         "Mark,Luke,John,Acts,Romans,1 Corinthians,2 Corinthians,Galatians,Ephesians,"
         "Philippians,Colossians,1 Thessalonians,2 Thessalonians,1 Timothy,2 Timothy,Titus,"
         "Philemon,Hebrews,James,1 Peter,2 Peter,1 John,2 John,3 John,Jude,Revelation").split(',')
ALIAS = {'Psalm': 'Psalms', 'Song of Songs': 'Song of Solomon'}
BI = {b: i + 1 for i, b in enumerate(BOOKS)}
ZB = {'创世记': 1, '出埃及记': 2, '利未记': 3, '民数记': 4, '申命记': 5, '约书亚记': 6, '士师记': 7, '路得记': 8,
      '撒母耳记上': 9, '撒母耳记下': 10, '列王纪上': 11, '列王纪下': 12, '历代志上': 13, '历代志下': 14,
      '以斯拉记': 15, '尼希米记': 16, '以斯帖记': 17, '约伯记': 18, '诗篇': 19, '箴言': 20, '传道书': 21,
      '雅歌': 22, '以赛亚书': 23, '耶利米书': 24, '耶利米哀歌': 25, '以西结书': 26, '但以理书': 27,
      '何西阿书': 28, '约珥书': 29, '阿摩司书': 30, '俄巴底亚书': 31, '约拿书': 32, '弥迦书': 33, '那鸿书': 34,
      '哈巴谷书': 35, '西番雅书': 36, '哈该书': 37, '撒迦利亚书': 38, '玛拉基书': 39, '马太福音': 40,
      '马可福音': 41, '路加福音': 42, '约翰福音': 43, '使徒行传': 44, '罗马书': 45, '哥林多前书': 46,
      '哥林多后书': 47, '加拉太书': 48, '以弗所书': 49, '腓立比书': 50, '歌罗西书': 51, '帖撒罗尼迦前书': 52,
      '帖撒罗尼迦后书': 53, '提摩太前书': 54, '提摩太后书': 55, '提多书': 56, '腓利门书': 57, '希伯来书': 58,
      '雅各书': 59, '彼得前书': 60, '彼得后书': 61, '约翰一书': 62, '约翰二书': 63, '约翰三书': 64,
      '犹大书': 65, '启示录': 66}
ZT_BOOKS = None  # zh-Hant refs are matched through the Simplified names after conversion of the book part only

# (id, language-field) quotes that are NOT scripture although they sit next to a reference.
SKIP_IDS = {
    # The quoted wording is the INSCRIPTION's, which differs from scripture on purpose.
    'ketef_hinnom_priestly_blessing', 'ketef_hinnom_scrolls', 'stele_of_zakkur',
    'hezekiah_royal_seal', 'road_to_emmaus', 'daniel_prophecies_accuracy',
}

ALT = '|'.join(sorted((re.escape(b) for b in list(BI) + list(ALIAS)), key=len, reverse=True))
REF_EN = re.compile(r'\b(' + ALT + r')\s+(\d+)(?::(\d+)(?:[-–](?:(\d+):)?(\d+))?)?')
HANS = re.compile(r'[一-鿿]')
TOK = re.compile(r'\S+')


def load(name):
    p = os.path.join(ASSETS, name)
    if not os.path.exists(p):
        return None
    out = {}
    for r in json.load(open(p, encoding='utf-8')):
        if r.get('id'):
            out[r['id']] = r['text']
    return out


class Bible:
    def __init__(self, table):
        self.t = table
        self.cache = {}

    def chapter(self, b, c):
        k = (b, c)
        if k not in self.cache:
            self.cache[k] = sorted((int(i[6:]), t) for i, t in self.t.items()
                                   if int(i[:3]) == b and int(i[3:6]) == c)
        return self.cache[k]


def tokn(w):
    return re.sub(r"[^a-z0-9']+", '', w.lower().replace('’', "'").replace('‘', "'"))


def nstr(s):
    return ' '.join(x for x in (tokn(w) for w in s.replace('—', ' ').split()) if x)


def numbers(s):
    return sorted(re.findall(r'\d+', s))


def en_refs(text):
    return [(m.start(), BI[ALIAS.get(m.group(1), m.group(1))], int(m.group(2))) for m in REF_EN.finditer(text)]


def zh_refs(text):
    out = []
    for m in re.finditer(r'([一-鿿]{1,8})\s*(\d+)(?::(\d+))?', text):
        for k in sorted(ZB, key=len, reverse=True):
            if m.group(1).endswith(k):
                out.append((m.start(), ZB[k], int(m.group(2))))
                break
    return out


def en_quotes(t):
    for m in re.finditer(r"(?<![A-Za-z])['‘\"“]((?:[^'‘’\"“”]|(?<=[A-Za-z])['’](?=[A-Za-z])){25,800}?)['’\"”](?![A-Za-z])", t):
        yield m.start(), m.start(1), m.end(1), m.group(1)


def exact_in_any(q, near, bibles):
    frs = [nstr(x) for x in re.split(r'\.\.\.|…', q) if len(x.split()) >= 3]
    if not frs:
        return False
    for bb in bibles:
        if all(any(f in nstr(' '.join(t for _, t in bb.chapter(b, c))) for _, b, c in near) for f in frs):
            return True
    return False


def en_align(q, near, bsb):
    out, worst, src = [], 1.0, set()
    for f in re.split(r'(\s*(?:\.\.\.|…)\s*)', q):
        if re.fullmatch(r'\s*(?:\.\.\.|…)\s*', f) or len(f.split()) < 3:
            out.append(f)
            continue
        qt = [x for x in (tokn(w) for w in f.split()) if x]
        best = (0, None)
        for _, b, c in near:
            vs = bsb.chapter(b, c)
            for i in range(len(vs)):
                toks = []
                for j in range(i, min(len(vs), i + 5)):
                    toks += TOK.findall(vs[j][1])
                    r = difflib.SequenceMatcher(None, qt, [x for x in map(tokn, toks) if x], autojunk=False).ratio()
                    if r > best[0]:
                        best = (r, (b, c, vs[i][0], vs[j][0], list(toks)))
        if best[1] is None:
            return 0, q, []
        r, (b, c, v1, v2, toks) = best
        nt = [(k, tokn(w)) for k, w in enumerate(toks) if tokn(w)]
        bl = [m for m in difflib.SequenceMatcher(None, qt, [x for _, x in nt], autojunk=False).get_matching_blocks() if m.size]
        if not bl:
            return 0, q, []
        s, e = nt[bl[0].b][0], nt[bl[-1].b + bl[-1].size - 1][0]
        if bl[0].a > 0:  # quote starts with words the edition does not have: go back to the sentence start
            while s > 0 and not re.search(r"[.!?]['’”\"]*$", toks[s - 1]):
                s -= 1
        if len(qt) - (bl[-1].a + bl[-1].size) >= 1:
            while e < len(toks) - 1 and not re.search(r"[.!?]['’”\"]*$", toks[e]):
                e += 1
        span = ' '.join(toks[s:e + 1]).replace('’', "'").replace('‘', "'").replace('“', '"').replace('”', '"')
        for qc_ in ('"', "'"):  # drop an unbalanced edge quote mark that belongs to the surrounding verse
            if span.startswith(qc_) and span.count(qc_) % 2 == 1 and qc_ != "'" or (qc_ == "'" and span.startswith("'") and not re.search(r"[A-Za-z]'", span[1:]) and span.count("'") % 2 == 1):
                span = span[1:]
            if span.endswith(qc_) and span.count(qc_) % 2 == 1 and qc_ == '"':
                span = span[:-1]
        if f.lstrip()[:1].isupper() and span[:1].islower():
            span = span[:1].upper() + span[1:]
        out.append(f[:len(f) - len(f.lstrip())] + span + f[len(f.rstrip()):])
        worst = min(worst, r)
        src.add((b, c, v1, v2))
    return worst, ''.join(out), sorted(src)


def zh_exact(q, near, bb):
    frs = [x for x in (''.join(HANS.findall(p)) for p in re.split(r'……|⋯⋯|\.\.\.|…|⋯', q)) if len(x) >= 6]
    if not frs:
        return False
    for _, b, c in near:
        tc = ''.join(HANS.findall(''.join(t for _, t in bb.chapter(b, c))))
        if all(f in tc for f in frs):
            return True
    return False


def zh_align(q, near, bb):
    out, worst, src = [], 1.0, set()
    for f in re.split(r'(\s*(?:……|⋯⋯|\.\.\.|…|⋯)\s*)', q):
        qc = ''.join(HANS.findall(f))
        if re.fullmatch(r'\s*(?:……|⋯⋯|\.\.\.|…|⋯)\s*', f) or len(qc) < 6:
            out.append(f)
            continue
        best = (0, None)
        for _, b, c in near:
            vs = bb.chapter(b, c)
            for i in range(len(vs)):
                txt = ''
                for j in range(i, min(len(vs), i + 4)):
                    txt += vs[j][1]
                    r = difflib.SequenceMatcher(None, qc, ''.join(HANS.findall(txt)), autojunk=False).ratio()
                    if r > best[0]:
                        best = (r, (b, c, vs[i][0], vs[j][0], txt))
        if best[1] is None:
            return 0, q, []
        r, (b, c, v1, v2, txt) = best
        idx = [k for k, ch in enumerate(txt) if HANS.match(ch)]
        tc = ''.join(txt[k] for k in idx)
        bl = [m for m in difflib.SequenceMatcher(None, qc, tc, autojunk=False).get_matching_blocks() if m.size]
        if not bl:
            return 0, q, []
        while len(bl) > 1 and bl[0].size <= 2 and bl[1].b - (bl[0].b + bl[0].size) >= 3:
            bl = bl[1:]
        s, e = idx[bl[0].b], idx[bl[-1].b + bl[-1].size - 1]
        if len(qc) - (bl[-1].a + bl[-1].size) >= 2:
            m2 = re.search(r'[。！？；]', txt[e:])
            e = e + m2.start() if m2 else len(txt) - 1
        elif e + 1 < len(txt) and txt[e + 1] in '。！？，；：' and f.rstrip()[-1:] in '。！？，；：':
            e += 1
        span = txt[s:e + 1].strip('「」『』“”')
        out.append(f[:len(f) - len(f.lstrip())] + span + f[len(f.rstrip()):])
        worst = min(worst, r)
        src.add((b, c, v1, v2))
    return worst, ''.join(out), sorted(src)


def safe(old, new, score, floor):
    if score < floor or new == old:
        return False
    if '<note' in new or numbers(old) != numbers(new):
        return False
    if new.count('“') != new.count('”') or new.count('"') % 2:
        return False
    return 0.6 <= len(new) / max(1, len(old)) <= 1.6


def main():
    write = '--write' in sys.argv
    data = json.load(open(TARGET, encoding='utf-8'))
    bsb = Bible(load('bsb-yhwh.json'))
    en_check = [bsb] + [Bible(t) for t in (load(n) for n in ('kjv.json', 'asv-yhwh.json', 'csb.json', 'leb.json', 'nasb.json', 'net.json')) if t]
    zh = Bible(load('cuvs-yhwh.json'))
    zt = Bible(load('cuvs-yhwh-tr.json'))
    stats, report = Counter(), []
    for e in data['evidences']:
        # hazor_destruction stored its English paragraphs as a JSON list while every other
        # field is one string. The model joins a list with a blank line (bible_evidence.dart),
        # so joining here renders identically and lets the quote pass see the whole text.
        for fld in ('description', 'scripturalCorrelation', 'summary'):
            v = e.get(fld)
            if isinstance(v, dict):
                for lg, t in list(v.items()):
                    if isinstance(t, list):
                        v[lg] = '\n\n'.join(str(x) for x in t)
                        stats['list-joined'] += 1
        for fld in ('scripturalCorrelation', 'description', 'summary'):
            val = e.get(fld)
            if not isinstance(val, dict):
                continue
            for lang in ('en', 'zh-Hans', 'zh-Hant'):
                t = val.get(lang)
                if not t:
                    continue
                reps = []
                if lang == 'en':
                    refs = en_refs(t) + [(0,) + r[1:] for r in en_refs(e['scriptureReference'])] * (fld != 'scripturalCorrelation')
                    for pos, s1, s2, q in en_quotes(t):
                        near = [r for r in refs if r[0] < pos][-3:] or refs[:3]
                        if not near or e['id'] in SKIP_IDS:
                            continue
                        stats['en-quotes'] += 1
                        if exact_in_any(q, near, en_check):
                            stats['en-exact'] += 1
                            continue
                        sc, new, src = en_align(q, near, bsb)
                        ok = safe(q, new, sc, MIN_SCORE_EN)
                        stats['en-replaced' if ok else 'en-left'] += 1
                        report.append(dict(id=e['id'], field=fld, lang=lang, score=round(sc, 2), applied=ok, old=q, new=new))
                        if ok:
                            reps.append((s1, s2, new))
                else:
                    table = zh if lang == 'zh-Hans' else zt
                    refs = zh_refs(t) + [(0,) + r[1:] for r in zh_refs(e['scriptureReference'])] * (fld != 'scripturalCorrelation')
                    for m in re.finditer(r'「([^」]{8,800})」', t):
                        near = [r for r in refs if r[0] < m.start()][-3:] or refs[:3]
                        if not near or e['id'] in SKIP_IDS:
                            continue
                        q = m.group(1)
                        stats[lang + '-quotes'] += 1
                        if zh_exact(q, near, table):
                            stats[lang + '-exact'] += 1
                            continue
                        sc, new, src = zh_align(q, near, table)
                        ok = safe(q, new, sc, MIN_SCORE_ZH)
                        stats[lang + ('-replaced' if ok else '-left')] += 1
                        report.append(dict(id=e['id'], field=fld, lang=lang, score=round(sc, 2), applied=ok, old=q, new=new))
                        if ok:
                            reps.append((m.start(1), m.end(1), new))
                for s1, s2, new in sorted(reps, reverse=True):
                    t = t[:s1] + new + t[s2:]
                if reps:
                    val[lang] = t
    for k in sorted(stats):
        print('%-16s %d' % (k, stats[k]))
    os.makedirs(os.path.dirname(REPORT), exist_ok=True)
    json.dump(report, open(REPORT, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
    print('report ->', REPORT)
    if not write:
        print('(dry run; pass --write)')
        return
    with open(TARGET, 'w', encoding='utf-8') as f:
        f.write(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
    print('WROTE', TARGET)


if __name__ == '__main__':
    main()
