#!/usr/bin/env python3
"""Add NEW entries to assets/bible_evidence.json (圣经证据): finds the original 225 lacked.

2026-10-04 audit, item 「查下是不是有更多要加进来没有到」. Every entry below rests on
sources that were opened during the audit (listed in academicSources and in
bible-evidence-audit/FINDINGS.md). Hand-written: English and 简体. 繁體 is generated with
`opencc -c s2tw` (+ the same repair table as tools/apply_evidence_corrections.py).
Scripture quotations are NOT typed: they are pulled from the app's own editions
(English bsb-yhwh.json, 简体 cuvs-yhwh.json, 繁體 cuvs-yhwh-tr.json of the SAME repo).

Schema differences handled: Words stores timeline / discoveryDate / location as
{en, zh-Hans, zh-Hant}; Sword stores them as plain English strings.
Idempotent: an id that already exists is left alone. Also refreshes _meta.count,
_meta.confidenceCounts and _meta.categories.

Usage:
    tools/add_evidence_entries.py            # dry run
    tools/add_evidence_entries.py --write
"""
import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, 'assets')
TARGET = os.path.join(ASSETS, 'bible_evidence.json')

REPAIRS = [
    ('髮掘', '發掘'), ('被髮', '被發'), ('騷亂髮', '騷亂發'), ('包括髮', '包括發'), ('覆活', '復活'),
    ('幹河谷', '乾河谷'), ('石制', '石製'), ('羊皮捲', '羊皮卷'), ('爐灶', '爐竈'),
    ('馬裡', '馬里'), ('泰勒裡', '泰勒里'), ('瑪裡', '瑪里'), ('胡裡', '胡里'), ('古裡', '古里'),
    ('弗裡', '弗里'), ('努外裡', '努外里'), ('加布裡', '加布里'), ('哈塔裡', '哈塔里'), ('艾茲裡', '艾茲里'),
    ('伊斯坦布林', '伊斯坦布爾'),
]


def hant(text):
    p = subprocess.run(['opencc', '-c', 's2tw'], input=text, capture_output=True, text=True, check=True)
    out = p.stdout.rstrip('\n')
    for a, b in REPAIRS:
        out = out.replace(a, b)
    return out


def load(name):
    d = json.load(open(os.path.join(ASSETS, name), encoding='utf-8'))
    return {r['id']: r['text'] for r in d if r.get('id')}


BSB, CUV, CUVT = load('bsb-yhwh.json'), load('cuvs-yhwh.json'), load('cuvs-yhwh-tr.json')


def passage(table, b, c, v1, v2):
    t = ' '.join(table['%03d%03d%03d' % (b, c, v)] for v in range(v1, v2 + 1))
    t = re.sub(r'<note:[^>]*>', '', t)
    for l, r in (('“', '”'), ('‘', '’')):
        if t.count(l) != t.count(r):
            t = t.replace(l, '').replace(r, '')  # a verse range that opens or closes a quotation mid-way
    return t.replace('“', '"').replace('”', '"').replace('’', "'").replace('‘', "'").strip()


def quote_para(refs, lang):
    """refs: [(book#, chapter, v1, v2, en_label, zh_label)] -> one paragraph of exact quotations."""
    out = []
    for b, c, v1, v2, en_l, zh_l in refs:
        if lang == 'en':
            out.append("%s reads: '%s'" % (en_l, passage(BSB, b, c, v1, v2)))
        else:
            tbl = CUV if lang == 'zh-Hans' else CUVT
            lab = zh_l if lang == 'zh-Hans' else hant(zh_l)
            out.append('%s：「%s」' % (lab, passage(tbl, b, c, v1, v2)))
    return ' '.join(out)


NEW = []


def entry(**kw):
    NEW.append(kw)


# ============================================================================ 1. Cave of Horror scroll, 2021
entry(
    id='cave_of_horror_scroll_2021', category='Manuscripts', icon='📜', confidence='Definitive',
    books=['Zechariah', 'Nahum'], ref='Zechariah 8:16-17',
    timeline=('2nd century CE (Bar Kokhba Revolt, 132–136 CE)', '公元2世纪（巴尔·科赫巴起义，公元132—136年）'),
    discovered=('2021 (announced March 2021)', '2021年（2021年3月公布）'),
    location=("Cave 8 ('Cave of Horror'), Nahal Hever, Judean Desert; studied by the Israel Antiquities Authority",
              '犹大沙漠拿哈勒·希弗（Nahal Hever）的8号洞（“恐怖洞”）；由以色列文物管理局研究'),
    title=("Cave of Horror Scroll Fragments (Greek Minor Prophets, 2021)", '“恐怖洞”经卷残片（希腊文小先知书，2021年）'),
    summary=("In March 2021 the Israel Antiquities Authority announced more than twenty new parchment fragments of a Greek scroll of the Minor Prophets, including parts of Zechariah 8 and Nahum 1, found in the 'Cave of Horror' in Nahal Hever, where they had been hidden during the Bar Kokhba Revolt (132–136 CE).",
             '2021年3月，以色列文物管理局公布了二十多片希腊文小先知书经卷的新羊皮纸残片，包括撒迦利亚书8章和那鸿书1章的部分，出自拿哈勒·希弗的“恐怖洞”，是巴尔·科赫巴起义（公元132—136年）期间藏在那里的。'),
    description=[
        ("In March 2021 the Israel Antiquities Authority (IAA) announced that exploration of caves in the Judean Desert had recovered dozens of new scroll fragments hidden during the Bar Kokhba Revolt (132–136 CE). Among them were more than twenty pieces of parchment from a Greek scroll of the Minor Prophets, including passages from Zechariah 8:16–17 and Nahum 1:5–6.",
         '2021年3月，以色列文物管理局（IAA）宣布，对犹大沙漠洞穴的勘察找到了数十片在巴尔·科赫巴起义（公元132—136年）期间藏起来的新经卷残片。其中有二十多片羊皮纸属于一卷希腊文小先知书，包括撒迦利亚书8:16—17和那鸿书1:5—6的段落。'),
        ("The fragments came from Cave 8 in Nahal Hever, known as the 'Cave of Horror' because of the remains of about forty people found there in the early 1960s, thought to be refugees from the revolt. Yigael Yadin's expedition had already recovered other pieces of the same scroll in 1960–61; those were published by Emanuel Tov in Discoveries in the Judaean Desert VIII (1990).",
         '这些残片出自拿哈勒·希弗的8号洞，因20世纪60年代初在那里发现约四十人的遗骸（据信是起义的难民）而被称为“恐怖洞”。伊加尔·雅丁的考察队1960至1961年已经在这里找到过同一卷的其他碎片，由以马内利·托夫发表于《犹大沙漠发现》第8卷（1990年）。'),
        ("The scroll is a Greek translation of the Minor Prophets that differs from the usual Septuagint text; scholars see it as a revision of the older Greek toward the Hebrew text. The divine name is written in Hebrew letters inside the Greek text. The new fragments are the first scroll fragments recovered by excavation in the Judean Desert in more than sixty years.",
         '这卷经文是小先知书的希腊文译本，与通行的七十士译本不同；学者认为它是把较早的希腊文本向希伯来文本校订的修订本。神的名字在希腊文中用希伯来字母书写。这批新残片是六十多年来在犹大沙漠经发掘取得的第一批经卷残片。'),
        ("The find matters for how the Hebrew prophets were read in Greek in the 2nd century CE and for how the divine name was written in Greek copies. It adds no new book to the Bible, and the fragments contain only a few verses.",
         '这一发现的意义在于了解公元2世纪希伯来先知书如何被译成希腊文阅读，以及神的名字在希腊文抄本中如何书写。它没有给圣经增加任何新书卷，残片所含的经文也只有寥寥几节。'),
    ],
    correlation=(
        [(38, 8, 16, 17, 'Zechariah 8:16-17', '撒迦利亚书8:16-17'), (34, 1, 5, 6, 'Nahum 1:5-6', '那鸿书1:5-6')],
        ("These verses are among the passages preserved on the new fragments. They are known from the Hebrew and Greek tradition, so the discovery is mainly important for the history of the Greek translation of the Minor Prophets and for the transmission of the biblical text in the 2nd century CE.",
         '这些经文是新残片上保存下来的段落。它们在希伯来文和希腊文传统中早已为人所知，因此这一发现的重要性主要在于小先知书希腊文译本的历史，以及公元2世纪圣经文本的传承。')),
    sources=[
        'Tov, Emanuel. The Greek Minor Prophets Scroll from Nahal Hever (8HevXIIgr). Discoveries in the Judaean Desert VIII. Oxford: Clarendon Press, 1990.',
        'Israel Antiquities Authority. Announcement of new Dead Sea Scroll fragments and other finds from the Judean Desert survey, March 2021.',
        'Biblical Archaeology Society. "New Scrolls Hidden During Bar Kokhba Revolt Discovered." https://www.biblicalarchaeology.org/daily/new-scrolls-hidden-during-bar-kokhba-revolt-discovered/',
    ],
)

# ============================================================================ 2. Lysanias inscription (Abila)
entry(
    id='lysanias_inscription_abila', category='Archaeology', icon='🏛️', confidence='Strong',
    books=['Luke'], ref='Luke 3:1',
    timeline=('Reign of Tiberius (14–37 CE), most likely 14–29 CE', '提庇留在位期间（公元14—37年），最可能在公元14—29年'),
    discovered=('Published in the 19th century', '19世纪发表'),
    location=('Abila (modern Suq Wadi Barada), northwest of Damascus, Syria', '亚比拉（今叙利亚大马士革西北的苏格瓦迪巴拉达）'),
    title=('Lysanias Inscription (Abila)', '吕撒聂铭文（亚比拉）'),
    summary=("A Greek inscription from Abila, near Damascus, from the reign of Tiberius names a 'Lysanias the tetrarch' under whom a freedman, Nymphaios, built a road and other works. It supports Luke 3:1, which names a Lysanias as tetrarch of Abilene.",
             '大马士革附近亚比拉的一块提庇留时期希腊文铭文，提到一位“分封王吕撒聂”，他的被释奴尼姆法欧斯修了一条路和其他工程。这支持了路加福音3:1把一位吕撒聂称为亚比利尼分封王的说法。'),
    description=[
        ("Luke 3:1 dates the start of John the Baptist's ministry by naming Tiberius, Pontius Pilate, Herod, Philip and 'Lysanias tetrarch of Abilene'. Josephus knows of an earlier Lysanias, king of Chalcis, put to death by Mark Antony around 34 BCE, and some critics have argued that Luke confused the two.",
         '路加福音3:1用提庇留、本丢·彼拉多、希律、腓力和“亚比利尼分封的王吕撒聂”来标明施洗约翰事工开始的时间。约瑟夫知道有一位更早的吕撒聂，是迦勒基斯的王，约在公元前34年被马可·安东尼处死，有些批评者认为路加把两人弄混了。'),
        ("A Greek inscription from Abila, the chief town of Abilene northwest of Damascus, records a dedication 'for the salvation of the August lords and all their household' by Nymphaios, freedman of Lysanias the tetrarch, who built a road and other works. The 'August lords' are taken to be the Emperor Tiberius and his mother Livia, which dates the text between 14 and 29 CE. It shows that a tetrarch named Lysanias was connected with Abilene in the reign of Tiberius, as Luke says.",
         '亚比拉是亚比利尼的主要城镇，在大马士革西北。那里的一块希腊文铭文记载了一次奉献：“为奥古斯都诸主及其全家的安康”，奉献者是分封王吕撒聂的被释奴尼姆法欧斯，他修了一条路和其他工程。“奥古斯都诸主”被理解为皇帝提庇留和他的母亲利维亚，因此文字的年代在公元14至29年之间。这表明在提庇留时期确有一位名叫吕撒聂的分封王与亚比利尼相连，正如路加所说。'),
        ("Most scholars take the inscription as evidence for a second Lysanias, tetrarch of Abilene, in the time of Tiberius, which answers the charge that Luke confused him with the earlier king. A few dispute that reading and relate the inscription to the older Lysanias's family. The stone was recorded long ago, so the question rests on the published copies and on how the text is interpreted.",
         '多数学者把这块铭文视为提庇留时期另有一位亚比利尼分封王吕撒聂的证据，这回答了路加把他与更早的那位王混为一谈的指责。少数人不同意这样解读，认为铭文与较早那位吕撒聂的家族有关。这块石头早就有人记录，所以这个问题取决于已发表的抄录本以及对文字的解释。'),
    ],
    correlation=(
        [(42, 3, 1, 1, 'Luke 3:1', '路加福音3:1')],
        ("Luke names Lysanias among the rulers around 28–29 CE. The Abila inscription supports the existence of a tetrarch of that name in the reign of Tiberius, which weakens the objection that Luke made a mistake. It is classed as Strong rather than Definitive because the inscription's reading and meaning have been debated.",
         '路加把吕撒聂列在约公元28至29年间的统治者之中。亚比拉铭文支持提庇留时期确有一位同名的分封王，这削弱了“路加弄错了”的反对意见。本条目列为“有力”而非“确证”，是因为铭文的读法和含义仍有讨论。')),
    sources=[
        'Josephus. Antiquities of the Jews 19.275 and 20.138 (Abila of Lysanias); Antiquities 15.92 (Lysanias of Chalcis).',
        'Hoehner, Harold W. Herod Antipas. Cambridge University Press, 1972 (discussion of the Lysanias question).',
        'Wikipedia. "Lysanias." https://en.wikipedia.org/wiki/Lysanias (summary of the Abila inscription and the debate).',
    ],
)

# ============================================================================ 3. Jerusalem Pilgrimage Road
entry(
    id='jerusalem_pilgrimage_road', category='Archaeology', icon='🛣️', confidence='Strong',
    books=['John'], ref='John 9:7',
    timeline=('Early 1st century CE (built about 30 CE or soon after)', '公元1世纪初（约公元30年或稍后修建）'),
    discovered=('Excavated by the Israel Antiquities Authority; dating announced 2019', '由以色列文物管理局发掘；年代于2019年公布'),
    location=('City of David (Silwan), Jerusalem, from the Pool of Siloam toward the Temple Mount', '耶路撒冷大卫城（西罗亚），从西罗亚池通往圣殿山'),
    title=('Jerusalem Pilgrimage Road (Siloam to the Temple Mount)', '耶路撒冷朝圣之路（从西罗亚池到圣殿山）'),
    summary=("A monumental stepped street, more than half a kilometre long and about 8 metres wide, excavated beneath the City of David, led from the Pool of Siloam to the Temple Mount. More than 100 coins sealed under its paving, the latest from about 31 CE, date its construction to the time of Pontius Pilate.",
             '大卫城地下发掘出一条宏伟的台阶街道，长超过半公里，宽约8米，从西罗亚池通往圣殿山。封在铺路石下面的一百多枚钱币，最晚的约为公元31年，把它的修建年代定在本丢·彼拉多时期。'),
    description=[
        ("Archaeologists of the Israel Antiquities Authority, working in tunnels beneath a neighbourhood just south of the Temple Mount, uncovered a monumental stepped street that ran from the Pool of Siloam up toward the Temple Mount. It was more than a third of a mile long, about 26 feet (8 m) wide and paved with around ten thousand tons of limestone slabs.",
         '以色列文物管理局的考古学家在圣殿山南面一处街区下的隧道里工作，发现了一条宏伟的台阶街道，从西罗亚池向上通往圣殿山。它长超过三分之一英里，宽约26英尺（8米），用大约一万吨石灰岩板铺成。'),
        ("More than 100 coins were found beneath the paving stones, the latest dating to about 31 CE. Donald Ariel, the IAA's coin expert, notes that the most common first-century Jerusalem coins were minted after 40 CE and that none lay under the street, so the street was laid before they appeared, in the time of Pontius Pilate, who governed Judea from about 26/27 CE. Joe Uziel and the excavation team reported this in Tel Aviv: Journal of the Institute of Archaeology in 2019.",
         '铺路石下面发现了一百多枚钱币，最晚的约为公元31年。文物管理局的钱币专家唐纳德·阿里尔指出，1世纪耶路撒冷最常见的钱币都是公元40年以后铸造的，而街道下面一枚也没有，所以街道是在这些钱币出现之前、也就是本丢·彼拉多时期铺的，彼拉多约从公元26/27年起任犹太巡抚。约埃·乌齐尔和发掘团队于2019年在《特拉维夫：特拉维夫大学考古学研究所期刊》上报告了这一点。'),
        ("Josephus reports that Pilate used sacred funds to build an aqueduct for Jerusalem (War 2.175–177; Antiquities 18.60–62), and the excavators suggest he may also have paid for or planned this street. Other scholars caution that the coins date the street but do not show who ordered it.",
         '约瑟夫记载，彼拉多动用圣殿的款项为耶路撒冷修了一条水道（《犹太战记》2.175—177；《犹太古史》18.60—62），发掘者认为他也可能为这条街道出资或主持规划。另一些学者提醒说，钱币只能确定街道的年代，不能说明是谁下令修的。'),
        ("The street linked the Pool of Siloam, where Jesus told the blind man to wash (John 9:7), with the Temple Mount, so it is the kind of road that pilgrims of his day will have used. It is classed as Strong because the dating by coins is solid, while the link to Pilate and to particular Gospel events is interpretation.",
         '这条街道把西罗亚池（耶稣叫瞎眼的人去那里洗，约翰福音9:7）与圣殿山连了起来，所以它正是当时的朝圣者会走的那种路。本条目列为“有力”，是因为用钱币断代的依据扎实，而它与彼拉多以及某些福音书事件的联系则属于解释。'),
    ],
    correlation=(
        [(43, 9, 7, 7, 'John 9:7', '约翰福音9:7')],
        ("The Gospels place Jesus in Jerusalem at pilgrim festivals. The Pilgrimage Road shows the kind of monumental infrastructure that served the crowds who went up to the Temple in his time, and it was built in the same decade in which Luke 3:1 places Pontius Pilate as governor of Judea. It does not mention any person from the Gospels.",
         '福音书记载耶稣在朝圣节期到过耶路撒冷。朝圣之路展示了他那个时代为上圣殿的人群而建的宏大基础设施，它修建的年代，正是路加福音3:1所说本丢·彼拉多任犹太巡抚的那十年。它并没有提到福音书中的任何人物。')),
    sources=[
        'National Geographic. "Road built by biblical villain uncovered in Jerusalem." 2019. https://www.nationalgeographic.com/history/2019/10/road-built-biblical-villain-uncovered-jerusalem/',
        'Uziel, Joe, and colleagues of the Israel Antiquities Authority. Report on the Pilgrimage Road excavation, Tel Aviv: Journal of the Institute of Archaeology of Tel Aviv University (2019).',
        'Josephus. Jewish War 2.175–177; Antiquities of the Jews 18.60–62 (Pilate and the aqueduct).',
    ],
)

# ============================================================================ 4. Ark Tablet
entry(
    id='ark_tablet_finkel', category='History', icon='⛵', confidence='Strong',
    books=['Genesis'], ref='Genesis 6:14-16',
    timeline=('Old Babylonian period, about 1850 BCE (Finkel\'s estimate)', '古巴比伦时期，约公元前1850年（芬克尔的估计）'),
    discovered=('Published 2014 (Irving Finkel)', '2014年发表（欧文·芬克尔）'),
    location=('Studied and published by Irving Finkel of the British Museum', '由大英博物馆的欧文·芬克尔研究并发表'),
    title=('The Ark Tablet (Mesopotamian flood story, 2014)', '方舟泥板（美索不达米亚洪水故事，2014年）'),
    summary=("A cuneiform tablet published in 2014 by Irving Finkel of the British Museum gives instructions for building a large round boat of rope and bitumen to survive a flood sent by the gods. It shows how old and widespread Mesopotamian flood stories were, and how the ark could be imagined differently from Genesis.",
             '大英博物馆的欧文·芬克尔于2014年发表了一块楔形文字泥板，里面有为躲避诸神所降洪水而建造一艘用绳索和沥青制成的大型圆形船的指示。它显示了美索不达米亚洪水故事有多古老、流传多广，也显示方舟可以被想象成与创世记不同的样子。'),
    description=[
        ("In 2014 Irving Finkel of the British Museum published a cuneiform tablet from the Old Babylonian period (about 1850 BCE in his estimate) that preserves instructions for building a large boat to survive a flood. The text is a version of the Mesopotamian flood story of the Atrahasis tradition.",
         '2014年，大英博物馆的欧文·芬克尔发表了一块古巴比伦时期（据他估计约公元前1850年）的楔形文字泥板，上面保存着为躲避洪水而建造大船的指示。这篇文字是阿特拉哈西斯传统的美索不达米亚洪水故事的一个版本。'),
        ("Unlike the long rectangular ark of Genesis, the tablet describes a giant circular vessel, a coracle of rope on a wooden frame, waterproofed with two kinds of bitumen. It gives enough measurements for a one-third scale model to be built for a 2014 television documentary.",
         '与创世记中长方形的方舟不同，泥板描述的是一艘巨大的圆形船，用绳索绑在木架上，涂两种沥青防水。它给出了足够的尺寸，使2014年的一部电视纪录片能造出三分之一比例的模型。'),
        ("The tablet is more than a thousand years older than the Gilgamesh flood tablet in the British Museum (7th century BCE). It shows that Mesopotamian flood stories with a divinely warned boat-builder were told long before the Hebrew Bible reached its present form. Finkel argues that Hebrew scholars would have met such texts during the Babylonian exile; whether the biblical account depends on them is a scholarly proposal, and others read the parallels as independent traditions. The tablet is not evidence that the flood described in Genesis happened, but it documents how the story was told in the ancient Near East.",
         '这块泥板比大英博物馆的吉尔伽美什洪水泥板（公元前7世纪）早一千多年。它表明，有神灵警告造船人的美索不达米亚洪水故事，在希伯来圣经成为现在的样子之前很久就在流传。芬克尔认为希伯来学者在巴比伦被掳期间会接触到这类文本；圣经的记载是否依赖它们，只是学界的一种看法，也有人把这些相似之处看作各自独立的传统。这块泥板并不是创世记所述洪水确实发生的证据，但它记录了这个故事在古代近东是怎样讲述的。'),
    ],
    correlation=(
        [(1, 6, 14, 16, 'Genesis 6:14-16', '创世记6:14-16')],
        ("Genesis and the Ark Tablet both record a divine instruction to build a vessel sealed with a waterproofing substance, but the shapes and materials differ: the biblical ark is a large rectangular box of gopher wood coated with pitch, while the Ark Tablet's boat is a round coracle of rope and wood coated with bitumen. The parallel is one of motif, not of identical design.",
         '创世记和方舟泥板都记载了神灵指示建造一只用防水材料封好的船，但形状和材料不同：圣经中的方舟是用歌斐木造的长方形大箱，抹上松香；方舟泥板中的船则是用绳索和木头做成的圆形小艇，涂上沥青。这种相似是母题上的相似，而不是设计相同。')),
    sources=[
        'Finkel, Irving. The Ark Before Noah: Decoding the Story of the Flood. London: Hodder & Stoughton; New York: Nan A. Talese/Doubleday, 2014.',
        'Archaeology magazine. "Cuneiform Tablet Tells Giant Ark Story." 27 January 2014. https://archaeology.org/news/2014/01/27/140127-ark-cuneiform-translation/',
    ],
)

# ============================================================================ 5. Nazareth house (2009)
entry(
    id='nazareth_first_century_house', category='Archaeology', icon='🏠', confidence='Strong',
    books=['Luke'], ref='Luke 2:39',
    timeline=('Early Roman period (1st century CE)', '早罗马时期（公元1世纪）'),
    discovered=('2009 (announced December 2009)', '2009年（2009年12月公布）'),
    location=('Next to the Basilica of the Annunciation, Nazareth, Israel', '以色列拿撒勒，天使报喜教堂旁'),
    title=('First-Century House in Nazareth (2009)', '拿撒勒的1世纪房屋（2009年）'),
    summary=("In December 2009 the Israel Antiquities Authority announced the remains of a modest first-century house at Nazareth: two rooms around a courtyard, with a water system that collected rain from the roof. It is the first dwelling of the Jewish village that can be dated to the time of Jesus.",
             '2009年12月，以色列文物管理局公布了拿撒勒一座朴素的1世纪房屋遗迹：两间房围着一个院子，还有一套收集屋顶雨水的供水设施。它是这个犹太村庄中第一座可以确定属于耶稣时代的住宅。'),
    description=[
        ("The remains were found in a salvage excavation by the Israel Antiquities Authority, directed by Yardenna Alexandre, on the site of a former convent beside the Basilica of the Annunciation, where the International Marian Center of Nazareth was to be built. Workers first noticed signs of the building in the summer of 2009, and by December it was clear that it dated from the time of Jesus.",
         '这些遗迹是以色列文物管理局由亚尔登娜·亚历山大（Yardenna Alexandre）主持的抢救性发掘中发现的，地点在天使报喜教堂旁一座旧修道院的原址，那里将要建国际玛利亚中心。2009年夏天工人先注意到这座建筑的迹象，到12月才清楚它属于耶稣时代。'),
        ("The excavators uncovered the walls of a house of two rooms and a courtyard, a hideout, and a water system that appeared to carry rainwater from the roof to the house. The building is small and modest, and Alexandre described it as typical of the dwellings of the Jewish village of Nazareth at that time.",
         '发掘者揭露出一座有两个房间和一个院子的房屋的墙壁、一个藏身处，以及一套似乎把屋顶雨水引到屋里的供水设施。这座建筑小而朴素，亚历山大把它描述为当时犹太村庄拿撒勒典型的住宅。'),
        ("Nazareth is not named in the Hebrew Bible or in Josephus, and a few writers have argued that it was insignificant or even absent in Jesus' day. The find shows a small Jewish settlement at Nazareth in the Early Roman period, as the Gospels assume. It cannot be linked to Jesus' family, and nothing in it shows who lived there.",
         '拿撒勒在希伯来圣经和约瑟夫的著作中都没有出现，少数作者曾认为它在耶稣时代微不足道，甚至并不存在。这一发现表明早罗马时期拿撒勒确有一个小型犹太聚落，正如福音书所设想的。它不能与耶稣的家庭联系起来，其中也没有任何东西表明谁住在那里。'),
    ],
    correlation=(
        [(42, 2, 39, 39, 'Luke 2:39', '路加福音2:39')],
        ("Luke 2:39 and Matthew 2:23 place Jesus' family in Nazareth. The 2009 excavation supports the existence of a small Jewish village there in the first century, which the Gospels assume. It says nothing about Jesus' own family, so it is evidence for the setting of the Gospel accounts rather than for any event in them.",
         '路加福音2:39和马太福音2:23把耶稣的家安在拿撒勒。2009年的发掘支持了1世纪那里确有一个小型犹太村庄，这正是福音书所设想的背景。它没有说到耶稣自己的家庭，所以它证明的是福音书叙事的背景，而不是其中的任何事件。')),
    sources=[
        'Israel Antiquities Authority. Press release on the first-century dwelling found in Nazareth, 21 December 2009.',
        'NBC News / Associated Press. "First Jesus-era house found in Nazareth." December 2009. https://www.nbcnews.com/id/wbna34511072',
        'Jewish Virtual Library. "Excavation Discovers Remains of Building from Time of Jesus." https://www.jewishvirtuallibrary.org/excavation-discovers-remains-of-building-from-time-of-jesus',
    ],
)

# ============================================================================ 6. Theodotus synagogue inscription
entry(
    id='theodotus_synagogue_inscription', category='Archaeology', icon='🕍', confidence='Definitive',
    books=['Acts'], ref='Acts 6:9',
    timeline=('1st century BCE – 70 CE (before the destruction of Jerusalem)', '公元前1世纪至公元70年（耶路撒冷被毁之前）'),
    discovered=('1913 (Raymond Weill)', '1913年（雷蒙·韦尔）'),
    location=("Found in the City of David, Jerusalem; now in the Israel Museum", '出土于耶路撒冷大卫城；现藏以色列博物馆'),
    title=('Theodotus Synagogue Inscription', '提阿多图会堂铭文'),
    summary=("A Greek inscription found in Jerusalem in 1913 records that Theodotus, son of Vettenus, a priest and synagogue leader, rebuilt a synagogue for the reading of the Law, with a hostel and baths for visitors from abroad. It is direct evidence of a synagogue in Jerusalem before the destruction of 70 CE.",
             '1913年在耶路撒冷发现的一块希腊文铭文记载，祭司兼会堂领袖、维提努斯之子提阿多图重建了一座会堂，用来诵读律法，并设有供外来客人使用的客舍和浴室。这是公元70年毁城之前耶路撒冷有会堂的直接证据。'),
    description=[
        ("The inscription is a limestone slab about 75 × 41 cm, written in Koine Greek. It was found in December 1913 by Raymond Weill during his excavations on the southeastern Ophel hill, the City of David south of the Temple Mount. It was first kept in the Rockefeller Museum and is now exhibited in the Israel Museum.",
         '这块铭文是一块约75×41厘米的石灰岩板，用通用希腊文书写。1913年12月，雷蒙·韦尔在圣殿山以南的大卫城、也就是东南俄斐勒山的发掘中发现了它。它最初存放在洛克菲勒博物馆，现在在以色列博物馆展出。'),
        ("It reads, in translation: Theodotus, son of Vettenus, priest and synagogue leader, son of a synagogue leader, grandson of a synagogue leader, rebuilt this synagogue for the reading of the Law and the teaching of the commandments, and the hostelry, rooms and baths, for the lodging of those who have need from abroad.",
         '译文是：提阿多图，维提努斯之子，祭司兼会堂领袖，会堂领袖之子、会堂领袖之孙，重建了这座会堂，用来诵读律法、教导诫命，并建了客舍、房间和浴室，供来自外地有需要的人住宿。'),
        ("The inscription dates from the 1st century BCE to 70 CE, before the destruction of Jerusalem. The name Vettenus is Roman, which suggests a family of freed slaves or of Roman origin. Acts 6:9 mentions a 'Synagogue of the Freedmen' in Jerusalem, and an identification with Theodotus' synagogue has been suggested, but the inscription does not say so. What it does show is that a priestly family ran a synagogue with lodging for pilgrims in Jerusalem while the Temple still stood.",
         '这块铭文的年代在公元前1世纪到公元70年之间，即耶路撒冷被毁之前。维提努斯（Vettenus）是罗马人的名字，说明这是一个被释奴或罗马出身的家族。使徒行传6:9提到耶路撒冷有一座“利百地拿（被释奴）会堂”，有人提出它就是提阿多图的会堂，但铭文本身并没有这样说。它确切表明的是：圣殿尚存的时候，耶路撒冷有一个祭司家族经营着一座为朝圣者提供住宿的会堂。'),
    ],
    correlation=(
        [(44, 6, 9, 9, 'Acts 6:9', '使徒行传6:9')],
        ("Acts speaks of synagogues in Jerusalem used by Greek-speaking Jews from the diaspora. The Theodotus inscription shows that such a synagogue existed, with a purpose that matches that description: reading the Law, teaching the commandments and lodging visitors from abroad. Whether it is the same as the 'Synagogue of the Freedmen' is an open suggestion.",
         '使徒行传提到耶路撒冷有供讲希腊语的外邦散居犹太人使用的会堂。提阿多图铭文表明确有这样的会堂，其用途也与那种描述相合：诵读律法、教导诫命、接待外地来客。至于它是否就是“利百地拿会堂”，只是一种尚无定论的推测。')),
    sources=[
        'Weill, Raymond. La Cité de David: compte rendu des fouilles exécutées à Jérusalem, 1913–1914. Paris: Geuthner, 1920.',
        'Wikipedia. "Theodotos inscription." https://en.wikipedia.org/wiki/Theodotos_inscription',
        'Jerusalem Perspective. "Sidebar: Synagogue Guest House for First-century Pilgrims." https://www.jerusalemperspective.com/2396/',
    ],
)

# ============================================================================ 7. Mount Ebal lead object (disputed)
entry(
    id='mount_ebal_lead_object', category='Archaeology', icon='⚠️', confidence='Circumstantial',
    books=['Deuteronomy'], ref='Deuteronomy 27:13',
    timeline=('Claimed about 1200 BCE (Late Bronze / Early Iron Age); the date and the reading are disputed', '发掘者主张约公元前1200年（青铜时代晚期/铁器时代早期）；年代和释读都有争议'),
    discovered=('Found December 2019; announced March 2022', '2019年12月发现；2022年3月公布'),
    location=('Mount Ebal, near Nablus, West Bank', '西岸地区纳布卢斯附近的以巴路山（Mount Ebal）'),
    title=('Mount Ebal Lead Object (disputed "curse tablet")', '以巴路山铅片（有争议的“咒诅泥板”）'),
    summary=("A tiny folded lead sheet found in 2019 on Mount Ebal was announced in 2022 as carrying a curse in early Hebrew, which would be the oldest Hebrew writing. Most scholars who have examined the claim reject the reading and say the object bears no writing, so it is not evidence.",
             '2019年在以巴路山发现的一小片折叠的铅片，于2022年被宣布刻有早期希伯来文的咒诅，若属实将是最古老的希伯来文字。大多数检验过这一说法的学者否定这种释读，认为这件东西上根本没有文字，所以它不能算作证据。'),
    description=[
        ("In March 2022 a team led by Scott Stripling (Associates for Biblical Research) announced a small folded lead sheet, about 2 cm × 2 cm, found in December 2019 during wet-sifting of excavation debris from Mount Ebal near Nablus. Using tomographic scans, Pieter van der Veen and Gershon Galil proposed that it carries a curse beginning 'cursed by the god YHW', dated to about 1200 BCE, which would make it the oldest known Hebrew inscription.",
         '2022年3月，由斯科特·斯特里普林（《圣经研究会》）领导的团队宣布发现了一小片折叠的铅片，约2厘米×2厘米，是2019年12月在对纳布卢斯附近以巴路山的发掘土石进行湿筛时找到的。彼得·范德费恩（Pieter van der Veen）和格尔松·加利尔（Gershon Galil）借助断层扫描，提出上面刻有以“被神YHW咒诅”开头的诅咒，年代约为公元前1200年，这将使它成为已知最古老的希伯来文铭文。'),
        ("The claim was publicised before peer review and has been strongly criticised. Three articles in the Israel Exploration Journal in late 2023 argued against it: Christopher Rollston and Aren Maeir found no writing at all, only random bumps and scratches that do not match the published drawings, and Amihai Mazar suggested the object is a fishing net sinker. Commentators have almost all rejected the proposed reading.",
         '这一说法在经同行评审之前就已公开，并受到强烈批评。2023年底，《以色列考古学刊》上有三篇文章反驳：克里斯托弗·罗尔斯顿和阿伦·迈尔认为上面根本没有文字，只有杂乱的凸起和划痕，与已发表的摹绘并不吻合；阿米海·马扎尔则认为这件东西是渔网的坠子。评论者几乎都否定了所提出的释读。'),
        ("Because the proposed reading and date are rejected by most specialists, this entry is included for completeness and classed as Circumstantial. It should not be cited as evidence for the covenant ceremony of Deuteronomy 27 or for early use of the divine name.",
         '由于大多数专家否定了所提出的释读和年代，本条目只是为了完整而收入，并列为“间接”等级。它不应被引用为申命记27章立约仪式的证据，也不应被引用为神的名字很早就被使用的证据。'),
    ],
    correlation=(
        [(5, 27, 13, 13, 'Deuteronomy 27:13', '申命记27:13')],
        ("Deuteronomy 27 places the pronouncing of curses on Mount Ebal, and the proposal that the lead sheet is a curse tablet from the site was meant to connect it with that tradition. Because the reading is rejected by most scholars, the connection is not supported by the object.",
         '申命记27章把宣布咒诅的仪式安排在以巴路山，而“这片铅片是出自该地的咒诅泥板”的提法，本意是要把它与这一传统联系起来。由于大多数学者否定了这种释读，这件东西并不能支持这种联系。')),
    sources=[
        'Wikipedia. "Mount Ebal lead object." https://en.wikipedia.org/wiki/Mount_Ebal_lead_object',
        'Times of Israel. "New academic articles heap fresh doubt on Mount Ebal curse tablet interpretation." https://www.timesofisrael.com/new-academic-articles-heap-fresh-doubt-on-mount-ebal-curse-tablet-interpretation/',
        'Critical responses by Christopher Rollston, Aren Maeir and Amihai Mazar, Israel Exploration Journal (2023).',
    ],
)

# ============================================================================ 8. Samaria ostraca
entry(
    id='samaria_ostraca', category='Archaeology', icon='🏺', confidence='Strong',
    books=['Amos'], ref='Amos 6:4-6',
    timeline=('Second quarter of the 8th century BCE (reign of Jeroboam II)', '公元前8世纪第二个二十五年（耶罗波安二世时期）'),
    discovered=('1910 (George Reisner, Harvard expedition)', '1910年（乔治·赖斯纳，哈佛考察队）'),
    location=('Found at Samaria; now in the Istanbul Archaeology Museums', '出土于撒玛利亚；现藏伊斯坦布尔考古博物馆'),
    title=('Samaria Ostraca', '撒玛利亚陶片文书'),
    summary=("About a hundred inscribed potsherds from the royal acropolis of Samaria, 63 of them legible dockets, record shipments of wine and olive oil to the capital of the northern kingdom in the 8th century BCE. They give a rare look at Israel's administration and its mixture of Yahweh and Baal names.",
             '撒玛利亚王家卫城出土了约一百片刻字陶片，其中63片可读，是公元前8世纪运往北国首都的酒和橄榄油的货单。它们让人难得一见以色列的行政管理，以及人名中耶和华名与巴力名并存的情形。'),
    description=[
        ("The ostraca were found in 1910 by George Reisner's Harvard expedition at Samaria, in a floor level of the royal palace area. They are short dockets written in ink on pottery in Paleo-Hebrew script by professional scribes, in a northern Hebrew dialect. The context and the script date them to the second quarter of the 8th century BCE, in the reign of Jeroboam II (about 786–746 BCE).",
         '这些陶片是1910年由乔治·赖斯纳率领的哈佛考察队在撒玛利亚王宫区的一个地面层中发现的。它们是用墨水写在陶器上的简短货单，由专业书吏用古希伯来字体书写，语言是北方希伯来语方言。出土背景和字体把它们的年代定在公元前8世纪第二个二十五年，即耶罗波安二世（约公元前786—746年）时期。'),
        ("The dockets record deliveries of aged wine and refined olive oil, giving the year of an unnamed king (most often years 9 and 10, generally taken as Jeroboam II), the place or clan it came from, and the person it was for. The places cluster within about 5–12 km of Samaria, in the territory of the clans of Manasseh named in the Bible (Abiezer, Helek, Shemida, Asriel, Hoglah, Noah).",
         '这些货单记录了陈酒和精炼橄榄油的送达，写明某位未具名的王的年份（多为第9年和第10年，一般认为是耶罗波安二世）、来源的地点或宗族，以及收货的人。这些地点集中在撒玛利亚周围约5至12公里的范围内，也就是圣经所记玛拿西各宗族的领地（亚比以谢、希勒、示米大、亚斯列、何拉、挪阿）。'),
        ("Personal names on the ostraca include names built on the divine name Yahweh, spelled with the ending -yw in the north, and names built on Baal. They show that both were in use in 8th-century Israel, which matches the prophets' complaints about Baal worship. The ostraca say nothing about any biblical person.",
         '陶片上的人名既有以神的名字雅伟构成的（在北方拼作词尾 -yw），也有以巴力构成的。这表明公元前8世纪的以色列两者并用，与先知对敬拜巴力的责备相合。陶片没有提到任何圣经人物。'),
    ],
    correlation=(
        [(30, 6, 4, 6, 'Amos 6:4-6', '阿摩司书6:4-6')],
        ("Amos, who prophesied in the reign of Jeroboam II, condemns the leaders of Samaria for their luxury, including drinking wine by the bowlful and anointing themselves with the finest oils. The Samaria ostraca show wine and refined oil being delivered to the capital in that very period, so they document the economy that Amos describes, although they do not mention Amos or his words.",
         '阿摩司在耶罗波安二世时期作先知，他谴责撒玛利亚的领袖奢侈无度，包括用大碗喝酒、用上等的油抹身。撒玛利亚陶片显示正是在那个时期有酒和精炼的油被送往首都，所以它们记录了阿摩司所描述的那种经济状况，尽管它们并没有提到阿摩司或他的话。')),
    sources=[
        'Reisner, George A., Clarence S. Fisher and David G. Lyon. Harvard Excavations at Samaria 1908–1910. Harvard University Press, 1924.',
        'Wikipedia. "Samaria Ostraca." https://en.wikipedia.org/wiki/Samaria_Ostraca',
        'Biblical Archaeology Society / Bible Odyssey. "The Samaria Ostraca." https://www.bibleodyssey.org/places/related-articles/the-samaria-ostraca/',
    ],
)

# ============================================================================ 9. Egyptian execration texts naming Jerusalem
entry(
    id='execration_texts_jerusalem', category='History', icon='🏺', confidence='Strong',
    books=['Genesis'], ref='Genesis 14:18',
    timeline=('About 1850–1800 BCE (Egyptian Middle Kingdom)', '约公元前1850—1800年（埃及中王国时期）'),
    discovered=('Berlin bowls published 1926 (Kurt Sethe); Brussels figurines 1940 (Georges Posener)', '柏林陶碗1926年发表（库尔特·塞特）；布鲁塞尔小像1940年发表（乔治·波塞内）'),
    location=('Egyptian Museum, Berlin; Royal Museums of Art and History, Brussels', '柏林埃及博物馆；布鲁塞尔皇家艺术与历史博物馆'),
    title=('Egyptian Execration Texts (earliest mention of Jerusalem)', '埃及咒诅文本（耶路撒冷的最早记载）'),
    summary=("Egyptian curse texts written on bowls and figurines around 1850–1800 BCE list Canaanite cities and rulers, among them 'Rushalimum', which is Jerusalem. They are the earliest known mention of the city and show it was already a city-state with its own rulers long before David.",
             '公元前1850至1800年前后写在陶碗和小像上的埃及咒诅文本，列出了迦南的城市及其统治者，其中有“鲁沙利穆”（Rushalimum），就是耶路撒冷。这是已知对这座城市的最早记载，表明早在大卫之前很久，它就已经是有自己统治者的城邦。'),
    description=[
        ("Egyptian priests wrote the names of cities, rulers and peoples that might rebel against Egypt on pottery bowls and clay figurines, then smashed them in a magical ritual meant to curse the named enemies; hence the name 'execration texts'. Three series survive from the Middle Kingdom: bowls from the fortress of Mirgissa in Nubia (about 1870 BCE), bowls now in Berlin (about 1850 BCE) and figurines from Saqqara (about 1800 BCE), with another set of figurines in Brussels.",
         '埃及祭司把可能反叛埃及的城市、统治者和民族的名字写在陶碗和泥塑小像上，然后在一场咒术仪式中把它们打碎，以咒诅被点名的敌人，因此称为“咒诅文本”。中王国时期留下三组：努比亚米尔吉萨要塞的陶碗（约公元前1870年）、现藏柏林的陶碗（约公元前1850年）和萨卡拉的小像（约公元前1800年），布鲁塞尔还有另一批小像。'),
        ("In these texts Jerusalem appears as Rushalimum, with the names of its rulers (read as Shas'an and Y'qar'am). This is the earliest known mention of Jerusalem, about eight hundred years before David captured the city. It shows that Jerusalem was already a place of political importance, and that its name is very old.",
         '在这些文本中，耶路撒冷写作鲁沙利穆（Rushalimum），并写有其统治者的名字（读作 Shas\'an 和 Y\'qar\'am）。这是已知对耶路撒冷的最早记载，比大卫攻取该城早大约八百年。它表明耶路撒冷当时已是有政治分量的地方，而且它的名字非常古老。'),
        ("The texts do not mention the Bible, Melchizedek or any biblical person. Genesis 14:18 speaks of Melchizedek, king of Salem, and Psalm 76:2 uses Salem as another name for Jerusalem, so the execration texts show that a city of this name and a line of local kings existed in the right region and period. The identification of Salem with Jerusalem rests on the Psalm, not on the texts.",
         '这些文本没有提到圣经、麦基洗德或任何圣经人物。创世记14:18提到撒冷王麦基洗德，诗篇76:2又把撒冷用作耶路撒冷的别名，所以咒诅文本表明，在相应的地区和时代确有这个名字的城市和一系列本地王。把撒冷认定为耶路撒冷，依据的是诗篇，而不是这些文本。'),
    ],
    correlation=(
        [(1, 14, 18, 18, 'Genesis 14:18', '创世记14:18'), (19, 76, 2, 2, 'Psalm 76:2', '诗篇76:2')],
        ("Genesis 14 describes Salem as a city with its own king in Abraham's time. The execration texts show that Jerusalem was a city-state with rulers around 1850–1800 BCE, which is the general period in which Abraham is usually placed. They are not proof of the Genesis story, but they show that the setting it describes was historically possible.",
         '创世记14章描述亚伯拉罕的时代有一座有自己王的撒冷城。咒诅文本表明，约公元前1850至1800年，也就是通常安放亚伯拉罕的大致时期，耶路撒冷是一个有统治者的城邦。它们不是创世记故事的证明，但表明这个故事所描述的背景在历史上是可能的。')),
    sources=[
        'Sethe, Kurt. Die Ächtung feindlicher Fürsten, Völker und Dinge auf altägyptischen Tongefäßscherben des Mittleren Reiches. Berlin, 1926.',
        'Posener, Georges. Princes et pays d\'Asie et de Nubie: Textes hiératiques sur des figurines d\'envoûtement du Moyen Empire. Brussels, 1940.',
        'Encyclopaedia Judaica, "Jerusalem: Early History / Execration Texts." https://www.jewishvirtuallibrary.org/jsource/judaica/ejud_0002_0011_0_10087.html',
    ],
)

# ============================================================================ 10. Sergius Paulus inscriptions
entry(
    id='sergius_paulus_inscriptions', category='Archaeology', icon='🪧', confidence='Circumstantial',
    books=['Acts'], ref='Acts 13:7',
    timeline=('1st century CE (about 46–47 CE)', '公元1世纪（约公元46—47年）'),
    discovered=('19th century (Soloi inscription, Cyprus; Tiber boundary stone, Rome, 1887)', '19世纪（塞浦路斯索罗伊铭文；1887年罗马台伯河界石）'),
    location=('Soloi, Cyprus (inscription); Rome (boundary stone)', '塞浦路斯索罗伊（铭文）；罗马（界石）'),
    title=('Sergius Paulus Inscriptions (Cyprus and Rome)', '士求·保罗铭文（塞浦路斯与罗马）'),
    summary=("An inscription from Soloi in Cyprus mentions a proconsul Paulus, and a boundary stone at Rome records a Sergius Paulus among the curators of the Tiber in 47 CE. Acts 13:7 names Sergius Paulus as proconsul of Cyprus. The link is plausible but uncertain.",
             '塞浦路斯索罗伊的一块铭文提到一位方伯保罗，罗马的一块界石则记载公元47年台伯河管理官中有一位士求·保罗。使徒行传13:7称士求·保罗是塞浦路斯的方伯。这种联系是可能的，但并不确定。'),
    description=[
        ("Acts 13:7 says that on Cyprus Paul and Barnabas met the proconsul Sergius Paulus, a man of intelligence who wanted to hear the word of God. Luke's title 'proconsul' fits Cyprus, which had been a senatorial province governed by proconsuls since 22 BCE.",
         '使徒行传13:7记载，保罗和巴拿巴在塞浦路斯遇见方伯士求·保罗，他是个通达人，想要听神的道。路加用“方伯（总督）”这个称号是恰当的，因为塞浦路斯自公元前22年起是由方伯治理的元老院行省。'),
        ("A Greek inscription found in the 19th century at Soloi on the north coast of Cyprus (by Luigi Palma di Cesnola) mentions a proconsul Paulus. It was first dated to the middle of the 1st century CE, but the epigrapher Terence Mitford thought it could be considerably later. A boundary stone of the emperor Claudius found at Rome in 1887 records the appointment of curators of the banks of the Tiber in 47 CE, and a Sergius Paulus is among them, which would fit a man who served on Cyprus and then returned to Rome.",
         '19世纪（由路易吉·帕尔马·迪·切斯诺拉发现）在塞浦路斯北岸的索罗伊出土了一块希腊文铭文，提到一位方伯保罗。它最初被定在公元1世纪中叶，但铭文学家特伦斯·米特福德认为它可能晚得多。1887年在罗马发现的一块克劳狄皇帝时期的界石，记载了公元47年任命台伯河两岸管理官的事，其中有一位士求·保罗，这与一个先在塞浦路斯任职、后来回到罗马的人相符。'),
        ("The identification with the Sergius Paulus of Acts is uncertain. The name Paulus was common, the Soloi inscription gives only 'Paulus', and one scholar calls the identification at best a conjecture. The evidence therefore shows that a Roman senator of this name was active at the right time, and that Luke used the right title, but it does not prove that he is the man in Acts.",
         '把他与使徒行传中的士求·保罗等同起来并不确定。保罗（Paulus）是常见的名字，索罗伊铭文只写了“保罗”，有学者称这种认定至多只是推测。因此这些证据只表明，在相应的时间确有一位同名的罗马元老活跃着，路加用的称号也是对的，但并不能证明他就是使徒行传中的那个人。'),
    ],
    correlation=(
        [(44, 13, 7, 7, 'Acts 13:7', '使徒行传13:7')],
        ("Acts presents Sergius Paulus as a historical Roman official on Cyprus in the mid-40s CE. The inscriptions show a Paulus as proconsul of Cyprus and a Sergius Paulus holding office at Rome in 47 CE, which is consistent with Luke's account. It is classed as Circumstantial because the identification of the man in the inscriptions with the man in Acts is not secure.",
         '使徒行传把士求·保罗描述为公元40年代中期塞浦路斯的一位罗马官员。铭文显示有一位保罗曾任塞浦路斯方伯，一位士求·保罗在公元47年于罗马任职，这与路加的记载相符。本条目列为“间接”等级，是因为铭文中的那个人与使徒行传中的那个人是否等同，尚无把握。')),
    sources=[
        'Wikipedia. "Sergius Paulus." https://en.wikipedia.org/wiki/Sergius_Paulus (summary of the Soloi and Tiber inscriptions and the debate).',
        'Biblical Archaeology Report. "Sergius Paulus: An Archaeological Biography." 15 November 2019. https://biblearchaeologyreport.com/2019/11/15/sergius-paulus-an-archaeological-biography/',
        'Mitford, Terence B. "Roman Cyprus." In Aufstieg und Niedergang der römischen Welt II.7.2 (1980) (on the Soloi inscription).',
    ],
)



def build(e, words_schema):
    def tri(en, zh):
        return {'en': en, 'zh-Hans': zh, 'zh-Hant': hant(zh)}

    refs, extra = e['correlation']
    corr = {
        'en': quote_para(refs, 'en') + '\n\n' + extra[0],
        'zh-Hans': quote_para(refs, 'zh-Hans') + '\n\n' + extra[1],
        'zh-Hant': quote_para(refs, 'zh-Hant') + '\n\n' + hant(extra[1]),
    }
    desc = {
        'en': '\n\n'.join(p[0] for p in e['description']),
        'zh-Hans': '\n\n'.join(p[1] for p in e['description']),
        'zh-Hant': '\n\n'.join(hant(p[1]) for p in e['description']),
    }
    meta = lambda pair: tri(*pair) if words_schema else pair[0]  # noqa: E731
    return {
        'id': e['id'], 'category': e['category'], 'bibleBooks': e['books'],
        'timeline': meta(e['timeline']), 'discoveryDate': meta(e['discovered']), 'location': meta(e['location']),
        'scriptureReference': e['ref'], 'images': [], 'academicSources': e['sources'],
        'confidenceLevel': e['confidence'], 'icon': e['icon'],
        'title': tri(*e['title']), 'summary': tri(*e['summary']), 'description': desc,
        'scripturalCorrelation': corr,
    }


def main():
    data = json.load(open(TARGET, encoding='utf-8'))
    items = data['evidences']
    ids = {x['id'] for x in items}
    words_schema = isinstance(items[0]['timeline'], dict)
    added = 0
    for e in NEW:
        if e['id'] in ids:
            continue
        items.append(build(e, words_schema))
        added += 1
    counts = {}
    for x in items:
        counts[x['confidenceLevel']] = counts.get(x['confidenceLevel'], 0) + 1
    meta = data.get('_meta', {})
    meta['count'] = len(items)
    if 'confidenceCounts' in meta:
        meta['confidenceCounts'] = counts
    cats = []
    for x in items:
        if x['category'] not in cats:
            cats.append(x['category'])
    if 'categories' in meta:
        meta['categories'] = cats
    print('entries added: %d (total %d)' % (added, len(items)))
    if '--write' not in sys.argv:
        print('(dry run; pass --write)')
        return
    with open(TARGET, 'w', encoding='utf-8') as f:
        f.write(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
    print('WROTE', TARGET)


if __name__ == '__main__':
    main()
