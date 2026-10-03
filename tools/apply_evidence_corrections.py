#!/usr/bin/env python3
"""Content corrections for assets/bible_evidence.json (圣经证据), found by the
2026-10-03/04 accuracy audit. Each correction cites the source it rests on.

Hand-written: English and 简体. 繁體 is generated from the 简体 with
`opencc -c s2tw` (s2tw for both repos).
Scripture quotations are NOT touched here (tools/fix_evidence_quotes.py owns those).

Edit kinds:
  para   replace the paragraph that STARTS with `match_*` (per language)
  set    replace a whole text field
  meta   confidenceLevel / location / timeline / discoveryDate
         (the Sword copy keeps these three as plain English strings; Words has per-language dicts)
  source replace/add an entry in academicSources
Every edit is idempotent (applied only when the current value differs).

Usage:
    tools/apply_evidence_corrections.py           # dry run
    tools/apply_evidence_corrections.py --write
"""
import json
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TARGET = os.path.join(ROOT, 'assets', 'bible_evidence.json')


def _config():
    # Both repos keep zh-Hant as a GLYPH conversion of the 简体 wording (tests pin that: no 公元->西元 etc.).
    return 's2tw'


CONFIG = None


def hant(text, config=None):
    global CONFIG
    if CONFIG is None:
        CONFIG = _config()
    p = subprocess.run(['opencc', '-c', config or CONFIG], input=text, capture_output=True, text=True, check=True)
    return p.stdout.rstrip('\n')


E = []  # corrections


def para(id, field, match_en, match_zh, en, zh):
    E.append(dict(kind='para', id=id, field=field, match_en=match_en, match_zh=match_zh, en=en, zh=zh))


def setf(id, field, en, zh):
    E.append(dict(kind='set', id=id, field=field, en=en, zh=zh))


def sub(id, field, en_old=None, en_new=None, zh_old=None, zh_new=None):
    E.append(dict(kind='sub', id=id, field=field, en_old=en_old, en_new=en_new, zh_old=zh_old, zh_new=zh_new))


def meta(id, field, en, zh=None):
    E.append(dict(kind='meta', id=id, field=field, en=en, zh=zh))


def source(id, replace_startswith, new):
    E.append(dict(kind='source', id=id, old=replace_startswith, new=new))


# ---------------------------------------------------------------- tall_el_hammam
# Retraction Note, Scientific Reports 15, 14291 (24 Apr 2025), doi:10.1038/s41598-025-99265-5
# https://pmc.ncbi.nlm.nih.gov/articles/PMC12022329/ ; Retraction Watch 2025-04-23.
setf('tall_el_hammam', 'summary',
     "Excavations at Tall el-Hammam in Jordan's southern Ghor plain show a large Middle Bronze Age city abandoned around 1650 BCE. A 2021 paper claimed a cosmic airburst destroyed it, but Scientific Reports retracted that paper in April 2025, and identifying the site with biblical Sodom remains a minority position.",
     "约旦南部戈尔平原的特尔哈曼遗址显示，一座大型青铜时代中期城市在约公元前1650年前后被废弃。2021年有论文主张该城毁于宇宙空爆，但《科学报告》已于2025年4月撤回该论文；将该遗址认定为圣经中的所多玛，仍属少数派观点。")
para('tall_el_hammam', 'description', 'A landmark 2021 paper', '菲利普·席尔维亚',
     "In September 2021 Scientific Reports published a paper led by Ted Bunch, with Phillip Silvia, Allen West and other co-authors, arguing that a Tunguska-sized cosmic airburst destroyed the city; it cited shocked quartz, melt glass, platinum-group anomalies and zircon evidence. Other scientists criticised the work at once, the journal attached an editor's note in 2023, and on 24 April 2025 it retracted the paper. The retraction note cites errors in methodology and in the analysis and interpretation of the mineralogical and geochemical data, and an unsupported comparison with the 1908 Tunguska event, and concludes that the airburst claim is not sufficiently supported by the data. The airburst explanation should therefore not be treated as established evidence.",
     "2021年9月，《科学报告》发表了一篇由特德·邦奇牵头、菲利普·席尔维亚、艾伦·韦斯特等人合著的论文，主张一次相当于通古斯规模的宇宙空爆摧毁了该城，所举证据包括冲击石英、熔融玻璃、铂族元素异常和锆石。其他科学家随即提出批评，期刊在2023年加上编辑说明，并于2025年4月24日撤回了该论文。撤稿声明指出其在方法、矿物学与地球化学数据的分析和解释上存在错误，并且与1908年通古斯事件的比较缺乏依据，结论是“空爆摧毁该城”的说法没有得到数据的充分支持。因此，空爆说不应被当作已确立的证据。")
para('tall_el_hammam', 'scripturalCorrelation', 'The Tall el-Hammam airburst evidence', '特尔哈曼空爆证据',
     "This entry is categorized as Circumstantial because the identification of Tall el-Hammam with Sodom is not proven, and because the 2021 airburst paper that was used to support a 'fire from heaven' reading was retracted by Scientific Reports in April 2025. What remains is a large Middle Bronze Age city in the Kikkar of the Jordan that fits the geographical setting of Genesis 13 and 19. Whether it is Sodom, and what ended its occupation, are still debated, and other sites, including some on the southern shore of the Dead Sea, have been proposed.",
     "本条目列为“间接”等级，一是因为将特尔哈曼认定为所多玛尚未得到证实，二是因为曾被用来支持“天上降火”解读的2021年空爆论文已于2025年4月被《科学报告》撤回。目前留下的只是约旦基卡尔地区一座符合创世记13章和19章地理背景的青铜时代中期大城。它是否就是所多玛、其居住为何终止，仍有争论，死海南岸的一些遗址也曾被提出为候选。")
source('tall_el_hammam', 'Collins, Steven, et al. "A Tall el-Hammam Cosmic Airburst Event."',
       'Bunch, Ted E., et al. "A Tunguska sized airburst destroyed Tall el-Hammam a Middle Bronze Age city in the Jordan Valley near the Dead Sea." Scientific Reports 11 (2021), doi:10.1038/s41598-021-97778-3. Retracted 24 April 2025: Retraction Note, Scientific Reports 15, 14291 (2025), doi:10.1038/s41598-025-99265-5.')

# ---------------------------------------------------------------- bulla_isaiah_prophet
# Found 2009 on the Ophel, published by E. Mazar, BAR 44.2 (Feb 2018); reading disputed (C. Rollston).
meta('bulla_isaiah_prophet', 'confidenceLevel', 'Circumstantial')
meta('bulla_isaiah_prophet', 'discoveryDate', '2009 (published 2018, Eilat Mazar)', '2009年（2018年由伊拉特·马扎尔发表）')
setf('bulla_isaiah_prophet', 'summary',
     "A damaged clay bulla found in 2009 on the Ophel in Jerusalem and published by Eilat Mazar in 2018 reads 'Belonging to Isaiah' followed by the letters nby. Mazar proposed 'Isaiah the prophet', but the reading and the identification are disputed.",
     "2009年在耶路撒冷俄斐勒出土、由伊拉特·马扎尔于2018年发表的破损封泥，铭文为“属于以赛亚”，其后接字母 nby。马扎尔主张可读作“先知以赛亚”，但这一释读及其认定尚有争议。")
para('bulla_isaiah_prophet', 'description', 'The bulla is fragmentary', '该封泥已残缺',
     "The bulla is fragmentary, and the end of the second word is damaged. It is a clay seal impression in three registers: the second reads lyšʿyh[w] ('Belonging to Isaiah') and the third preserves the letters nby. Eilat Mazar (1956–2021), who directed the Ophel excavation, argued that with a restored aleph this is nby[ʾ], 'prophet'. Critics, notably Christopher Rollston, note that no aleph is legible, that the definite article ('the prophet') that would be expected is missing, that Isaiah was a common name, and that the bulla gives no patronymic ('son of Amoz'). On that view nby may be a personal name or a gentilic, and identifying the owner with the biblical prophet is speculative. The bulla was found in 2009 and Mazar published it in Biblical Archaeology Review in February 2018.",
     "该封泥已残缺，第二个词的末尾受损。它是一枚分为三栏的泥封印：第二栏为 lyšʿyh[w]（“属于以赛亚”），第三栏保留了字母 nby。主持俄斐勒发掘的伊拉特·马扎尔（1956—2021）主张，补回缺失的字母 aleph 后可读作 nby[ʾ]，即“先知”。批评者（尤以克里斯托弗·罗尔斯顿为代表）指出：没有一个清晰可辨的 aleph；应有的定冠词（“那位先知”）也没有；以赛亚是常见人名；封泥上也没有父名（“亚摩斯的儿子”）。照这种看法，nby 可能是人名或出身地名，把印主认定为圣经中的先知只是推测。该封泥于2009年出土，马扎尔于2018年2月在《圣经考古评论》上发表。")
para('bulla_isaiah_prophet', 'description', 'Its proximity to the bulla of King Hezekiah', '本品与已确认的希西家王封泥',
     "It was found about three metres from the bulla of King Hezekiah, in the same destruction layer and by the same expedition. Hezekiah and Isaiah are paired throughout 2 Kings 19–20 and Isaiah 36–39, which makes the find suggestive, but proximity alone cannot settle a damaged inscription.",
     "它出土于距希西家王封泥约三米处，同属一个毁坏地层，由同一考察队发现。希西家与以赛亚在列王纪下19—20章和以赛亚书36—39章中始终并列出现，这使该发现颇具启发，但仅凭位置接近，无法确定一段受损的铭文。")
para('bulla_isaiah_prophet', 'scripturalCorrelation', "2 Kings 19:1-7 records", '列王纪下19:1-7',
     "2 Kings 19:1-7 records King Hezekiah sending messengers to Isaiah the prophet during the Assyrian siege; the king and the prophet collaborate throughout chapters 19-20. If the 'prophet' reading of the bulla were confirmed, it would be a rare physical link to a named Hebrew prophet. The damaged inscription does not allow that to be established, so the bulla is best treated as a suggestive possibility, not proof.",
     "列王纪下19:1-7记载，亚述围城之际希西家王差人去见先知以赛亚；二人在第19—20章中通力协作。若“先知”的读法得到证实，这将是与一位具名希伯来先知之间罕见的实物联系。但受损的铭文无法确立这一点，因此这枚封泥最好被看作一种有启发性的可能，而不是证据。")

# ---------------------------------------------------------------- ossuary_of_james
# Farkash verdict 14 Mar 2012; Supreme Court 2013 ordered the ossuary returned to O. Golan.
# https://www.biblicalarchaeology.org/daily/news/will-the-iaa-return-the-james-ossuary-to-oded-golan/
meta('ossuary_of_james', 'location',
     'Israel; privately held by collector Oded Golan (returned to him after a 2013 Supreme Court ruling; exhibited at the Royal Ontario Museum, Toronto, in 2002)',
     '以色列；由收藏家奥德·戈兰私人持有（2013年最高法院裁决后发还给他；2002年曾在多伦多皇家安大略博物馆展出）')
para('ossuary_of_james', 'description', 'The Israel Antiquities Authority', '以色列文物管理局',
     "The Israel Antiquities Authority declared the inscription a forgery in 2003, and the collector Oded Golan was tried in Jerusalem. In March 2012 Judge Aharon Farkash acquitted him of forging the inscription, stating that the acquittal did not mean the inscription is authentic or was written 2,000 years ago, only that forgery had not been proven beyond a reasonable doubt. Golan was convicted of a lesser charge of illegal trading in antiquities. In 2013 the Supreme Court ordered the ossuary returned to him. The ossuary has no excavated provenance and scholarly opinion remains divided.",
     "以色列文物管理局于2003年宣布该铭文为伪造，收藏家奥德·戈兰因此在耶路撒冷受审。2012年3月，法官阿哈龙·法尔卡什判决他伪造铭文的罪名不成立，并指出这一判决并不表示铭文是真的、也不表示它写于两千年前，只表示伪造未能在排除合理怀疑的程度上得到证明。戈兰另被以非法买卖古物的较轻罪名定罪。2013年最高法院裁定把骸骨箱发还给他。该骸骨箱没有科学发掘的出土背景，学界意见至今仍然分歧。")
source('ossuary_of_james', 'Shanks, Hershel, and Ben Witherington III.',
       'Shanks, Hershel, and Ben Witherington III. The Brother of Jesus. HarperSanFrancisco, 2003.')


# ---------------------------------------------------------------- hezekiah_royal_seal
# Bulla found in 2009 Ophel wet-sifting (refuse dump beside a 10th-c. BCE royal building), announced Dec 2015;
# shows a two-winged sun between TWO ankhs; the winged-scarab Hezekiah seals are unprovenanced market pieces.
# https://library.biblicalarchaeology.org/department/royal-seal-of-king-hezekiah-comes-to-light-in-jerusalem-excavation/
# https://en.wikipedia.org/wiki/King_Hezekiah_bulla
meta('hezekiah_royal_seal', 'discoveryDate', '2009 (announced 2015)', '2009年（2015年公布）')
para('hezekiah_royal_seal', 'description', 'The bulla (a clay seal impression)', '希西家王的泥印',
     "The bulla (a clay seal impression) of King Hezekiah was found in 2009 by Eilat Mazar's Ophel expedition during wet-sifting of earth from a refuse dump beside a 10th-century BCE royal building at the foot of the Temple Mount's southern wall, together with 33 other bullae; it was announced in December 2015. Its Paleo-Hebrew inscription reads 'Belonging to Hezekiah [son of] Ahaz king of Judah'. The seal dates to the 8th century BCE, the period of Hezekiah's reign, making it a contemporary artifact of the biblical king.",
     "希西家王的泥印（印章印记）于2009年由埃拉特·马扎尔率领的俄斐勒发掘队在筛洗土壤时发现，出土于圣殿山南墙脚下一座公元前10世纪王室建筑旁的垃圾堆，同时出土的还有另外33枚泥印；2015年12月公布。其古希伯来文铭文为“属于希西家，亚哈斯之子，犹大王”。该印章可追溯到公元前8世纪，即希西家王的统治时期，使其成为这位圣经君王的同期文物。")
para('hezekiah_royal_seal', 'description', 'The bulla depicts a two-winged sun', '该泥印描绘了一个两翼太阳',
     "The bulla shows a two-winged sun disc with its wings turned downward, flanked by two ankh signs (symbols of life), above the inscription. Other seal impressions of Hezekiah, known since the 1990s from the antiquities market and so without excavation context, show a winged scarab or a winged sun. This is the first impression of a seal of an Israelite or Judean king found in a scientific excavation, and it comes from the royal quarter beside the Temple Mount.",
     "该泥印上有一个两翼向下的太阳盘，两侧各有一个安卡符号（生命的象征），其下为铭文。自20世纪90年代起，古董市场上已出现过其他希西家印章的印记，因没有发掘背景，有的刻带翼圣甲虫，有的刻带翼太阳。本品是科学发掘中首次出土的以色列或犹大国王的印章印记，出自圣殿山旁的王室区域。")

# ---------------------------------------------------------------- ketef_hinnom_scrolls
# Barkay published in Hebrew 1989 and in English 1992 (Tel Aviv 19); West Semitic Research Project reanalysis,
# Barkay et al., BASOR 334 (2004): date c. 650-587 BCE.  https://madainproject.com/ketef_hinnom_scrolls
para('ketef_hinnom_scrolls', 'description', 'High-resolution multispectral imaging', '2004年，学者借助高分辨率多光谱成像技术',
     "In the early 2000s Barkay's team and the West Semitic Research Project re-photographed and re-read the scrolls with advanced imaging. Their study, 'The Amulets from Ketef Hinnom: A New Edition and Evaluation' (Bulletin of the American Schools of Oriental Research 334, 2004), allowed much more of the inscriptions to be read and dated them to about 650–587 BCE. The scrolls are now in the Israel Museum, Jerusalem. Barkay first published the inscriptions in Hebrew in 1989 and in English in 1992.",
     "21世纪初，巴克莱的团队与西闪研究计划借助先进成像技术重新拍摄并重读了这些银卷。其研究《基特夫·欣嫩的护身符：新版与评估》（《美国东方研究学会学报》334期，2004年）使铭文得以更完整地辨读，并把年代定在约公元前650至587年。银卷现藏于耶路撒冷以色列博物馆。巴克莱于1989年首先用希伯来文、1992年用英文发表了这些铭文。")
source('ketef_hinnom_scrolls', 'Barkay, Gabriel, et al. "The Amulets from Ketef Hinnom',
       'Barkay, Gabriel, et al. "The Amulets from Ketef Hinnom: A New Edition and Evaluation." Bulletin of the American Schools of Oriental Research 334 (2004).')

# ---------------------------------------------------------------- khirbet_qeiyafa_ostracon
# C-14 of olive pits: late 11th-early 10th c. BCE; Hebrew vs Canaanite dispute (Garfinkel's verb 'to do').
sub('khirbet_qeiyafa_ostracon', 'description',
    "Radiocarbon dating of olive pits from the same layer confirmed the 10th century date.",
    "Radiocarbon dating of olive pits from the same context points to the late 11th or early 10th century BCE. Whether the language is Hebrew is disputed: Garfinkel read a verb meaning 'to do' as distinctively Hebrew, while other scholars hold that the text could equally be Canaanite, Phoenician or Moabite.",
    "同一地层的橄榄核放射性碳测年确认了公元前10世纪的日期。",
    "同一地层的橄榄核放射性碳测年指向公元前11世纪末或10世纪初。铭文的语言是否为希伯来语仍有争议：加芬克尔把其中一个表示“做”的动词视为希伯来语特有，而另一些学者认为该文本同样可能是迦南语、腓尼基语或摩押语。")
sub('khirbet_qeiyafa_ostracon', 'description', None, None, "位于犹大与 Philistia 的边界", "位于犹大与非利士地的边界")
sub('khirbet_qeiyafa_ostracon', 'description', None, None, "在 Philistine 城市中未发现", "在非利士城市中未发现")
sub('khirbet_qeiyafa_ostracon', 'description', None, None, "区别于附近的 Philistine 遗址", "区别于附近的非利士遗址")
sub('khirbet_qeiyafa_ostracon', 'description', None, None, "犹大/Philistine边境地区", "犹大/非利士边境地区")


def apply(data):
    by = {e['id']: e for e in data['evidences']}
    changed = 0
    for c in E:
        e = by.get(c['id'])
        if e is None:
            raise SystemExit('unknown id ' + c['id'])
        k = c['kind']
        if k == 'meta':
            f = c['field']
            if f == 'confidenceLevel':
                if e[f] != c['en']:
                    e[f] = c['en']; changed += 1
            elif isinstance(e[f], dict):
                new = {'en': c['en'], 'zh-Hans': c['zh'], 'zh-Hant': hant(c['zh'])}
                if e[f] != new:
                    e[f] = new; changed += 1
            else:  # Sword: plain English string
                if e[f] != c['en']:
                    e[f] = c['en']; changed += 1
        elif k == 'sub':
            for lang in ('en', 'zh-Hans', 'zh-Hant'):
                if lang == 'en':
                    old, new = c['en_old'], c['en_new']
                elif lang == 'zh-Hans':
                    old, new = c['zh_old'], c['zh_new']
                else:
                    old = hant(c['zh_old']) if c['zh_old'] else None
                    new = hant(c['zh_new']) if c['zh_new'] else None
                if not old:
                    continue
                val = e[c['field']]
                cur = val[lang]
                if isinstance(cur, list):
                    cur = '\n\n'.join(cur)
                if old in cur:
                    if cur.count(old) != 1:
                        raise SystemExit('%s.%s[%s]: %r occurs %d times' % (c['id'], c['field'], lang, old, cur.count(old)))
                    val[lang] = cur.replace(old, new); changed += 1
                elif new not in cur:
                    raise SystemExit('%s.%s[%s]: neither old nor new text found: %r' % (c['id'], c['field'], lang, old[:40]))
        elif k == 'source':
            src = e['academicSources']
            idx = next((i for i, s in enumerate(src) if s.startswith(c['old'])), None)
            if idx is None:
                if c['new'] not in src:
                    src.append(c['new']); changed += 1
            elif src[idx] != c['new']:
                src[idx] = c['new']; changed += 1
        else:
            for lang, new in (('en', c['en']), ('zh-Hans', c['zh']), ('zh-Hant', hant(c['zh']))):
                val = e[c['field']]
                cur = val[lang]
                if isinstance(cur, list):
                    cur = '\n\n'.join(cur)
                if k == 'set':
                    if cur != new:
                        val[lang] = new; changed += 1
                else:
                    match = c['match_en'] if lang == 'en' else (c['match_zh'] if lang == 'zh-Hans' else hant(c['match_zh']))
                    paras = cur.split('\n\n')
                    # also accept a paragraph that already holds this correction (any zh-Hant conversion)
                    n = 30 if lang == 'en' else 14
                    starts = {match, new[:n]}
                    if lang == 'zh-Hant':
                        starts |= {hant(c['zh'], 's2tw')[:n], hant(c['zh'], 's2twp')[:n]}
                    hit = [i for i, p in enumerate(paras) if any(p.startswith(x) for x in starts)]
                    # zh-Hant wording differs between the repos' existing text (藉助/借助 ...): trust the
                    # paragraph position found for 简体 when both versions have the same paragraph count.
                    if lang == 'zh-Hans' and len(hit) == 1:
                        c['_idx'], c['_n'] = hit[0], len(paras)
                    elif lang == 'zh-Hant' and len(hit) != 1 and c.get('_n') == len(paras):
                        hit = [c['_idx']]
                    if len(hit) != 1:
                        if new in paras:
                            continue
                        raise SystemExit('%s.%s[%s]: paragraph %r matched %d times' % (c['id'], c['field'], lang, match, len(hit)))
                    if paras[hit[0]] != new:
                        paras[hit[0]] = new
                        val[lang] = '\n\n'.join(paras); changed += 1
    return changed


def main():
    data = json.load(open(TARGET, encoding='utf-8'))
    n = apply(data)
    counts = {}
    for e in data['evidences']:
        counts[e['confidenceLevel']] = counts.get(e['confidenceLevel'], 0) + 1
    meta = data.get('_meta', {})
    if 'confidenceCounts' in meta and meta['confidenceCounts'] != counts:
        meta['confidenceCounts'] = counts
        n += 1
    print('corrections applied: %d' % n)
    if '--write' not in sys.argv:
        print('(dry run; pass --write)')
        return
    with open(TARGET, 'w', encoding='utf-8') as f:
        f.write(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
    print('WROTE', TARGET)


if __name__ == '__main__':
    main()
