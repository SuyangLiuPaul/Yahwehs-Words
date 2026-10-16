#!/usr/bin/env python3
"""Generate the synthetic add-on test fixtures (and their expected rows).

Why synthetic, and why this file exists
---------------------------------------
The add-on importer reads files that other people made: MyBible.zone and
MySword SQLite modules, theWord text modules, Zefania XML, our own JSON/CSV.
Nothing in this repo may depend on a downloaded third-party module, so every
fixture is BUILT HERE, to the published layout, from nothing:

  * the MyBible.zone layout is the one in its public specification
    (https://mybible.zone/?p=1626 -> "MyBible modules format");
  * the MySword layout (`Details`, `Bible(Book,Chapter,Verse,Scripture)`) is
    the one `tools/import_yahweh_modules.py` reads from the publisher's real
    module;
  * the theWord layout (31102 lines, KJV versification, metadata after) is
    the one `tools/import_yahweh_ont.py` reads from a real .ont.

What synthetic fixtures CAN prove: that our reader decodes SQLite's own file
format correctly (the expected rows come from Python's `sqlite3`, an
independent implementation), including the cases that go wrong silently —
multi-level b-trees and overflow chains — and that every parser maps the
documented columns/tags the way we say it does.

What they CANNOT prove: that a real module matches the layout described
above. That gap is closed only by importing a real file. See
docs/addon-modules.md.

Run:
    python3 tools/make_addon_fixtures.py            # (re)write the fixtures
    python3 tools/make_addon_fixtures.py --check    # fail if they drifted

The output is deterministic (fixed seed, no clocks), so --check is exact.
"""
import hashlib
import json
import os
import random
import sqlite3
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "test", "fixtures", "addons")

# MyBible.zone book numbers for the 66 canonical books, in canon order.
# Taken from the "Books reference" table of the published specification.
MYBIBLE_NUMBERS = [
    10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 120, 130, 140, 150, 160,
    190, 220, 230, 240, 250, 260, 290, 300, 310, 330, 340, 350, 360, 370,
    380, 390, 400, 410, 420, 430, 440, 450, 460, 470, 480, 490, 500, 510,
    520, 530, 540, 550, 560, 570, 580, 590, 600, 610, 620, 630, 640, 650,
    660, 670, 680, 690, 700, 710, 720, 730,
]

def _canon():
    """Verses per chapter per book. Words ships assets/chapter_verses.json;
    Sword derives the identical table from its bundled KJV."""
    path = os.path.join(ROOT, "assets", "chapter_verses.json")
    if os.path.exists(path):
        return json.load(open(path))
    seen = {}
    for r in json.load(open(os.path.join(ROOT, "assets", "kjv.json"))):
        ch = seen.setdefault(r["book"], {})
        c, v = int(r["chapter"]), int(r["verse"])
        ch[c] = max(ch.get(c, 0), v)
    return {b: [ch[c] for c in range(1, max(ch) + 1)] for b, ch in seen.items()}


CANON = _canon()
BOOKS = list(CANON.keys())  # canon order, English names
assert len(BOOKS) == 66 and len(MYBIBLE_NUMBERS) == 66


def sha(b):
    return hashlib.sha256(b).hexdigest()


class Writer:
    """Collects files; either writes them or compares with what is on disk."""

    def __init__(self, check):
        self.check = check
        self.drift = []
        self.names = []

    def put(self, name, data):
        if isinstance(data, str):
            data = data.encode("utf-8")
        path = os.path.join(OUT, name)
        self.names.append(name)
        if self.check:
            if not os.path.exists(path) or open(path, "rb").read() != data:
                self.drift.append(name)
        else:
            os.makedirs(OUT, exist_ok=True)
            with open(path, "wb") as f:
                f.write(data)


def build_sqlite(path_in_memory_name, ddl, rows_by_table, page_size=4096):
    """Build a SQLite file in a temp path; return (bytes, expected dict)."""
    import tempfile

    fd, tmp = tempfile.mkstemp(suffix=".sqlite3")
    os.close(fd)
    os.remove(tmp)
    con = sqlite3.connect(tmp)
    con.execute(f"PRAGMA page_size={page_size}")
    con.execute("PRAGMA journal_mode=DELETE")
    for stmt in ddl:
        con.execute(stmt)
    for table, rows in rows_by_table.items():
        if not rows:
            continue
        marks = ",".join("?" * len(rows[0]))
        con.executemany(f"INSERT INTO {table} VALUES ({marks})", rows)
    con.commit()
    con.execute("VACUUM")  # canonical, compact, no free pages
    con.commit()
    expected = {}
    for (name,) in con.execute(
        "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name"
    ).fetchall():
        expected[name] = [
            list(r) for r in con.execute(f'SELECT * FROM "{name}" ORDER BY rowid')
        ]
    con.close()
    data = open(tmp, "rb").read()
    os.remove(tmp)
    return data, expected


def verse_text(rng, book, c, v, n_words=8):
    words = ["light", "God", "said", "earth", "waters", "heaven", "day",
             "evening", "morning", "spirit", "face", "deep", "good", "word"]
    return f"{book} {c}:{v} " + " ".join(rng.choice(words) for _ in range(n_words))


MYBIBLE_DDL = [
    "CREATE TABLE info (name TEXT, value TEXT)",
    "CREATE TABLE books (book_number NUMERIC, book_color TEXT, short_name TEXT,"
    " long_name TEXT, sorting_order NUMERIC)",
    "CREATE TABLE verses (book_number NUMERIC, chapter NUMERIC, verse NUMERIC,"
    " text TEXT)",
    "CREATE UNIQUE INDEX verses_index ON verses (book_number, chapter, verse)",
]


def mybible_files(w):
    rng = random.Random(20261017)

    # --- minimal: three books, tags exercised ---------------------------
    gen = [
        (10, 1, 1, "In the beginning God created the heaven and the earth."),
        (10, 1, 2, "And the earth was <i>without form</i>, and void;<pb/>and darkness was upon the face of the deep."),
        (10, 1, 3, "And God said, Let there be light: and there was light."),
        (10, 1, 4, "And God saw the light<S>216</S>, that <J>it was good</J><n>note one</n>."),
        (10, 2, 1, "Thus the heavens and the earth were finished<br/>and all the host of them."),
    ]
    john = [(500, 3, 16, "For God so loved the world<f>1</f>, that he gave his only begotten Son."),
            (500, 3, 17, "For God sent not his Son<m>V-AAI-3S</m> into the world to condemn the world.")]
    rev = [(730, 22, 21, "The grace of our Lord Jesus Christ be with you all. Amen.")]
    verses = gen + john + rev
    books = [
        (10, "#ccccff", "Gen", "Genesis", 10),
        (500, "#ffff99", "Jhn", "John", 500),
        (730, "#ff6600", "Rev", "Revelation", 730),
    ]
    info = [
        ("description", "Synthetic Test Bible"),
        ("language", "en"),
        ("strong_numbers", "true"),
        ("detailed_info", "<p>Made by tools/make_addon_fixtures.py</p>"),
    ]
    data, exp = build_sqlite("mybible_min", MYBIBLE_DDL,
                             {"info": info, "books": books, "verses": verses})
    w.put("mybible_min.SQLite3", data)
    w.put("mybible_min.expected.json", json.dumps(exp, ensure_ascii=False, indent=1))

    # --- books_all with is_present and a superscription (verse 0) -------
    ddl = [
        MYBIBLE_DDL[0],
        "CREATE TABLE books_all (book_number NUMERIC, book_color TEXT,"
        " short_name TEXT, title TEXT, long_name TEXT, is_present BOOLEAN,"
        " sorting_order NUMERIC)",
        MYBIBLE_DDL[2],
        MYBIBLE_DDL[3],
        "CREATE TABLE stories (book_number NUMERIC, chapter NUMERIC, verse NUMERIC,"
        " order_if_several NUMERIC, title TEXT)",
        "CREATE TABLE introductions (book_number NUMERIC, introduction TEXT,"
        " PRIMARY KEY (book_number))",
    ]
    books_all = [
        (230, "#ccccff", "Ps", "Psalms", "Book of Psalms", 1, 230),
        (470, "#ffff99", "Mt", "Matthew", "Gospel of Matthew", 1, 470),
        (730, "#ff6600", "Rev", "Revelation", "Revelation", 0, 730),
    ]
    verses = [
        (230, 23, 0, "A Psalm of David."),
        (230, 23, 1, "The LORD is my shepherd; I shall not want."),
        (230, 23, 2, "He maketh me to lie down in green pastures."),
        (470, 1, 1, "The book of the generation of Jesus Christ."),
    ]
    stories = [(230, 23, 1, 0, "The Shepherd Psalm")]
    intros = [(0, "<p>module intro</p>"), (230, "<p>About Psalms</p>")]
    data, exp = build_sqlite("mybible_books_all", ddl, {
        "info": [("language", "en"), ("description", "Books-all Test")],
        "books_all": books_all, "verses": verses, "stories": stories,
        "introductions": intros})
    w.put("mybible_books_all.SQLite3", data)
    w.put("mybible_books_all.expected.json", json.dumps(exp, ensure_ascii=False, indent=1))

    # --- deep b-tree: page_size 512, thousands of rows -------------------
    rows = []
    n = 0
    for bi in range(0, 3):
        book = BOOKS[bi]
        for ci, vc in enumerate(CANON[book], start=1):
            for v in range(1, vc + 1):
                rows.append((MYBIBLE_NUMBERS[bi], ci, v, verse_text(rng, book, ci, v, 6)))
                n += 1
        if n > 2600:
            break
    data, exp = build_sqlite("mybible_deep_tree", MYBIBLE_DDL, {
        "info": [("language", "en")],
        "books": [(MYBIBLE_NUMBERS[i], "#fff", BOOKS[i][:3], BOOKS[i], MYBIBLE_NUMBERS[i]) for i in range(3)],
        "verses": rows}, page_size=512)
    w.put("mybible_deep_tree.SQLite3", data)
    w.put("mybible_deep_tree.expected.json", json.dumps(exp, ensure_ascii=False, indent=1))

    # --- overflow: texts straddling the local-payload thresholds ---------
    # page_size 512 -> usable U = 512, X = U-35 = 477, M = 39.
    rows = []
    v = 0
    # lengths chosen around X (payload also holds a 6-9 byte header + 3 ints)
    for ln in list(range(440, 500, 3)) + [1000, 2000, 5000, 11000]:
        v += 1
        rows.append((10, 1, v, ("x" * (ln - 12)) + f"#{ln}"))
    # multi-byte text so byte length != char length
    for ln in (150, 300, 700):
        v += 1
        rows.append((10, 2, v, "创世记" * ln))
    data, exp = build_sqlite("mybible_overflow", MYBIBLE_DDL, {
        "info": [("language", "zh")], "books": [(10, "#fff", "Gen", "Genesis", 10)],
        "verses": rows}, page_size=512)
    w.put("mybible_overflow.SQLite3", data)
    w.put("mybible_overflow.expected.json", json.dumps(exp, ensure_ascii=False, indent=1))

    # --- page_size 65536 (stored in the header as 1) ---------------------
    data, exp = build_sqlite("mybible_bigpage", MYBIBLE_DDL, {
        "info": [("language", "en")],
        "books": [(10, "#fff", "Gen", "Genesis", 10)],
        "verses": [(10, 1, 1, "A"), (10, 1, 2, "B" * 70000)]}, page_size=65536)
    w.put("mybible_bigpage.SQLite3", data)
    w.put("mybible_bigpage.expected.json", json.dumps(exp, ensure_ascii=False, indent=1))

    # --- Russian numbering + deuterocanon + an unknown book number -------
    verses = [
        (230, 22, 1, "Psalm 22 in Russian numbering is 21 in the Hebrew."),
        (145, 1, 1, "O Lord Almighty, God of our fathers."),
        (192, 1, 1, "Additions to Esther."),
        (780, 1, 1, "Paul to the Laodiceans."),
        (999, 1, 1, "A number the specification does not know."),
        (10, 1, 1, "In the beginning."),
    ]
    data, exp = build_sqlite("mybible_russian", MYBIBLE_DDL, {
        "info": [("language", "ru"), ("russian_numbering", "true"),
                 ("right_to_left", "false")],
        "verses": verses})
    w.put("mybible_russian.SQLite3", data)
    w.put("mybible_russian.expected.json", json.dumps(exp, ensure_ascii=False, indent=1))

    # --- commentary + dictionary (Phase 2 reads these; Phase 1 must
    #     recognise and politely decline them) ----------------------------
    data, exp = build_sqlite("mybible_commentary", [
        "CREATE TABLE info (name TEXT, value TEXT)",
        "CREATE TABLE commentaries (book_number NUMERIC, chapter_number_from NUMERIC,"
        " verse_number_from NUMERIC, chapter_number_to NUMERIC, verse_number_to NUMERIC,"
        " is_preceding NUMERIC, marker TEXT, text TEXT)",
    ], {"info": [("description", "Commentary Test")],
        "commentaries": [(10, 1, 1, None, None, 0, None, "<p>In the beginning...</p>")]})
    w.put("mybible_commentary.SQLite3", data)
    data, exp = build_sqlite("mybible_dictionary", [
        "CREATE TABLE info (name TEXT, value TEXT)",
        "CREATE TABLE dictionary (topic TEXT, definition TEXT NOT NULL,"
        " short_definition TEXT, lexeme TEXT, transliteration TEXT, pronunciation TEXT)",
    ], {"info": [("description", "Dictionary Test")],
        "dictionary": [("G26", "<p>love</p>", "love", "ἀγάπη", "agape", "")]})
    w.put("mybible_dictionary.SQLite3", data)


def mysword_files(w):
    ddl = [
        "CREATE TABLE Details (Title NVARCHAR(100), Description TEXT,"
        " Abbreviation NVARCHAR(50), Comments TEXT, Version TEXT,"
        " VersionDate DATETIME, PublishDate DATETIME, RightToLeft BOOL,"
        " OT BOOL, NT BOOL, Strong BOOL, Language TEXT, Encryption TEXT)",
        "CREATE TABLE Bible (Book INT, Chapter INT, Verse INT, Scripture TEXT)",
        "CREATE UNIQUE INDEX bible_key ON Bible (Book ASC, Chapter ASC, Verse ASC)",
    ]
    verses = [
        (1, 1, 1, "In the beginning God created the heaven and the earth."),
        (1, 1, 2, "And the earth was <FI>without form<Fi>, and void;<CM>and darkness <WH2822> was upon the face of the deep."),
        (1, 1, 3, "<TS>The First Day<Ts>And God said<WH559>, Let there be light<RF>a footnote<Rf>."),
        (43, 3, 16, "For God so loved the world, <FR>that he gave his only begotten Son<Fr><RX43.3.17>."),
        (66, 22, 21, "The grace of our Lord Jesus Christ be with you all. Amen."),
        (67, 1, 1, "A book number outside 1-66."),
    ]
    details = [("MySword Test Bible", "A synthetic test", "MST", "", "1.0",
                "2026-10-17", "2026-10-17", 0, 1, 1, 1, "eng", "0")]
    data, exp = build_sqlite("mysword", ddl, {"Details": details, "Bible": verses})
    w.put("mysword_bible.bbl.mybible", data)
    w.put("mysword_bible.expected.json", json.dumps(exp, ensure_ascii=False, indent=1))

    details = [("Locked Bible", "encrypted", "LCK", "", "1.0", "2026-10-17",
                "2026-10-17", 0, 1, 1, 0, "eng", "1")]
    data, exp = build_sqlite("mysword_enc", ddl, {"Details": details, "Bible": verses[:2]})
    w.put("mysword_encrypted.bbl.mybible", data)

    # A MySword module with a Chinese Details language, to pick the script.
    details = [("中文测试", "", "ZHT", "", "1", "2026-10-17", "2026-10-17", 0, 1, 1, 0, "zho", "0")]
    data, exp = build_sqlite("mysword_zh", ddl, {"Details": details, "Bible": [
        (1, 1, 1, "起初神创造天地。"), (43, 3, 16, "神爱世人，甚至将他的独生子赐给他们。")]})
    w.put("mysword_zh.bbl.mybible", data)


def theword_files(w):
    # A full .nt (7957 lines) is small enough to commit; the full .ont is
    # built in the test from assets/chapter_verses.json instead.
    nt_books = BOOKS[39:]
    lines = []
    for b in nt_books:
        for ci, vc in enumerate(CANON[b], start=1):
            for v in range(1, vc + 1):
                lines.append(f"{b[:3]} {ci}:{v}")
    assert len(lines) == 7957
    special = {
        ("Matthew", 1, 1): "The book of the generation of <FI>Jesus<Fi> Christ<WG5547>, the son of David<WG1138>.",
        ("Matthew", 1, 2): "- - -",
        ("John", 3, 16): "For God so loved the world<WG2889>, that he gave <FR>his only begotten Son<Fr><RF>some witnesses omit this<Rf>.",
        ("Revelation", 22, 21): "The grace of our Lord Jesus Christ be with you all. Amen.<CM>",
        ("Mark", 1, 1): "<TS>The Beginning<Ts>The beginning of the gospel<WG<WG746> of Jesus Christ.",
    }
    i = 0
    out = []
    for b in nt_books:
        for ci, vc in enumerate(CANON[b], start=1):
            for v in range(1, vc + 1):
                out.append(special.get((b, ci, v), lines[i]))
                i += 1
    meta = ["short.title = SYN", "title = Synthetic theWord NT",
            "description = made by make_addon_fixtures.py", "version.major = 1",
            "version.minor = 0", "version.date = 2026-10-17"]
    w.put("theword_nt.nt", "﻿" + "\r\n".join(out + meta) + "\r\n")
    # The same file with the verse count wrong (one line short).
    w.put("theword_nt_short.nt", "\r\n".join(out[:-1]) + "\r\n")


ZEFANIA = """<?xml version="1.0" encoding="utf-8"?>
<XMLBIBLE xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="zef2005.xsd" version="2.0.1.18" status="v" biblename="Sloppy Test" type="x-bible" revision="1">
 <INFORMATION><title>Sloppy Test Bible</title><language>ENG</language></INFORMATION>
 <BIBLEBOOK bnumber="1" bname="Genesis" bsname="Gen">
  <CHAPTER cnumber="1">
   <VERS vnumber="1">In the beginning God created the heaven and the earth.</VERS>
   <VERS vnumber="2">And the earth was <STYLE css="font-style:italic">without form</STYLE>, and void;<BR/>and darkness was upon the face of the deep.</VERS>
   <VERS vnumber="3">And God said, Let there be light<NOTE type="x-studynote">a note</NOTE>: and there was light.</vers>
   <VERS vnumber="4">And God saw the light, that it was good: &amp; God divided the light from the darkness.</VERS>
  </CHAPTER>
  <CHAPTER cnumber="2">
   <VERS vnumber="1">Thus the heavens and the earth were finished.</VERS>
  </CHAPTER>
 </BIBLEBOOK>
 <BIBLEBOOK bnumber="2" bname="Matthew" bsname="Mat">
  <CHAPTER cnumber="1">
   <VERS vnumber="1">This book claims to be Exodus (2) but says Matthew.</VERS>
  </CHAPTER>
 </BIBLEBOOK>
 <BIBLEBOOK bnumber="43" bname="John" bsname="Jhn">
  <CHAPTER cnumber="3">
   <CAPTION vref="16">The love of God</CAPTION>
   <VERS vnumber="16">For God so loved the world, that he gave his only begotten Son.<XREF fscope="Rom 5:8"/></VERS>
  </CHAPTER>
 </BIBLEBOOK>
 <BIBLEBOOK bnumber="99" bname="Tobit">
  <CHAPTER cnumber="1"><VERS vnumber="1">Not in the canon.</VERS></CHAPTER>
 </BIBLEBOOK>
</XMLBIBLE>
"""


def plain_files(w):
    w.put("zefania_sloppy.xml", ZEFANIA)
    w.put("addon.csv",
          "book,chapter,verse,text\r\n"
          "Genesis,1,1,\"In the beginning God created the heaven and the earth.\"\r\n"
          "Genesis,1,2,\"And the earth was without form, and void;\r\nand darkness was upon the face of the deep.\"\r\n"
          "John,3,16,\"For God so loved the world, that he gave his only begotten Son, \"\"believe\"\".\"\r\n"
          "Tobit,1,1,\"Not in the canon.\"\r\n")
    w.put("addon.json", json.dumps([
        {"book": "Genesis", "chapter": 1, "verse": 1, "text": "In the beginning."},
        {"book": "Genesis", "chapter": 1, "verse": 2, "text": "And the earth was without form."},
        {"book": "John", "chapter": "3", "verse": "16", "text": "For God so loved the world."},
    ], ensure_ascii=False, indent=1))


def main():
    check = "--check" in sys.argv
    w = Writer(check)
    mybible_files(w)
    mysword_files(w)
    theword_files(w)
    plain_files(w)
    if check:
        if w.drift:
            print("fixtures drifted from the generator:", *w.drift, sep="\n  ")
            sys.exit(1)
        print(f"{len(w.names)} fixtures match the generator")
    else:
        total = sum(os.path.getsize(os.path.join(OUT, n)) for n in w.names)
        print(f"wrote {len(w.names)} fixtures, {total/1024:.0f} KiB, to {OUT}")


if __name__ == "__main__":
    main()
