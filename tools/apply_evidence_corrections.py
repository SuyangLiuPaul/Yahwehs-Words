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
