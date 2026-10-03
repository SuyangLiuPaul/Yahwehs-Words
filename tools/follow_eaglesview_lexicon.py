#!/usr/bin/env python3
"""Chinese Strong's entries: take Eagle's View's wording where EV edited it.

2026-10-03, on the owner's instruction: 「sword跟着eaglesview尽量跟着」.

Sword's Chinese lexicon (assets/strongs/greek.json, thayer_zh.json) is the
SAME translation Eagle's View ships in `Strong SCh.dct`, except that EV's
author removed some doctrinal wording the original outline carried. Four
entries were verified against both EV's file and the original outline
(Blue Letter Bible, Thayer/Strong "Outline of Biblical Usage"):

  G2316 θεός    original: 2) 神性, 三位一体 / 2a 天父, 第一位 / 2b 基督, 第二位 /
                2c 圣灵, 第三位      EV: 2) 神性
  G3056 λόγος   original: item 3 also says "…是神性中的第二位格…"
                EV: 3) 在约翰福音中, 是指神的话
  G2424 Ἰησοῦς  original: 1) 耶稣, 上帝的儿子, 人类的救主, 上帝道成肉身
                EV: 1) 耶稣, 上帝的儿子, 人类的救主
  (G4151 πνεῦμα is edited by EV in English only; the Chinese outline Sword
   carries has no entry for it.)

Each edit is guarded on the exact text it expects and refuses rather than
guesses. The original wording is recorded in docs/pastor-reviews-2026-10-03
so nothing is lost.

NOT done here, on purpose:
  * H7307 — EV KEEPS 「三一神的第三位…」 there; Sword's Hebrew lexicon never
    had it, and following EV would ADD doctrinal wording. Left for the owner.
  * Wholesale replacement of the lexicon by EV's file: different schema, no
    Traditional layer. A separate decision.

Usage:
    tools/follow_eaglesview_lexicon.py            # dry run
    tools/follow_eaglesview_lexicon.py --write
"""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GREEK = os.path.join(ROOT, 'assets', 'strongs', 'greek.json')
THAYER = os.path.join(ROOT, 'assets', 'strongs', 'thayer_zh.json')
THAYER_EN = os.path.join(ROOT, 'assets', 'thayer.json')

# (strong, field, expected-old, new)
GREEK_EDITS = [
    ('G2316', 'defZh',
     '2) 神性, 三位一体\n   2a) 上帝天父, 三位一体的第一位\n   2b) 基督, 三位一体的第二位\n   2c) 圣灵, 三位一体的第三位\n',
     '2) 神性\n'),
    ('G2316', 'defZhTw',
     '2) 神性, 三位一體\n   2a) 上帝天父, 三位一體的第一位\n   2b) 基督, 三位一體的第二位\n   2c) 聖靈, 三位一體的第三位\n',
     '2) 神性\n'),
    ('G3056', 'defZh',
     '3) 在约翰福音中, 是指神的话; 基督耶稣与神联合的智慧和能力;\n'
     '   他在宇宙中创造和治理的职事; 是世上物质和道德生命力的起因;\n'
     '   是为了人类的救恩而穿上人类本性, 在耶稣的形体里的弥赛亚;\n'
     '   是神性中的第二位格, 并从他的话和行为中显着地的表明出来.',
     '3) 在约翰福音中, 是指神的话'),
    ('G3056', 'defZhTw',
     '3) 在約翰福音中, 是指神的話; 基督耶穌與神聯合的智慧和能力;\n'
     '   他在宇宙中創造和治理的職事; 是世上物質和道德生命力的起因;\n'
     '   是爲了人類的救恩而穿上人類本性, 在耶穌的形體裏的彌賽亞;\n'
     '   是神性中的第二位格, 並從他的話和行爲中顯着地的表明出來.',
     '3) 在約翰福音中, 是指神的話'),
    ('G2424', 'glossZh', '耶稣, 上帝的儿子, 人类的救主, 上帝道成肉身', '耶稣, 上帝的儿子, 人类的救主'),
    ('G2424', 'glossZhTw', '耶穌, 上帝的兒子, 人類的救主, 上帝道成肉身', '耶穌, 上帝的兒子, 人類的救主'),
    ('G2424', 'defZh', '1) 耶稣, 上帝的儿子, 人类的救主, 上帝道成肉身\n', '1) 耶稣, 上帝的儿子, 人类的救主\n'),
    ('G2424', 'defZhTw', '1) 耶穌, 上帝的兒子, 人類的救主, 上帝道成肉身\n', '1) 耶穌, 上帝的兒子, 人類的救主\n'),
]

# thayer_zh: outline lists, replaced as exact sub-lists.
THAYER_EDITS = [
    ('G2316',
     ['2) 神性, 三位一体', '2a) 上帝天父, 三位一体的第一位', '2b) 基督, 三位一体的第二位', '2c) 圣灵, 三位一体的第三位'],
     ['2) 神性']),
    ('G3056',
     ['3) 在约翰福音中, 是指神的话；基督耶稣与神联合的智慧和能力；',
      '祂在宇宙中创造和治理的职事；是世上物质和道德生命力的起因；',
      '是为了人类的救恩而穿上人类本性，在耶稣的形体里的弥赛亚；',
      '是神性中的第二位格,并从祂的话和行为中显著地的表明出来。'],
     ['3) 在约翰福音中, 是指神的话']),
    ('G2424',
     ['1) 耶稣, 上帝的儿子, 人类的救主, 上帝道成肉身'],
     ['1) 耶稣, 上帝的儿子, 人类的救主']),
]


# 2026-10-03, owner: 「eaglesview版本有footnotes eaglesview版本呢中文英文都是」.
# The entry now reads as Eagle's View's, and a footnote says so and quotes the
# standard outline wording EV left out, so nothing is silently dropped.
EN_NOTE_MARK = "[Eagle's View version]"
ZH_NOTE_MARK = '※ EagleView 版本'
EN_FOOTNOTES = {
    'G2316': "[Eagle's View version] The standard outline of this entry also reads: \u201c2. the Godhead, trinity: 2a. God the Father, the first person in the trinity; 2b. Christ, the second person of the trinity; 2c. Holy Spirit, the third person in the trinity.\u201d Eagle's View reads item 2 as \u201cGod Divine\u201d.",
    'G3056': "[Eagle's View version] The standard outline of item 3 continues: \u201c\u2026Jesus Christ, the personal wisdom and power in union with God, his minister in the creation and government of the universe, the cause of all the world's life both physical and ethical, which for the procurement of man's salvation put on human nature in the person of Jesus the Messiah, the second person in the Godhead, and shone forth conspicuously from His words and deeds.\u201d Eagle's View stops at \u201cthe essential Word of God\u201d.",
    'G4151': "[Eagle's View version] The standard outline reads item 1 as: \u201cthe third person of the triune God, the Holy Spirit, coequal, coeternal with the Father and the Son.\u201d Eagle's View reads: \u201cThe Holy Spirit\u201d.",
    'G2424': "[Eagle's View version] The standard outline reads item 1 as: \u201cJesus, the Son of God, the Saviour of mankind, God incarnate.\u201d Eagle's View omits \u201cGod incarnate\u201d.",
}
ZH_FOOTNOTES = {  # (simplified, traditional)
    'G2316': ('※ EagleView 版本：通行的释义大纲在“2) 神性”之下另有“三位一体；2a) 上帝天父，三位一体的第一位；2b) 基督，三位一体的第二位；2c) 圣灵，三位一体的第三位”，EagleView 版本未列。',
              '※ EagleView 版本：通行的釋義大綱在「2) 神性」之下另有「三位一體；2a) 上帝天父，三位一體的第一位；2b) 基督，三位一體的第二位；2c) 聖靈，三位一體的第三位」，EagleView 版本未列。'),
    'G3056': ('※ EagleView 版本：通行的释义大纲第 3 项另有“基督耶稣与神联合的智慧和能力……是神性中的第二位格，并从他的话和行为中显着地的表明出来”，EagleView 版本只作“在约翰福音中，是指神的话”。',
              '※ EagleView 版本：通行的釋義大綱第 3 項另有「基督耶穌與神聯合的智慧和能力……是神性中的第二位格，並從他的話和行爲中顯着地的表明出來」，EagleView 版本只作「在約翰福音中，是指神的話」。'),
    'G2424': ('※ EagleView 版本：通行的释义大纲第 1 项作“耶稣, 上帝的儿子, 人类的救主, 上帝道成肉身”，EagleView 版本无“上帝道成肉身”。',
              '※ EagleView 版本：通行的釋義大綱第 1 項作「耶穌, 上帝的兒子, 人類的救主, 上帝道成肉身」，EagleView 版本無「上帝道成肉身」。'),
}


def main():
    write = '--write' in sys.argv
    greek = json.load(open(GREEK, encoding='utf-8'))
    thayer = json.load(open(THAYER, encoding='utf-8')) if os.path.exists(THAYER) else None
    bad = 0
    for sid, field, old, new in GREEK_EDITS:
        cur = greek[sid].get(field, '')
        if sid == 'G3056':
            head = new.split(',')[0]            # '3) 在约翰福音中' / '3) 在約翰福音中'
            at = cur.find(head)
            if at < 0:
                print('NO MATCH greek   %s.%s' % (sid, field)); bad += 1; continue
            tail = cur[at:]
            if tail.split('\n※')[0].rstrip() == new:
                print('already  greek   %s.%s' % (sid, field))
            elif '第二位格' in tail:
                greek[sid][field] = cur[:at] + new
                print('applied  greek   %s.%s' % (sid, field))
            else:
                print('NO MATCH greek   %s.%s: tail %r' % (sid, field, tail[:60])); bad += 1
            continue
        if old in cur:
            if cur.count(old) != 1:
                print('AMBIGUOUS greek %s.%s' % (sid, field)); bad += 1; continue
            greek[sid][field] = cur.replace(old, new)
            print('applied  greek   %s.%s' % (sid, field))
        elif new in cur:
            print('already  greek   %s.%s' % (sid, field))
        else:
            print('NO MATCH greek   %s.%s: %r' % (sid, field, cur[:80])); bad += 1
    for sid, old, new in (THAYER_EDITS if thayer is not None else []):
        s = thayer[sid]['s']
        if sid == 'G3056':
            at = next((i for i, x in enumerate(s) if x.startswith('3) 在约翰福音中')), None)
            if at is None:
                print('NO MATCH thayer  %s' % sid); bad += 1; continue
            tail = ''.join(s[at:])
            if [x for x in s[at:] if not x.startswith('※')] == new:
                print('already  thayer  %s' % sid)
            elif '第二位格' in tail:
                thayer[sid]['s'] = s[:at] + new
                print('applied  thayer  %s' % sid)
            else:
                print('NO MATCH thayer  %s: tail %r' % (sid, tail[:60])); bad += 1
            continue
        n = len(old)
        at = next((i for i in range(len(s) - n + 1) if s[i:i + n] == old), None)
        if at is not None:
            thayer[sid]['s'] = s[:at] + new + s[at + n:]
            print('applied  thayer  %s' % sid)
        elif any(s[i:i + len(new)] == new for i in range(len(s) - len(new) + 1)):
            print('already  thayer  %s' % sid)
        else:
            print('NO MATCH thayer  %s' % sid); bad += 1
    thayer_en = json.load(open(THAYER_EN, encoding='utf-8'))
    for sid, note in EN_FOOTNOTES.items():
        cur = thayer_en['entries'][sid]
        if EN_NOTE_MARK in cur:
            print('already  en-note %s' % sid)
        else:
            thayer_en['entries'][sid] = cur.rstrip() + '\n\n' + note
            print('applied  en-note %s' % sid)
    for sid, (simp, trad) in ZH_FOOTNOTES.items():
        for field, text in (('defZh', simp), ('defZhTw', trad)):
            cur = greek[sid][field]
            if ZH_NOTE_MARK in cur:
                print('already  zh-note %s.%s' % (sid, field))
            else:
                greek[sid][field] = cur.rstrip() + '\n' + text
                print('applied  zh-note %s.%s' % (sid, field))
        if thayer is None:
            pass
        elif any(x.startswith(ZH_NOTE_MARK) for x in thayer[sid]['s']):
            print('already  zh-note thayer %s' % sid)
        else:
            thayer[sid]['s'].append(simp)
            print('applied  zh-note thayer %s' % sid)
    if bad:
        raise SystemExit('REFUSING TO WRITE: go and read the entry')
    if not write:
        print('(dry run; pass --write)')
        return
    for path, obj in ((GREEK, greek), (THAYER, thayer), (THAYER_EN, thayer_en)):
        if obj is None:
            continue
        with open(path, encoding='utf-8') as f:
            raw = f.read()
        before = json.loads(raw)
        # Write back in the file's own format, so the diff is only the edit.
        for kw, nl in ((dict(separators=(',', ':')), ''), (dict(separators=(',', ':')), '\n'),
                       (dict(indent=2), ''), (dict(indent=2), '\n')):
            if json.dumps(before, ensure_ascii=False, **kw) + nl == raw:
                out = json.dumps(obj, ensure_ascii=False, **kw) + nl
                break
        else:
            raise SystemExit('unknown JSON layout in %s' % path)
        with open(path, 'w', encoding='utf-8') as f:
            f.write(out)
        print('WROTE %s' % path)


if __name__ == '__main__':
    main()
