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

# opencc s2tw one-to-many mistakes that the repos' tests pin as corrected (see
# test/bible_evidence_traditional_test.dart and bible_evidence_language_test.dart).
REPAIRS = [
    ('髮掘', '發掘'), ('被髮', '被發'), ('騷亂髮', '騷亂發'), ('包括髮', '包括發'), ('覆活', '復活'),
    ('幹河谷', '乾河谷'), ('石制', '石製'), ('羊皮捲', '羊皮卷'), ('爐灶', '爐竈'),
    ('馬裡', '馬里'), ('泰勒裡', '泰勒里'), ('瑪裡', '瑪里'), ('胡裡', '胡里'), ('古裡', '古里'),
    ('弗裡', '弗里'), ('努外裡', '努外里'), ('加布裡', '加布里'), ('哈塔裡', '哈塔里'), ('艾茲裡', '艾茲里'),
    ('伊斯坦布林', '伊斯坦布爾'),
]


def hant(text, config=None):
    global CONFIG
    if CONFIG is None:
        CONFIG = _config()
    p = subprocess.run(['opencc', '-c', config or CONFIG], input=text, capture_output=True, text=True, check=True)
    out = p.stdout.rstrip('\n')
    for a, b in REPAIRS:
        out = out.replace(a, b)
    return out


E = []  # corrections


def para(id, field, match_en, match_zh, en, zh):
    E.append(dict(kind='para', id=id, field=field, match_en=match_en, match_zh=match_zh, en=en, zh=zh))


def setf(id, field, en, zh):
    E.append(dict(kind='set', id=id, field=field, en=en, zh=zh))


def append(id, field, en, zh):
    E.append(dict(kind='append', id=id, field=field, en=en, zh=zh))


def drop(id, field, lang_prefixes):
    """Remove paragraphs that start with a given prefix: {'zh-Hans': [prefix, ...], 'en': [...]}."""
    E.append(dict(kind='drop', id=id, field=field, lang_prefixes=lang_prefixes))


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


# ---------------------------------------------------------------- pool_of_siloam
# Found autumn 2004, announced 9 Aug 2005; Alexander Jannaeus coins in the plaster; Szanton doubts the mikveh reading;
# full IAA excavation from 2023 (monumental dam ~800 BCE). https://en.wikipedia.org/wiki/Siloam_Pool ;
# https://www.biblicalarchaeology.org/daily/ancient-cultures/ancient-israel/rethinking-the-pool-of-siloam/
meta('pool_of_siloam', 'confidenceLevel', 'Strong')
setf('pool_of_siloam', 'summary',
     "Discovered in 2004 during a sewer repair in Jerusalem's City of David, a large stepped Second Temple-era pool matching the Gospel of John's Pool of Siloam was excavated. It is strongly consistent with the account of Jesus healing the blind man, although the pool's exact identification and use are still debated.",
     "2004年耶路撒冷大卫城一处排水管道修缮工程中，一座与约翰福音所载西罗亚池相符的第二圣殿时期大型踏步式水池被发掘出来。它与耶稣医治瞎眼男子的记载高度吻合，但这座水池的确切身份和用途仍有争论。")
para('pool_of_siloam', 'description', 'In August 2004', '2004年8月',
     "In autumn 2004, during routine sewage pipe repairs in Jerusalem's City of David, workers uncovered a series of ancient stone steps (the find was announced in August 2005). Archaeologists Ronny Reich and Eli Shukron excavated the site and revealed a large stepped pool, trapezoidal in plan and about 69 metres (225 ft) wide, with three sets of five broad steps descending into the basin. Reich interpreted it as a ritual pool (mikveh).",
     "2004年秋，在耶路撒冷大卫城一处例行的排水管道修缮工程中，施工人员掘出了一系列古代石阶（该发现于2005年8月公布）。考古学家荣尼·雷希与埃利·舒克隆主持发掘，揭露出一座大型踏步式水池，平面呈梯形，宽约69米（225英尺），设有三组各五级的宽阔石阶延伸入池中。雷希把它解释为一座礼仪浴池（mikveh）。")
para('pool_of_siloam', 'description', 'Ceramic, coin, and stratigraphic analysis', '陶片、钱币及地层分析',
     "Coins of the Hasmonean king Alexander Jannaeus (103–76 BCE) embedded in the plaster lining give the earliest possible date for the pool's construction, and the pool stayed in use until the destruction of Jerusalem in 70 CE. That places its use during Jesus' ministry (c. 28–30 CE). It was fed by Hezekiah's Tunnel from the Gihon Spring, which links the spring, the tunnel and the pool.",
     "嵌在池壁灰泥层中的哈斯蒙尼王亚历山大·詹乃（公元前103—76年）的钱币，给出了水池建造的最早可能年代；此池一直使用到公元70年耶路撒冷被毁。这意味着它在耶稣传道期间（约公元28至30年）仍在使用。它由希西家水道从基训泉引水，把泉、水道与水池连成一线。")
append('pool_of_siloam', 'description',
     "Not every archaeologist accepts the whole picture. Nahshon Szanton of the Israel Antiquities Authority, who leads the full excavation that the IAA and the City of David Foundation began in 2023, has argued that the mikveh identification is almost certainly wrong. The 2023 work has also exposed a monumental dam, reported to be at least 19 metres long and 11 metres high and radiocarbon-dated to about 800 BCE, so the picture of the area keeps changing.",
     "并非所有考古学家都接受上述全部看法。以色列文物管理局的纳雄·桑通（Nahshon Szanton）主持文物管理局与大卫城基金会自2023年起展开的全面发掘，他认为“礼仪浴池”的认定几乎肯定是错的。2023年的工作还揭露出一座巨大的堤坝，据报道长至少19米、高11米，经放射性碳测年约为公元前800年，因此该地区的整体图景仍在变化。")

# ---------------------------------------------------------------- jericho_walls
# Bruins & van der Plicht, Radiocarbon 37 (1995): City IV destruction 1562 +/- 38 BCE (18 samples).
# https://en.wikipedia.org/wiki/Fall_of_Jericho ; https://biblearchaeologyreport.com/2019/05/17/biblical-places-three-ways-to-date-the-destruction-at-jericho/
para('jericho_walls', 'description', 'Garstang identified a destruction layer', '加斯唐识别出一个毁坏层',
     "Garstang identified a destruction layer, including collapsed walls and a burn level, that he attributed to the Late Bronze Age (c. 1400 BCE), consistent with his dating of the Exodus and conquest. Kenyon's more rigorous stratigraphic analysis dated that City IV destruction to the Middle Bronze Age (c. 1550 BCE) and found the site largely unoccupied in the Late Bronze Age (c. 1550–1200 BCE), the period in which a conquest under Joshua would fall. That creates the central scholarly problem for this evidence.",
     "加斯唐识别出一个毁坏层，包括坍塌的城墙和焚烧层，并把它归因于青铜时代晚期（约公元前1400年），与他对出埃及和征服的年代学一致。凯尼恩更严格的地层分析则把这一第四城的毁灭定在青铜时代中期（约公元前1550年），并认为在青铜时代晚期（约公元前1550-1200年），也就是约书亚征服可能发生的时期，该遗址基本无人居住。这就构成了此项证据的核心学术难题。")
append('jericho_walls', 'description',
     "In 1995 Hendrik Bruins and Johannes van der Plicht radiocarbon-dated 18 samples from Jericho, including charred grain from the City IV burn layer, and placed the destruction at 1562 ± 38 BCE, which supports Kenyon's Middle Bronze Age date. Wood and other defenders of a destruction around 1400 BCE dispute how the pottery and the radiocarbon evidence are read, so linking this layer to Joshua 6 remains unresolved.",
     "1995年，亨德里克·布鲁因斯与约翰内斯·范德普利赫特对耶利哥的18个样本（包括第四城焚烧层中的炭化谷粒）作了放射性碳测年，把这次毁灭定在公元前1562年（误差±38年），支持了凯尼恩的青铜时代中期年代。伍德等主张约公元前1400年毁灭的人，则对陶器与放射性碳证据的解读提出异议，因此把这一地层与约书亚记6章联系起来，至今没有定论。")
source('jericho_walls', 'Bruins, Hendrik J.',
       'Bruins, Hendrik J., and Johannes van der Plicht. "Tell es-Sultan (Jericho): Radiocarbon Results of Short-Lived Cereal and Multi-Year Charcoal Samples from the End of the Middle Bronze Age." Radiocarbon 37 (1995).')

# ---------------------------------------------------------------- caiaphas_ossuary / house_of_caiaphas
# Inscribed 'Yehosef bar Qayafa' (long side) and 'Yehosef bar Qafa' (narrow side); identification debated (spelling, no
# 'priest' title, plain tomb; Puech); Reich: Joseph with the nickname Caiaphas. https://en.wikipedia.org/wiki/Caiaphas_ossuary
setf('caiaphas_ossuary', 'summary',
     "A limestone bone box found in Jerusalem in 1990, inscribed 'Joseph son of Caiaphas'. Many scholars identify it as the ossuary of the high priest Joseph Caiaphas who presided at Jesus' trial, but the identification is debated.",
     "1990年在耶路撒冷发现的石灰岩藏骨罐，上刻「约瑟——该亚法之子」。许多学者认为它是主持耶稣审判的大祭司约瑟·该亚法的藏骨罐，但这一认定仍有争议。")
para('caiaphas_ossuary', 'description', 'The identification with the biblical high priest', '多数学者，包括发表此发现的荣尼·雷希',
     "Zvi Greenhut, who excavated the cave, and Ronny Reich, who published the inscriptions, regard the identification with the high priest as probable. Josephus (Antiquities 18.2.2) calls the high priest 'Joseph who was called Caiaphas', and Reich takes 'Caiaphas' to be a nickname or family name. Others are doubtful: the spelling (Qafa or Qayafa), the missing title 'priest' on the ossuary and the plain tomb have led scholars such as Émile Puech to question it. The identification is therefore probable, but not certain.",
     "挖掘该洞穴的茨维·格林胡特和发表铭文的荣尼·雷希认为，这与大祭司为同一人很有可能。约瑟夫（《犹太古史》18.2.2）称这位大祭司为“又称该亚法的约瑟”，雷希认为“该亚法”是绰号或家族名。另一些学者持怀疑态度：拼写（Qafa 或 Qayafa）、骨罐上没有“祭司”头衔，以及墓室简朴，使埃米尔·普克等学者对此提出质疑。因此这一认定属“很可能”，而非确定。")
meta('house_of_caiaphas', 'confidenceLevel', 'Strong')
setf('house_of_caiaphas', 'summary',
     "A family tomb accidentally exposed by road work in south Jerusalem in 1990, containing twelve ossuaries. One ornate ossuary is inscribed on two sides with variants of 'Joseph son of Caiaphas', a name that many scholars link to the high priest who presided over Jesus' trial.",
     "1990年耶路撒冷南部修路时意外发掘出的家族墓室，内有十二件骨匣。其中一件华丽的骨匣在两个侧面刻有「约瑟·该亚法之子」的不同写法，许多学者把这一名字与审判耶稣的大祭司联系起来。")
para('house_of_caiaphas', 'description', 'The ornate ossuary contained', '华丽的骨匣盛装',
     "The ornate ossuary contained the bones of a man around 60 years old, consistent with the lifetime of Caiaphas, who served as high priest from 18 to 36 CE. Some scholars doubt that it belongs to the Joseph Caiaphas known from Josephus and the Gospels, citing the spelling, the missing title 'priest' and the plain tomb (Caiaphas may also be a family name), while many regard the identification as probable.",
     "华丽的骨匣盛装一名年约六十岁男性的骸骨，与公元18—36年间任大祭司的该亚法之生平相符。一些学者质疑它是否属于约瑟夫与福音书所记的约瑟·该亚法，理由是拼写、没有“祭司”头衔以及墓室简朴（“该亚法”也可能是家族名）；但许多学者认为这一认定很有可能成立。")


# ---------------------------------------------------------------- rylands_papyrus (P52)
# Date rests on palaeography alone: usually early-mid 2nd c. (traditionally c.125 CE), possibly late 1st-early 3rd c.
# Nongbri, "The Use and Abuse of P52", Harvard Theological Review 98 (2005). https://en.wikipedia.org/wiki/Rylands_Library_Papyrus_P52
meta('rylands_papyrus', 'confidenceLevel', 'Strong')
setf('rylands_papyrus', 'summary',
     "This small papyrus fragment, acquired in 1920, is generally accepted as the earliest surviving fragment of a New Testament text. Handwriting dates it to the early or mid 2nd century CE (traditionally about 125 CE). It contains verses from John's Gospel, showing that the Gospel was being copied and read in Egypt by the 2nd century.",
     "这份于1920年购得的小型纸莎草残片，被普遍认为是现存最早的新约经文残片。依笔迹，它被定在公元2世纪早期或中期（传统上约为公元125年）。它包含约翰福音的经文，表明该福音书至迟在2世纪已在埃及被抄写和阅读。")
para('rylands_papyrus', 'description', 'The Rylands Papyrus P52', '赖兰纸莎草残片P52',
     "The Rylands Papyrus P52, also known as the St John Fragment, was acquired by the John Rylands Library in Manchester in 1920 from a collection of papyri purchased on the Egyptian antiquities market. It was first identified and published by C.H. Roberts in 1935. Its date rests on palaeography alone (the study of ancient handwriting): it is usually placed in the early to mid 2nd century CE, traditionally about 125 CE, and it is generally accepted as the earliest surviving fragment of a New Testament text. Brent Nongbri has argued that handwriting cannot fix so precise a date and that the possible range extends into the 3rd century.",
     "赖兰纸莎草残片P52，亦称圣约翰残片，于1920年由曼彻斯特的约翰·赖兰图书馆从埃及文物市场购得的一批纸莎草文献中获得。它由C.H.罗伯茨于1935年首次鉴定并发表。它的年代仅凭古文字学（对古代手稿笔迹的研究）判断：通常被定在公元2世纪早期至中期，传统上约为公元125年，并被普遍认为是现存最早的新约经文残片。布伦特·农布里（Brent Nongbri）指出，仅凭笔迹无法确定如此精确的年代，可能的范围可延伸到3世纪。")
para('rylands_papyrus', 'description', 'The definitive dating of P52', 'P52的明确年代测定',
     "Even allowing for the uncertainty of palaeographic dating, P52 matters for New Testament textual criticism. It is early evidence that the Gospel of John was being copied and read in Egypt, and it weighs against theories of a much later date of composition for that Gospel.",
     "即使考虑到笔迹断代的不确定性，P52对新约文本批判学仍很重要。它是约翰福音已在埃及被抄写和阅读的早期证据，也不利于认为该福音书成书晚得多的理论。")
source('rylands_papyrus', 'Nongbri, Brent.',
       'Nongbri, Brent. "The Use and Abuse of P52: Papyrological Pitfalls in the Dating of the Fourth Gospel." Harvard Theological Review 98 (2005).')

# ---------------------------------------------------------------- thallus_fragment
# Known only via Syncellus quoting Africanus; Africanus objected that an eclipse is impossible at Passover; Thallus's date
# and whether he referred to the crucifixion darkness are disputed. https://en.wikipedia.org/wiki/Thallus_(historian)
setf('thallus_fragment', 'summary',
     "A passage preserved by the 9th-century chronicler Syncellus, quoting Julius Africanus, says a historian named Thallus called 'this darkness', which Africanus takes to be the darkness at Jesus' death, an eclipse of the sun. Who Thallus was, when he wrote and whether he meant the crucifixion are all uncertain, so this is weak, circumstantial evidence.",
     "9世纪编年史家辛塞鲁斯保存的一段话引用尤利乌斯·阿非利加努斯的说法：一位名叫塔勒斯的历史学家把“这黑暗”称为日食，阿非利加努斯认为那指的是耶稣受难时的黑暗。塔勒斯是谁、写于何时、是否指受难，都不确定，因此这只是薄弱的间接证据。")
para('thallus_fragment', 'description', 'The "Thallus fragment"', '“塔勒斯残篇”',
     "The \"Thallus fragment\" is not a physical discovery but a citation from a lost work by a historian named Thallus. His \"Histories\" covered the history of the Mediterranean world; when he wrote is uncertain, and most scholars place it around the middle of the 1st century CE (about 52 CE). The fragment survives only in the 9th-century chronicler George Syncellus, who quotes the Christian historian Julius Africanus (writing about 221 CE). Africanus says that Thallus, in the third book of his Histories, calls \"this darkness\" an eclipse of the sun, and Africanus understands it to be the darkness at Jesus' death.",
     "“塔勒斯残篇”并非实物发现，而是对一位名叫塔勒斯的历史学家失传著作的引用。他的《历史》涵盖地中海世界的历史；他写于何时并不确定，多数学者把它定在公元1世纪中叶（约公元52年）。该残篇只保存在9世纪编年史家乔治·辛塞鲁斯的著作里，他引用了基督教历史学家尤利乌斯·阿非利加努斯（约公元221年撰写）的话。阿非利加努斯说，塔勒斯在他《历史》第三卷中把“这黑暗”称为日食，而阿非利加努斯理解那就是耶稣受难时的黑暗。")
para('thallus_fragment', 'description', "Thallus's original work is lost", '塔勒斯的原始著作已失传',
     "Thallus's original work is lost, and we know of this reference only through Africanus and Syncellus. Africanus himself objected that Thallus's explanation was without reason, because a solar eclipse cannot happen at Passover, when the moon is full. Thallus's identity and date are not secure, and some scholars think that the link with the crucifixion darkness is an inference by Africanus or Syncellus rather than Thallus's own statement.",
     "塔勒斯的原始著作已失传，我们只能通过阿非利加努斯和辛塞鲁斯得知这一记载。阿非利加努斯本人就反对塔勒斯的说法，认为这没有道理，因为逾越节时是满月，不可能发生日食。塔勒斯的身份和年代并不确定，一些学者认为，把它与受难时的黑暗联系起来，是阿非利加努斯或辛塞鲁斯的推断，而不是塔勒斯自己的说法。")
para('thallus_fragment', 'description', 'The significance of this fragment', '这一残篇的重要性',
     "If Thallus did refer to the darkness at Jesus' death, it would be an early non-Christian attempt to explain it naturally, and would at least show that such a darkness was being discussed. But the evidence is thin and indirect, so it is classed as circumstantial: it is not an independent eyewitness record, and it does not confirm the Gospel account.",
     "如果塔勒斯确实提到了耶稣受难时的黑暗，那将是早期非基督徒用自然原因解释它的一次尝试，至少说明当时有人在讨论这样的黑暗。但证据单薄而且是间接的，所以只列为间接证据：它不是独立的目击记录，也不能证实福音书的记载。")
para('thallus_fragment', 'scripturalCorrelation', 'This biblical account of a widespread darkness', '圣经中对普遍黑暗的记载',
     "The Gospel account of a widespread darkness is what Africanus connects with Thallus's remark. Because the fragment survives only at second hand, and the words attributed to Thallus ('this darkness') do not name Jesus, it lends the Gospel description only weak, indirect support.",
     "福音书所记的大范围黑暗，正是阿非利加努斯与塔勒斯那句话联系起来的内容。由于该残篇只是转述，而且归于塔勒斯名下的话（“这黑暗”）并没有提到耶稣，它只能为福音书的描述提供薄弱而间接的支持。")

# ---------------------------------------------------------------- nazareth_inscription
# 2020 isotope study (Harper, McCormick, Hamilton, Peiffert, Michels, Engel), J. Archaeological Science: Reports,
# doi:10.1016/j.jasrep.2020.102228: marble from the upper quarry of Kos; edict proposed as Augustan, after the desecration
# of the tomb of the Kos tyrant Nikias c. 20 BCE. https://en.wikipedia.org/wiki/Nazareth_Inscription ;
# https://www.smithsonianmag.com/smart-news/new-analysis-refutes-nazareth-inscriptions-ties-jesus-death-180974485/
meta('nazareth_inscription', 'confidenceLevel', 'Circumstantial')
setf('nazareth_inscription', 'summary',
     "A marble slab bearing a Greek imperial edict that threatens capital punishment for tomb violation. It reached Paris in 1878 as 'sent from Nazareth', but a 2020 isotope study traced its marble to the Greek island of Kos, and the old suggestion that it answered reports of Jesus' resurrection is now in serious doubt.",
     "一块刻有希腊文帝国敕令的大理石板，以死刑威胁毁坏坟墓的行为。它在1878年以“自拿撒勒寄出”的名义到达巴黎，但2020年的同位素研究把它的大理石追溯到希腊的科斯岛，而它曾被认为是回应耶稣复活传闻的旧说，现在受到严重质疑。")
para('nazareth_inscription', 'description', 'The Nazareth Inscription is a marble tablet', '拿撒勒铭文是一块',
     "The Nazareth Inscription is a marble tablet bearing a Greek text, acquired by the collector Wilhelm Fröhner in 1878, with a note that it was sent from Nazareth, and published by Franz Cumont in 1930 after it entered the Bibliothèque nationale de France. The inscription measures about 37 × 60 cm. The note shows where it was shipped from, not necessarily where it was found, and its true findspot is unknown.",
     "拿撒勒铭文是一块刻有希腊文的大理石碑，收藏家威廉·弗勒纳于1878年获得，并附有注明“自拿撒勒寄出”的记录；它进入法国国家图书馆后，由弗朗茨·库蒙于1930年发表。铭文尺寸约37×60厘米。那条记录只说明它从哪里寄出，不一定是它的出土地，其真正的出土地点不详。")
para('nazareth_inscription', 'description', 'A 2020 geochemical study', '2020年一项',
     "In 2020 Kyle Harper, Michael McCormick and colleagues published a stable-isotope study (Journal of Archaeological Science: Reports) that traced the marble to the upper quarry of the Greek island of Kos, not to Galilee. They proposed that the edict was issued by Augustus after the grave of the Kos tyrant Nikias was desecrated, about 20 BCE. On the lettering, earlier scholars dated the text to the first half of the 1st century CE; Cumont thought of Augustus, others of Claudius (41–54 CE). The text never mentions Jesus, so the link with him was only ever a suggestion.",
     "2020年，凯尔·哈珀、迈克尔·麦科密克等人发表了一项稳定同位素研究（《考古科学杂志：报告》），把这块大理石追溯到希腊科斯岛的上采石场，而不是加利利。他们提出，该敕令是奥古斯都在科斯岛僭主尼基亚斯的坟墓遭亵渎（约公元前20年）之后颁布的。此前学者依字体把文本定在公元1世纪上半叶；库蒙认为是奥古斯都，另一些人认为是克劳狄乌斯（公元41—54年）。文本从未提到耶稣，所以它与耶稣的联系始终只是一种推测。")
para('nazareth_inscription', 'scripturalCorrelation', 'If the Nazareth Inscription does originate', '如果拿撒勒铭文确实源自拿撒勒',
     "Some New Testament scholars suggested that the edict could be an imperial reaction to the claim that Jesus' body had been stolen. That is now hard to maintain: the text never mentions Jesus, the findspot is unknown, and the marble came from Kos. The inscription remains of interest for Roman attitudes to tomb violation in the eastern Mediterranean, but it is not evidence for the resurrection narrative.",
     "一些新约学者曾提出，这份敕令可能是帝国对“耶稣的遗体被偷走”之说的反应。现在这一点很难成立：文本从未提到耶稣，出土地点不明，大理石又来自科斯岛。这块铭文仍有助于了解罗马对东地中海坟墓被毁行为的态度，但它不是复活记载的证据。")
source('nazareth_inscription', 'Clarysse, Willy, and Mark Depauw.',
       'Harper, Kyle, Michael McCormick, Matthew Hamilton, Chantal Peiffert, Raymond Michels, and Michael Engel. "Establishing the provenance of the Nazareth Inscription: Using stable isotopes to resolve a historic controversy and trace ancient marble production." Journal of Archaeological Science: Reports (2020), doi:10.1016/j.jasrep.2020.102228.')

# ---------------------------------------------------------------- nag_hammadi_codices
# The Gospel of Mary is not among the Nag Hammadi codices (Berlin Codex / Oxyrhynchus); the Gospel of Truth is.
setf('nag_hammadi_codices', 'summary',
     "Thirteen leather-bound codices discovered at Nag Hammadi, Egypt in 1945 contain over 50 texts, including Gnostic gospels (Thomas, Philip, Truth) and numerous other writings. They are not canonical, and they illuminate the diverse religious landscape of early Christianity, in which the New Testament writings circulated alongside many others.",
     "1945年在埃及拿戈哈马迪发现的13部皮革装订抄本包含50多份文本，其中有诺斯替福音书（多马福音、腓力福音、真理福音）和许多其他著作。它们不属正典，却展现了早期基督教多元的宗教环境：新约各书当时与许多别的著作一起流传。")
sub('nag_hammadi_codices', 'description',
    "(5) The codices confirm that the early Church's selection of canonical texts was not arbitrary but reflected genuine criteria of apostolic authorship, widespread use, and theological consistency with Hebrew Scripture.",
    "(5) The codices show that many other gospels and revelations circulated alongside the writings that became the New Testament. Early church writers explained their choice of canonical books by criteria such as apostolic connection, wide use and agreement with the faith they had received; scholars debate how consistently those criteria worked.",
    "（5）抄本确认早期教会选择正典文本并非随意，而是反映了使徒作者身份、广泛使用和与希伯来圣经神学一致性的真正标准。",
    "（5）这些抄本表明，除了后来成为新约的那些著作之外，还有许多别的福音书和启示书在流传。早期教会作家用使徒渊源、广泛使用以及与所领受的信仰相符等标准来说明他们为何选定正典书卷；这些标准实际执行得多么一致，学者仍有讨论。")


# ---------------------------------------------------------------- sodom_gomorrah_evidence
# Repeated the retracted Tall el-Hammam airburst paper as evidence (see tall_el_hammam). Excavators' own figures
# (layer thickness, population, occupation gap) are not independently confirmed, so they are attributed, not asserted.
setf('sodom_gomorrah_evidence', 'summary',
     "Tall el-Hammam in Jordan, a large Middle Bronze Age city northeast of the Dead Sea, is proposed by its excavators as biblical Sodom. A 2021 paper claimed a cosmic airburst destroyed it, but the journal retracted that paper in April 2025, and the identification with Sodom remains a minority view.",
     "约旦的特尔哈曼是死海东北的一座大型青铜时代中期城市，其发掘者提出它就是圣经中的所多玛。2021年有论文主张它毁于宇宙空爆，但期刊已于2025年4月撤回该论文；把它认定为所多玛，至今仍是少数派观点。")
setf('sodom_gomorrah_evidence', 'description',
     "The biblical account of Sodom and Gomorrah (Genesis 19:24-28) describes fire and sulfur raining down from heaven on the cities. Tall el-Hammam is a large Bronze Age site in the Jordan Valley northeast of the Dead Sea, excavated since 2005 by a team led by Steven Collins and Phillip Silvia, who identify it with Sodom.\n\nWhat the excavators report is a major fortified city with a palace complex, abandoned around 1650 BCE (Middle Bronze Age II) after a destruction layer containing ash, charred material and debris, with pottery and mudbrick that they interpret as having been heated to very high temperatures, and a long gap in occupation afterwards. These are the excavation team's own claims; the thickness of the layer, the population estimates and the length of the gap have not been independently confirmed.\n\nIn 2021 Scientific Reports published a paper by Ted Bunch and colleagues arguing that a cosmic airburst like the 1908 Tunguska event destroyed the city, citing shocked quartz, melted material and other markers. Other scientists disputed the data, and on 24 April 2025 the journal retracted the paper because its claims were not sufficiently supported by the data. The airburst explanation is therefore not established and cannot be used as evidence for Genesis 19.\n\nThe identification of Tall el-Hammam with Sodom is a minority position, and other sites, including some on the southern shore of the Dead Sea, have been proposed. The Jordan Valley setting does fit the 'cities of the plain' of Genesis 13 and 19, and Genesis 19:28 describes smoke rising from the land like smoke from a furnace, but the evidence cannot show that a destruction at this site is the event behind the narrative.",
     "圣经关于所多玛和蛾摩拉的记载（创世记19:24-28）描述有火与硫磺从天降在这些城上。特尔哈曼是约旦河谷、死海东北的一处大型青铜时代遗址，自2005年起由史蒂文·柯林斯和菲利普·席尔维亚领导的团队发掘，他们把它认定为所多玛。\n\n发掘者报告的情况是：一座设有宫殿建筑群的大型设防城市，约在公元前1650年（中青铜时代II）被废弃，其前有含灰烬、炭化物和碎片的毁坏层，陶器和泥砖据他们解释曾受极高温加热，此后有很长的无人居住期。这些都是发掘团队自己的说法；毁坏层的厚度、人口估算和空白期的长度都没有得到独立证实。\n\n2021年，《科学报告》发表了特德·邦奇等人的论文，主张与1908年通古斯事件相仿的宇宙空爆摧毁了该城，所举证据包括冲击石英、熔融物等标志。其他科学家对数据提出异议，期刊于2025年4月24日以“其主张没有得到数据的充分支持”为由撤回了该论文。因此，空爆说并未确立，也不能用作创世记19章的证据。\n\n把特尔哈曼认定为所多玛是少数派观点，死海南岸的一些遗址也曾被提为候选。约旦河谷的位置确实符合创世记13章和19章的“平原诸城”，创世记19:28也描述烟气从地上腾起，如同烧窑的烟；但现有证据无法表明这处遗址的毁坏就是叙事背后的事件。")
setf('sodom_gomorrah_evidence', 'scripturalCorrelation',
     "Genesis 19:24-28 describes fire and sulfur from heaven falling on Sodom and Gomorrah, and Abraham seeing smoke rising from the land like smoke from a furnace. The Jordan Valley setting of Tall el-Hammam fits the 'cities of the plain' of Genesis 13 and 19, but the 2021 airburst paper that was used to link its destruction with the narrative was retracted in 2025, so the evidence for a destruction that matches Genesis 19 is not established.",
     "创世记19:24-28描述有火与硫磺从天降在所多玛和蛾摩拉上，亚伯拉罕看见烟气从地上腾起，如同烧窑的烟。特尔哈曼所在的约旦河谷符合创世记13章和19章的“平原诸城”，但曾被用来把它的毁坏与这段叙事联系起来的2021年空爆论文已于2025年被撤回，因此与创世记19章相符的毁坏证据并未确立。")
source('sodom_gomorrah_evidence', 'Bunch, Ted E., et al. "Widespread Rampart Destruction."',
       'Bunch, Ted E., et al. "A Tunguska sized airburst destroyed Tall el-Hammam a Middle Bronze Age city in the Jordan Valley near the Dead Sea." Scientific Reports 11 (2021), doi:10.1038/s41598-021-97778-3. Retracted 24 April 2025: Retraction Note, Scientific Reports 15, 14291 (2025), doi:10.1038/s41598-025-99265-5.')


# ---------------------------------------------------------------- citation fixes (verified 2026-10-04)
# Bethlehem bulla: IEJ 62.2 (2012) 200-205, "A fiscal bulla from the City of David, Jerusalem", by Ronny Reich
# (https://cris.haifa.ac.il/en/publications/a-fiscal-bulla-from-the-city-of-david-jerusalem/).
source('bethlehem_bulla', 'Vainstub, Daniel.',
       'Reich, Ronny. "A Fiscal Bulla from the City of David, Jerusalem." Israel Exploration Journal 62.2 (2012): 200–205.')
# Joshua's long day: the Humphreys paper that exists is Humphreys & Waddington 2017 (Astronomy & Geophysics), which proposes
# a solar eclipse on 30 Oct 1207 BC; the proposal is disputed. The listed 'Science and Christian Belief 23 (2011)' title was not found.
source('joshua_long_day', 'Humphreys, Colin J.',
       'Humphreys, Colin J., and W. Graeme Waddington. "Solar eclipse of 1207 BC helps to date pharaohs." Astronomy & Geophysics 58.5 (2017). (Proposes that the Hebrew of Joshua 10:12-13 describes a solar eclipse; the proposal is disputed.)')
# Nebo-Sarsekim: Jursa's note is NABU 2008/5 (title in the entry was not found).
source('nebo_sarsekim_tablet', 'Jursa, Michael.',
       'Jursa, Michael. Note on the Babylonian receipt naming Nabu-sharrussu-ukin, the chief eunuch (Nebo-Sarsekim of Jeremiah 39:3). NABU 2008/5.')
# Circumcision on day 8: the 'prothrombin 110% on day 8' claim comes from popular books, not current paediatrics.
meta('circumcision_day_8', 'confidenceLevel', 'Circumstantial')
setf('circumcision_day_8', 'summary',
     "The Bible commands circumcision on the eighth day (Genesis 17:12). A popular argument says this timing matches a peak in a newborn's blood-clotting factors, but current medical evidence does not support that claim, so it is not offered as scientific confirmation of the Bible.",
     "圣经命令在第八天行割礼（创世记17:12）。一种流行的说法认为这个时间恰好对应新生儿凝血因子的峰值，但目前的医学证据并不支持这种说法，因此这里不把它当作圣经得到科学证实的证据。")
setf('circumcision_day_8', 'description',
     "A frequently repeated argument holds that the eighth day is medically ideal for circumcision because vitamin K and prothrombin supposedly peak then, at '110% of normal'. That figure comes from popular books and apologetic writing, not from current paediatric evidence.\n\nNewborns do have low vitamin K, which is why vitamin K is now routinely given to babies at birth: vitamin K deficiency bleeding can occur at any time in the first weeks of life, not only before the eighth day. Current medical guidance does not identify day 8 as a point of guaranteed clotting safety.\n\nThe commandment in Genesis 17:12 stands on its own as a covenant sign. This entry therefore treats the medical argument as a claim that has been made, not as scientific confirmation of the Bible.",
     "有一种常被重复的论点认为，第八天对割礼来说在医学上是最佳时间，因为维生素K和凝血酶原据说在这一天达到峰值，即“正常值的110%”。这个数字来自通俗读物和护教文章，而不是当前的儿科证据。\n\n新生儿的维生素K确实偏低，所以现在给新生儿常规在出生时补充维生素K：维生素K缺乏性出血可能发生在出生后头几周的任何时候，而不只是在第八天之前。目前的医学指南并没有把第八天认定为凝血绝对安全的时间点。\n\n创世记17:12的诫命本身就是立约的记号，不需要这类医学论证。因此本条目把这一医学论点当作“曾被提出的说法”，而不是圣经得到科学证实的证据。")
para('circumcision_day_8', 'scripturalCorrelation', 'The precise instruction for the eighth day', '第八天而非出生后立即或更晚',
     "The command itself is clear. Claims that the eighth day coincides with a peak in clotting factors are not supported by current medical evidence, so they are not offered here as proof of the passage.",
     "这条命令本身是清楚的。至于第八天恰逢凝血因子峰值的说法，目前的医学证据并不支持，所以这里不把它当作这段经文的证明。")
source('circumcision_day_8', 'Ness, Robert B.',
       'American Academy of Pediatrics, Committee on Fetus and Newborn. "Controversies Concerning Vitamin K and the Newborn." Pediatrics 112 (2003): 191–192.')


# ---------------------------------------------------------------- golgotha_holy_sepulchre
# 2016 Edicule restoration (NTUA, A. Moropoulou): mortar dated by OSL (optically stimulated luminescence) in two labs to ~345 CE,
# other samples ~335 and ~1570 CE (NOT radiocarbon). https://www.nationalgeographic.com/news/2017/11/jesus-tomb-archaeology-jerusalem-christianity-rome/
# https://www.smithsonianmag.com/smart-news/mortar-found-jesus-tomb-dates-constantine-era-180967345/
# The zh text claimed Justin, Melito, Origen and Alexander of Jerusalem "unanimously located Golgotha at the present site" — not supported.
setf('golgotha_holy_sepulchre', 'summary',
     "Excavations beneath the Church of the Holy Sepulchre show that the site lay outside the 1st-century city walls (compare Hebrews 13:12) and was an abandoned quarry used for rock-cut tombs (compare John 19:41), and optical (OSL) dating of mortar from the Edicule, reported in 2017, points to building work around 345 CE, in the time of Constantine. The identification with Golgotha and the tomb of Jesus remains a tradition, not a proof.",
     "圣墓教堂之下的发掘表明，该地在公元1世纪位于城墙之外（参希伯来书13:12），是一座废弃的采石场，其中有岩凿墓穴（参约翰福音19:41）；2017年公布的对圣墓小堂灰浆的光释光（OSL）测年，则指向约公元345年君士坦丁时代的建造工程。把这里认定为各各他和耶稣的坟墓，仍属传统，而不是已被证明的事实。")
para('golgotha_holy_sepulchre', 'description', '#1', '#1',
     "Archaeology is consistent with the tradition at several points, though it cannot prove it:",
     "考古发现在几个方面与这一传统相符，但并不能证明它：")
para('golgotha_holy_sepulchre', 'description', '(4) 2016 Edicule radiocarbon study', '**2016年恢复分析**',
     "(4) 2016 Edicule restoration: Antonia Moropoulou (National Technical University of Athens) led a team that opened the tomb in October 2016 and took mortar samples from the structures enclosing it. Two laboratories dated the mortar by optically stimulated luminescence (OSL), a method that dates when quartz grains were last exposed to light. The earliest samples gave about 345 CE, which fits the time of Constantine; other samples gave about 335 CE and 1570 CE, the latter matching a documented restoration. This supports building work around the tomb in Constantine's time; it does not date the cutting of the tomb itself.",
     "**2016年修复**：国立雅典理工大学的安东尼娅·莫罗普卢（Antonia Moropoulou）领导的团队于2016年10月打开了坟墓，并从包围坟墓的结构上采集了灰浆样品。两家实验室用光释光（OSL，测定石英颗粒最后一次见光的时间）法对灰浆测年：最早的样品约为公元345年，与君士坦丁时代相符；其他样品约为公元335年和1570年，后者与有记载的一次修复吻合。这支持了君士坦丁时代在墓周围的建造工程，但并不能确定墓穴本身开凿的年代。")
source('golgotha_holy_sepulchre', 'Moropoulou, Antonia et al.',
       'Moropoulou, Antonia et al. "Non-destructive dating of mortars from the Edicule of the Holy Sepulchre." Journal of Archaeological Science 81, 2017. [Citation not independently verified in the 2026 audit; the OSL dating itself is reported by National Geographic (2017) and Smithsonian Magazine (2017).]')

# ---------------------------------------------------------------- house_of_peter
# Corbo/Loffreda: domus-ecclesia from the end of the 1st c. CE; graffiti are Christian-phase; reading of the name Peter is doubted.
# https://dig.corps-cmhl.huji.ac.il/rep_church_full/15904 ; https://madainproject.com/house_of_saint_peter
meta('house_of_peter', 'confidenceLevel', 'Circumstantial')
setf('house_of_peter', 'summary',
     "Excavations beneath a Byzantine church at Capernaum revealed a 1st-century house that was later turned into a place of Christian worship, with graffiti that include the name of Jesus. It is traditionally identified as the house of the Apostle Peter mentioned in the Gospels, but the excavators' reading of the name 'Peter' is doubted by other scholars.",
     "迦百农一座拜占庭教堂下方的发掘揭示了一座1世纪的房屋，后来被改作基督徒的敬拜场所，墙上涂鸦中有耶稣的名字。传统上认为它就是福音书所载使徒彼得的住所，但发掘者对“彼得”这个名字的释读，受到其他学者质疑。")
para('house_of_peter', 'description', '#1', '#1',
     "The Franciscan excavators date the first phase of the house to the 1st century BCE and say that from the end of the 1st century CE part of it was turned into a domus-ecclesia (house church): the floor was plastered repeatedly, which is unusual for a home, and cooking pottery disappeared while storage and serving vessels multiplied. In the 4th century the house church was enlarged and walled off from the village, and in the later 5th century everything was demolished and the octagonal church built. The graffiti on the plaster, in Greek, Aramaic, Syriac and Latin, include the name and monogram of Jesus, liturgical formulas such as Amen and Kyrie eleison, and an inscription in Syriac script that appears to refer to the Eucharist. They come from the Christian use of the room, not from an ordinary household, and other scholars find little evidence for the excavators' reading of the name Peter among them.",
     "方济各会的发掘者把这座房屋的第一阶段定在公元前1世纪，并认为从公元1世纪末起，其中一部分被改作“家庭教会”（domus-ecclesia）：地面被反复抹灰（对住宅来说不寻常），烹饪陶器消失，储藏和盛放器皿增多。4世纪时这座家庭教会被扩建，并用围墙与村庄隔开；5世纪后期整片建筑被拆除，建起了八角形教堂。灰泥墙上用希腊文、亚兰文、叙利亚文和拉丁文写的涂鸦，包括耶稣的名字和圣名字母组合、“阿们”“求主怜悯”等礼仪用语，以及一句似乎涉及圣餐的叙利亚字体铭文。它们出自这个房间被基督徒使用的时期，而不是普通的家庭生活；至于发掘者所读出的“彼得”之名，另一些学者认为证据很少。")
para('house_of_peter', 'description', '#2', '#2',
     "The octagonal Byzantine church (a plan typically used to mark a sacred site) built directly over the room, together with a tradition from the 4th century CE identifying the site as the house of Peter, offers circumstantial support for the identification. The site is now under a modern Franciscan church with a glass floor permitting visitors to view the excavations below.",
     "直接建在这个房间之上的八角形拜占庭教堂（通常用于标记圣地的建筑形制），加上自4世纪以来认定此处为彼得住所的传统，为这一认定提供了间接的支持。遗址上现建有现代方济各会教堂，设有玻璃地板，供访客观看下方的发掘遗迹。")
para('house_of_peter', 'scripturalCorrelation', '#1', '#1',
     "The excavated structure at Capernaum lies next to the remains of the ancient synagogue, which fits the spatial relationship described in Mark 1:29. The conversion of the house into a Christian meeting place, which the excavators date from the end of the 1st century CE, is consistent with early veneration of a house associated with Peter, but it does not by itself prove that this was Peter's house.",
     "迦百农这处发掘出的建筑紧邻古代犹太会堂遗址，与马可福音1:29所描述的空间关系相符。发掘者认为这座房屋自公元1世纪末起被改作基督徒的聚会场所，这与人们很早就崇敬一座与彼得有关的房屋并不矛盾，但这本身并不能证明它就是彼得的家。")

# ---------------------------------------------------------------- capernaum_synagogue
meta('capernaum_synagogue', 'confidenceLevel', 'Strong')
setf('capernaum_synagogue', 'summary',
     "Excavations at Capernaum show a 4th–5th-century white limestone synagogue standing on the remains of a 1st-century basalt structure that the Franciscan excavators identify as an earlier synagogue, plausibly the building in which Jesus taught according to the Gospels, although the dating and the identification are debated.",
     "迦百农的发掘显示，一座4至5世纪的白色石灰岩犹太会堂建在一座1世纪玄武岩建筑的遗迹之上；方济各会的发掘者把后者认定为更早的会堂，很可能就是福音书所载耶稣在其中教导的那座建筑，但年代和认定都有争议。")
para('capernaum_synagogue', 'description', '#1', '#1',
     "The visible white limestone synagogue is dated by its Franciscan excavators to the 4th–5th century CE and is one of the best-preserved ancient synagogues in Israel; scholarly opinion on its date has ranged from the 2nd to the 5th century. Beneath its foundations, excavations in the 1960s–80s revealed the black basalt foundations and a cobble floor of an earlier hall, which the excavators date to the late Second Temple period (1st century BCE–1st century CE) from ceramics, coins and stratigraphy and identify as an earlier synagogue. That the earlier hall is the synagogue of the Gospels is an inference, not a proven fact.",
     "可见的白色石灰岩犹太会堂，其方济各会发掘者把它定在公元4至5世纪，它是以色列保存最完好的古代犹太会堂之一；学界对其年代的看法曾从2世纪到5世纪不等。在其地基之下，1960至80年代的发掘揭露出一座更早大厅的黑色玄武岩基址和卵石地面；发掘者依据陶器、钱币和地层，把它定在第二圣殿晚期（公元前1世纪至公元1世纪），并认定为更早的会堂。至于这座更早的大厅是否就是福音书所载的会堂，只是一种推断，而非已证明的事实。")


# Chinese-only corrections in golgotha_holy_sepulchre (the English text has no counterpart for these claims).
sub('golgotha_holy_sepulchre', 'description', None, None,
    "**早期传统（公元2世纪）**：殉道者游斯丁（约150年）、萨迪斯主教米力图（约170年）和俄利根（约235年）都将各各他定位于现今地点。耶路撒冷主教亚历山大（约212年）在就任时前来崇敬。",
    "**早期传统**：公元2世纪起已有基督徒到耶路撒冷朝圣（例如撒狄主教米力图约在公元170年前后到访过），但现存的君士坦丁时代之前的文献并没有明确指出圣墓教堂所在的地点；把这里与耶稣的坟墓明确联系起来的最早记载，是优西比乌（《君士坦丁传》）对君士坦丁时代发掘的叙述。")
sub('golgotha_holy_sepulchre', 'description', None, None,
    "反证明基督徒在公元135年前已持续认定此为圣地。",
    "有人据此推论基督徒在公元135年之前已把这里视为圣地，但这属于推论。")
sub('golgotha_holy_sepulchre', 'description', None, None,
    "优西比乌（《君士坦丁传》3.25-28）亲眼目睹整个过程。",
    "优西比乌（《君士坦丁传》3.25-28）记述了这一过程。")
sub('golgotha_holy_sepulchre', 'summary', None, None, None, None) if False else None


# ---------------------------------------------------------------- transfiguration_mount_tabor
# zh said "Bagatti excavations 1921-24" (those years are Barluzzi's building of the present church), "Arculf, 6th-century" pilgrim
# (Arculf is 7th c.), "martyr Origen". Verified: Barluzzi built the church 1921-24 on Byzantine (5th/6th c.) and Crusader ruins; the
# Piacenza pilgrim (c.570) saw three basilicas. https://custodia.org/en/sanctuaries/mount-tabor
setf('transfiguration_mount_tabor', 'summary',
     "Mount Tabor in Lower Galilee, identified as the transfiguration site by Origen, Cyril of Jerusalem (c. 348 CE) and Jerome, preserves Byzantine and Crusader church remains and has kept Christian veneration for over 1,600 years.",
     "下加利利的他泊山被俄利根、耶路撒冷的区利罗（约公元348年）和耶柔米认定为耶稣变像之地，保存着拜占庭和十字军时期的教堂遗迹，基督徒的崇敬延续了1600多年。")
para('transfiguration_mount_tabor', 'description', 'Origen (3rd century CE)', '#1',
     "Origen (3rd century CE) is the earliest extant witness to this identification. Cyril of Jerusalem (Catechetical Lectures 12.16, c. 348 CE) explicitly names Tabor as the transfiguration mountain, and Jerome, writing from Bethlehem, likewise confirms the tradition. Byzantine churches stood on the summit: an anonymous pilgrim from Piacenza (c. 570 CE) saw three basilicas there, which tradition linked to Peter's proposal to build 'three tents' (Matthew 17:4), and 20th-century excavations by Bellarmino Bagatti documented Byzantine foundations.",
     "俄利根（3世纪）是这一认定现存最早的见证。耶路撒冷的区利罗（《教理讲授》12.16，约公元348年）明确点名他泊山为变像之山，在伯利恒写作的耶柔米同样确认了这一传统。山顶曾有拜占庭教堂：一位来自皮亚琴察的匿名朝圣者（约公元570年）在那里看到三座大教堂，传统把它们与彼得提议搭“三座棚”（马太福音17:4）联系起来；20世纪贝拉米诺·巴加蒂（Bellarmino Bagatti）的发掘也记录了拜占庭时期的地基。")
para('transfiguration_mount_tabor', 'description', 'The Crusaders rebuilt', '#2',
     "The Crusaders rebuilt the monastic complex in the 12th century, and the present Franciscan Church of the Transfiguration (built 1921–24 by the architect Antonio Barluzzi) stands on Byzantine and Crusader ruins. The summit's flat plateau (approximately 1 km × 400 m) accommodates the narrative requirement of a 'high mountain' apart from settled areas.",
     "十字军在12世纪重建了修道院建筑群；现今的方济各会变像教堂（1921至1924年由建筑师安东尼奥·巴卢齐建造）坐落在拜占庭和十字军时期的废墟之上。山顶平坦的高地（约1公里×400米）符合叙事中远离居民点的“高山”。")
sub('transfiguration_mount_tabor', 'scripturalCorrelation', None, None,
    "4世纪拜占庭、十字军和现代方济各会三层教堂遗迹", "拜占庭、十字军和现代方济各会三层教堂遗迹")


# ---------------------------------------------------------------- bronze_serpent_timna
# Removed: an invented-looking Rothenberg quote ("shocking coincidence or proof of the truth of the biblical text"), the claim that the
# gilded snake is unique in the Near East (serpent figures are known from other Canaanite sites), "precisely the right place and
# period", "Solomon's era precisely", and the unreconciled 1969/1974 dates. Verified: Hathor temple Site 200 (Seti I) reused as a
# desert tent-shrine; copper snake with gilded head found in it. https://madainproject.com/hathor_shrine_(timna)
meta('bronze_serpent_timna', 'confidenceLevel', 'Circumstantial')
meta('bronze_serpent_timna', 'discoveryDate', "Beno Rothenberg's Timna excavations (1959–1990), Site 200", '贝诺·罗滕伯格的提姆纳发掘（1959—1990年），Site 200')
setf('bronze_serpent_timna', 'summary',
     "At Timna in the southern Arabah, Beno Rothenberg excavated an Egyptian temple of Hathor (Site 200) that was later reused as a desert tent-shrine, and recovered a small copper snake with a gilded head. It is an interesting parallel to the bronze serpent of Numbers 21:8-9 and 2 Kings 18:4, but snake figures are known from other Canaanite sites, and it is not evidence for the Numbers episode.",
     "在阿拉伯谷南部的提姆纳，贝诺·罗滕伯格发掘了一座埃及哈托尔神庙（Site 200），它后来被改作沙漠中的帐幕式神庙，其中出土了一条头部镀金的小铜蛇。它与民数记21:8-9和列王纪下18:4所记的铜蛇有趣地相似，但迦南其他遗址也有蛇形器物出土，它并不是民数记那段记载的证据。")
para('bronze_serpent_timna', 'description', 'From 1959-1990', '#1',
     "From 1959 to 1990 Beno Rothenberg directed the Arabah Expedition at Timna Valley (southern Negev), a copper-mining district exploited first by Egyptians and then by local peoples, whom Rothenberg identified as Midianites on the basis of a painted pottery known as Qurayya ware. At Site 200 he excavated a small Egyptian temple of Hathor, the goddess of miners, founded in the reign of Seti I.",
     "从1959到1990年，贝诺·罗滕伯格主持阿拉瓦考察队在提姆纳谷（内盖夫南部）发掘；那里是一个铜矿区，先由埃及人开采，后来由当地人群开采，罗滕伯格根据一种称为库赖亚（Qurayya）的彩陶，把这些当地人认定为米甸人。在Site 200，他发掘了一座小型埃及神庙，供奉矿工的女神哈托尔，始建于塞提一世时期。")
para('bronze_serpent_timna', 'description', '(1) The Hathor Temple', '#2',
     "After the Egyptians withdrew (around the middle of the 12th century BCE) the temple was reused as a desert tent-shrine: post-holes, decayed cloth and copper rings from curtains were found along two walls. In the shrine's inner niche Rothenberg's team found a small copper snake with a gilded head, together with a hoard of metal objects.",
     "埃及人撤出之后（约公元前12世纪中叶），这座神庙被改作沙漠中的帐幕式神庙：沿着两面墙发现了柱洞、腐朽的织物，以及悬挂帷幕用的铜环。在神庙内部的壁龛里，罗滕伯格的团队发现了一条头部镀金的小铜蛇，同时出土的还有一批金属器物。")
para('bronze_serpent_timna', 'description', '(2) The Bronze Serpent', '#3',
     "The snake is a small cultic object from the shrine's reuse phase. Snake figures are known from other Canaanite sites too, so it is not unique, and nothing links it to the object Moses made.",
     "这条蛇是该神庙改建时期的一件小型祭仪器物。迦南其他遗址也出土过蛇形器物，所以它并不独一无二，也没有任何东西把它与摩西所造的那条铜蛇联系起来。")
para('bronze_serpent_timna', 'description', '(3) Archaeological context', '#4',
     "Erez Ben-Yosef's renewed excavations (since 2013) at Timna Site 34 ('Slaves' Hill') show that copper production there flourished in the 11th–10th centuries BCE, and he dates its peak to the 10th century BCE. How the people who used the Timna shrine relate to the biblical Midianites is debated.",
     "埃雷兹·本-约瑟夫自2013年起在提姆纳Site 34（“奴隶之丘”）重新展开的发掘表明，当地铜的生产在公元前11至10世纪兴盛，他把其高峰定在公元前10世纪。使用提姆纳神庙的人群与圣经中的米甸人是什么关系，仍有争论。")
para('bronze_serpent_timna', 'description', '(4) 2 Kings 18:4', '#5',
     "2 Kings 18:4 records King Hezekiah destroying the bronze serpent (Nehushtan) that had become an object of worship. The Timna snake has no known connection with it.",
     "列王纪下18:4记载希西家王毁掉了已成为崇拜对象的铜蛇（Nehushtan）。提姆纳的这条蛇与它没有任何已知的联系。")
para('bronze_serpent_timna', 'scripturalCorrelation', 'Numbers 21:8-9 specifies', '#0',
     "Numbers 21:8-9 describes a bronze serpent raised on a pole. The Timna snake is a small copper figure with a gilded head from an Egyptian temple reused as a tent-shrine in the 12th century BCE, in the same broad region as the wilderness traditions. It shows that serpent figures belonged to the cult of the area, but it does not identify or confirm the object in Numbers.",
     "民数记21:8-9描述了挂在杆子上的铜蛇。提姆纳的这条蛇是一件头部镀金的小型铜像，出自公元前12世纪被改作帐幕式神庙的埃及神庙，所在的大致区域与旷野传统相同。它说明蛇形器物属于当地的祭仪，但并不能确认或证实民数记中所说的那件器物。")
para('bronze_serpent_timna', 'scripturalCorrelation', 'Midianites were Moses', '#1',
     "The Midianites appear as Moses's in-laws (Exodus 2–3; Numbers 10:29) and later as opponents (Numbers 25; 31), so a link between a Midianite shrine and the story is imaginable, but the identification of the Timna shrine's users as Midianites rests on Rothenberg's interpretation of the pottery.",
     "米甸人在圣经中先是摩西的姻亲（出埃及记2—3章；民数记10:29），后来成了对手（民数记25、31章），因此把一座米甸神庙与这段故事联系起来是可以想象的，但把提姆纳神庙的使用者认定为米甸人，依据的是罗滕伯格对陶器的解释。因此，提姆纳的发现至多只提供一种文化上的类比。本条目列为间接证据，是因为它既不能确定摩西的那条铜蛇，也不能表明民数记所述的事件曾经发生。")
para('bronze_serpent_timna', 'scripturalCorrelation', 'The discovery does not identify', '#2',
     "The Timna find therefore offers a cultural parallel at most. It is classed as circumstantial because it neither identifies Moses' serpent nor shows that the Numbers episode took place.",
     None)

# ---------------------------------------------------------------- jonah_nineveh
# Removed: "monotheistic-leaning worship of Nabu" under Adad-nirari III, "repentance fits the reform period", "confirming ... repentance
# ... exactly", "90 km district", and "abandonment confirmed by no Persian-period settlement". Nineveh fell 612 BCE (Fall of Nineveh Chronicle).
meta('jonah_nineveh', 'confidenceLevel', 'Circumstantial')
setf('jonah_nineveh', 'summary',
     "Austen Henry Layard's excavations from 1847 at Tell Kuyunjik uncovered the Assyrian capital Nineveh, including Sennacherib's 'Palace Without Rival', and Hormuzd Rassam later recovered much of Ashurbanipal's library of some 30,000 tablets. This confirms that Nineveh was a vast capital that fell in 612 BCE, but it does not by itself confirm the events of the book of Jonah.",
     "奥斯丁·亨利·莱亚德自1847年起在库云吉克废丘的发掘，揭示了亚述首都尼尼微，包括西拿基立的“无与伦比之宫”；后来霍尔穆兹·拉萨姆又找回了亚述巴尼拔图书馆约3万块泥板中的大部分。这证实了尼尼微是一座巨大的首都，并于公元前612年陷落，但本身并不能证实约拿书中所记的事件。")
para('jonah_nineveh', 'description', 'For centuries, critical scholars', '#0',
     "For a long time critics treated the book of Jonah's description of Nineveh as 'an exceedingly great city, a three days' journey in breadth' (Jonah 3:3) as exaggeration. Excavations at Tell Kuyunjik and Tell Nebi Yunus (near modern Mosul, Iraq), begun by Austen Henry Layard in 1847, show that Nineveh was in fact one of the largest cities of its age. Some interpreters read the 'three days' journey' as including the surrounding Assyrian heartland (Khorsabad, Nimrud and their districts), but the phrase is difficult and is understood in different ways.",
     "很长时间里，批评学者把约拿书对尼尼微“极大的城，有三日的路程”（约拿书3:3）的描述视为夸张。奥斯丁·亨利·莱亚德自1847年起在库云吉克废丘和尼比尤努斯废丘（靠近现代伊拉克摩苏尔）的发掘表明，尼尼微确实是当时最大的城市之一。有些解经者把“三日的路程”理解为包括周围的亚述腹地（霍尔萨巴德、尼姆鲁德及其辖区），但这个短语很难解，学者有不同的理解。")
para('jonah_nineveh', 'description', "The city's inner wall alone", '#1',
     "The city's inner wall encloses about 1,800 acres and runs for nearly 12 km. Layard's discoveries included Sennacherib's 'Palace Without Rival' with its Lachish reliefs, and Hormuzd Rassam's excavations (1853) recovered much of Ashurbanipal's library of some 30,000 cuneiform tablets, the most important literary find of the ancient Near East.",
     "该城的内城墙围出约1,800英亩的面积，周长近12公里。莱亚德的发现包括西拿基立的“无与伦比之宫”及其拉吉浮雕；霍尔穆兹·拉萨姆的发掘（1853年）找回了亚述巴尼拔图书馆约3万块楔形文字泥板中的大部分，这是古代近东最重要的文献发现。")
para('jonah_nineveh', 'description', 'Assyrian records from the reign', '#2',
     "Nineveh fell to the Medes and Babylonians in 612 BCE, as the Babylonian Chronicle records, which fits the prophecies of Nahum and Zephaniah against the city. A few scholars have tried to connect a Nabu-centred religious emphasis under Adad-nirari III (c. 810–783 BCE) with the mission of Jonah, but that is speculative, and the Assyrian records do not mention Jonah or a repentance of Nineveh.",
     "尼尼微于公元前612年陷落于玛代人和巴比伦人之手，巴比伦编年史对此有记载，这与那鸿书和西番雅书对该城的预言相符。少数学者试图把阿达德-尼拉里三世（约公元前810—783年）治下以那布（Nabu）为中心的宗教倾向与约拿的使命联系起来，但那只是推测，亚述记录并没有提到约拿，也没有提到尼尼微的悔改。")
para('jonah_nineveh', 'scripturalCorrelation', "Jonah 3:3 describes Nineveh", '#0',
     "Jonah 3:3 describes Nineveh as 'an exceedingly great city, three days' journey in breadth'. The excavated city was very large for its day, which is consistent with the description, although the exact meaning of the 'three days' journey' is uncertain.",
     "约拿书3:3把尼尼微描述为“极大的城，有三日的路程”。出土的这座城在当时规模很大，与这一描述并不矛盾，但“三日的路程”的确切含义并不确定。")
para('jonah_nineveh', 'scripturalCorrelation', 'The description of Nineveh', '#1',
     "The book describes Nineveh's repentance (Jonah 3:5-9). The Assyrian records contain no trace of such an event, so the account cannot be tested archaeologically. Nineveh's destruction in 612 BCE is well documented and was foretold in Nahum 3:7 and Zephaniah 2:13, but that fits the prophecies against Nineveh rather than the book of Jonah.",
     "书中记载了尼尼微的悔改（约拿书3:5-9）。亚述的记录里没有这类事件的痕迹，所以这段记载无法用考古学来检验。尼尼微于公元前612年被毁有充分的记录，那鸿书3:7和西番雅书2:13也预言了这件事，但这符合的是对尼尼微的预言，而不是约拿书。")


# ---------------------------------------------------------------- unverifiable direct quotations replaced by paraphrase
# Jursa: the entry's "first time an individual mentioned by name in Jeremiah ..." quotation could not be found (NABU 2008/5 note).
sub('nebo_sarsekim_tablet', 'description',
    "Jursa noted: 'If this is indeed the same individual, it would be the first time an individual mentioned by name in Jeremiah has been confirmed by a contemporary Babylonian source.'",
    "Jursa suggested that, if the identification is correct, a Babylonian official named in Jeremiah would here be confirmed by a contemporary Babylonian source.",
    "尤尔萨指出：「如果确实是同一个人，这将是耶利米书中提到的人物首次被当代巴比伦来源所确认。」",
    "尤尔萨（Jursa）认为，如果这一认定成立，耶利米书中点名的一位巴比伦官员就在当时的巴比伦文献中得到了印证。")
# Irenaeus, Against Heresies 5.30.3: the quoted wording was not exact; paraphrase (he says the Apocalypse was seen not long ago,
# towards the end of Domitian's reign).
sub('john_patmos_cave', 'description',
    "states John 'saw the apocalyptic vision… almost in our own time, at the end of Domitian's reign.'",
    "writes that the Apocalypse was seen not long before his own time, towards the end of Domitian's reign.",
    "陈述约翰「几乎在我们自己的时代，在多米田统治末期」见异象。",
    "写道，启示录的异象见于离他自己的时代不远之前，约在多米田统治的末期。")


drop('bronze_serpent_timna', 'description',
     {'zh-Hans': ['3. **帐幕平行**', '4. **铜蛇独特性**', '罗滕伯格（1972年）写道']})

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
        elif k == 'drop':
            for lang, prefixes in c['lang_prefixes'].items():
                langs = [lang] if lang != 'zh-Hans' else ['zh-Hans', 'zh-Hant']
                for lg in langs:
                    val = e[c['field']]
                    cur = val[lg]
                    if isinstance(cur, list):
                        cur = '\n\n'.join(cur)
                    paras = cur.split('\n\n')
                    pf = [hant(x) if lg == 'zh-Hant' else x for x in prefixes]
                    keep = [p for p in paras if not any(p.startswith(x) for x in pf)]
                    if len(keep) != len(paras):
                        val[lg] = '\n\n'.join(keep); changed += 1
        elif k == 'append':
            for lang, new in (('en', c['en']), ('zh-Hans', c['zh']), ('zh-Hant', hant(c['zh']))):
                val = e[c['field']]
                cur = val[lang]
                if isinstance(cur, list):
                    cur = '\n\n'.join(cur)
                paras = cur.split('\n\n')
                n = 30 if lang == 'en' else 14
                if any(p.startswith(new[:n]) for p in paras):
                    if new not in paras and lang != 'zh-Hant':
                        paras = [new if p.startswith(new[:n]) else p for p in paras]
                        val[lang] = '\n\n'.join(paras); changed += 1
                    continue
                paras.append(new)
                val[lang] = '\n\n'.join(paras); changed += 1
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
            for lang, new in (('en', c['en']), ('zh-Hans', c['zh']), ('zh-Hant', hant(c['zh']) if c['zh'] else None)):
                if new is None:
                    continue
                val = e[c['field']]
                cur = val[lang]
                if isinstance(cur, list):
                    cur = '\n\n'.join(cur)
                if k == 'set':
                    if cur != new:
                        val[lang] = new; changed += 1
                else:
                    match = c['match_en'] if lang == 'en' else (c['match_zh'] if lang == 'zh-Hans' else (c['match_zh'] if c['match_zh'].startswith('#') else hant(c['match_zh'])))
                    paras = cur.split('\n\n')
                    # also accept a paragraph that already holds this correction (any zh-Hant conversion)
                    n = 30 if lang == 'en' else 14
                    if match.startswith('#'):  # match by paragraph index
                        i = int(match[1:])
                        if i >= len(paras):
                            raise SystemExit('%s.%s[%s]: no paragraph %d' % (c['id'], c['field'], lang, i))
                        if paras[i] != new:
                            paras[i] = new
                            val[lang] = '\n\n'.join(paras); changed += 1
                        continue
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
