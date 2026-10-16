# Add-ons: importing third-party Bible modules

*Written 2026-10-17. The same document ships in Yahweh's Words and Yahweh's Sword; the code it describes is shared between them (see [Where the code lives](#where-the-code-lives)).*

A reader can bring in a Bible text they downloaded elsewhere and read it in the
app. It appears in the version list beside the editions the app ships, marked
**Your file**, and can be switched off or removed at any time.

**Settings › Add-ons** (导入模块 / 匯入模組).

## What it reads

| Format | Extension | Status | What is read |
|---|---|---|---|
| **MyBible.zone** | `.SQLite3` (any name — detection is by content) | Supported | Bible modules: `verses`, `info`, `books`/`books_all`, `stories`, `introductions` |
| **MySword** | `.bbl.mybible` | Supported | Bible modules: `Bible(Book,Chapter,Verse,Scripture)` and `Details` |
| **theWord** | `.ont` `.ot` `.nt` | Supported | Plain-text Bibles: one verse per line, KJV versification, settings block after |
| **Zefania XML** | `.xml` | Supported, forgiving | `XMLBIBLE › BIBLEBOOK › CHAPTER › VERS` |
| **JSON** | `.json` | Supported | `[{"book","chapter","verse","text"}]` |
| **CSV** | `.csv` `.tsv` | Supported | `book,chapter,verse,text`, optional header, `,` `;` or tab |
| MyBible / MySword **commentaries, dictionaries, cross-references** | | Recognised, **not imported yet** | The reader is told what the file is |
| **e-Sword** | `.bblx` `.bbli` `.cmtx` … | **Not supported** | Refused by name |
| theWord `.twm`, `.ontx/.otx/.ntx` (encrypted), MySword with `Encryption` set | | **Not supported** | Refused; the app never tries to open what a publisher locked |
| **zip** archives | | Not yet | "Unzip it first, then pick the file inside" |

Only **Bible texts** are imported in this release. Commentaries and
dictionaries share the MyBible file format, so they are recognised and
declined with an honest message; they need a place in the reader to live
(a per-verse commentary sheet, a dictionary lookup) and that is a separate piece
of design.

### Why e-Sword is not supported

The only e-Sword layout we have is the one a *converter's exporter* writes
(e-Sword 11 `.bbli`: `Details`, `Bible`, `Notes`, HTML-ish text). That tells us
what one writer emits, not what readers' real files contain, and the older
`.bblx` layout and its RTF-ish text are unverified. Separately, a large share
of e-Sword modules are commercial, so this is the format most likely to turn an
importer into a piracy complaint. It is a decision to revisit when a real file
is in hand — not before.

## What happens to a file

```
pick a file
   │  (file_selector, one door on every platform; bytes only — no path, no handle)
   ▼
detect by CONTENT ──► refuse with a plain sentence ──► (nothing stored)
   │
   ▼
parse (in slices that yield to the event loop; Cancel is always live)
   │   • SQLite file → our own pure-Dart reader (below)
   │   • every verse's markup → the app's four-token vocabulary (below)
   │   • every verse fitted to the 66-book canon (below)
   ▼
"Here is what was found"  ◄─ the reader names it and ticks the licence box
   │
   ▼
encode as the app's own verse JSON ──► payload store, then manifest (two-phase)
   │
   ▼
the report: what was kept and, never silently, what was not
```

A refusal, a cancel, or a failure at any point leaves **nothing** behind.

## The licence confirmation

Import stays disabled until the reader ticks a box that is **never pre-ticked**:

> I confirm I have the right to use this file on this device. This app does not
> and cannot check where it came from or who owns it. Imported content stays on
> this device — it is never uploaded, synced or shared.

The ui-strings **key** of the sentence they agreed to is stored with the add-on
(`licenceAttestation`), so a later change of wording cannot retroactively claim
they agreed to the new one. An imported edition is marked **Your file**
everywhere, carries `aboutLicenseUserSupplied` ("Supplied by you · this app has
not verified its source or rights · stored on this device only") and is **not**
exempt from the Copy Center's 500-verse ceiling.

## What stays on the device

Everything. There is no upload, no sync, no share, and no code path that could
add one — the store has no network client.

* **Native**: files under the app-**support** directory (`addons/manifest.json`
  and `<id>.json`). Support rather than Documents on purpose: Documents is
  visible in the iOS Files app and goes into iCloud backup, which would be an
  *upload, by Apple,* of somebody else's text.
* **Web**: IndexedDB. Two object stores: `versions` (one record per add-on) and
  `manifest`.
* The **synced reading position** (Words only) never carries an add-on's code,
  which is a slug of a name the reader typed. When the text on screen is an
  import, the synced blob names a bundled stand-in of the same language
  (`syncSafeVersion`). Nothing about an import leaves the device.
* The Add-ons page's **Remove** deletes the text. The reader's original file is
  untouched.

The manifest (a few KB) is the only thing read at boot; a payload (megabytes) is
read only when that edition is opened. An unreadable manifest is an empty one —
the app still starts.

## What it does to the text

The reader understands exactly four things in a verse's text, and the importer
emits only those:

| Output | Meaning |
|---|---|
| plain text | |
| `[words]` | words the translators added (rendered as an insertion, as the LEB and NASB are) |
| `<note: …>` | a footnote |
| `\n` | a line break inside a verse |

There is **no italic span, no words-of-Jesus colour and no inline Strong's
number** in that list, so the importer does not pretend to have them: red
letters and Strong's numbers are counted and dropped, and the report says so.
(Inline Strong's in this app is a separate aligned layer loaded from its own
files; an import cannot reach it, and does not try to.)

| Source markup | Becomes |
|---|---|
| MyBible `<i>` · GBF `<FI>…<Fi>` (words added by the translators) | `[…]` |
| MyBible `<n>` · GBF `<RF>…<Rf>` · Zefania `<NOTE>` | `<note: …>` |
| MyBible `<f>` footnote *markers* (the body lives in another module) | dropped, counted |
| `<S>1234</S>` · `<WG123>` `<WH123>` `<WT …>` · `<m>` (Strong's, morphology) | dropped; the add-on is marked "carries Strong's" |
| `<J>` `<e>` `<t>` · GBF `<FR>` `<FO>` `<FU>` · simple HTML | tag stripped, text kept (`<t>` starts a line) |
| `<br/>` · GBF `<CL>` | `\n` |
| `<pb/>` · GBF `<CM>` | **end of a paragraph**: the *next* verse opens one (best effort — a paragraph hint, never text) |
| `<h>` · GBF `<TS>…<Ts>` · Zefania `<CAPTION>` · MyBible `stories` | headings: dropped, counted |
| GBF `<RX43.3.16>` · Zefania `<XREF>` · MyBible cross-reference modules | dropped, counted |
| GBF `<Q>…<q>` (interlinear blocks) | dropped whole |
| anything else | tag stripped, inner text kept, counted |

### The text is shown exactly as the file has it

The app's usual render-time divine-name normalisation (*the LORD* → *Yahweh*,
耶和华 → 雅伟) is **not** applied to an imported text. The app's own
restorations are curated work the ministry stands behind; a stranger's text is
not ours to amend, and it would be shown under that publisher's name.
It is skipped on every path that knows which edition a verse came from — the
reader, copy, the verse popup, projection, the verse card — through the
`verbatim:` flag of the sanitisers in `lib/constants/text_patterns.dart`
(`isVerbatimEdition`), and `test/addons/addon_integration_test.dart` pins it.
(Search still normalises its index so a search for *Yahweh* finds *the LORD*.)
The Add-ons detail sheet says so.

### Security

A module is somebody else's file. The normaliser never copies a tag through —
not `<a>`, not `<img>`, not `<script>`, no link, no URL — so there is nothing
for the reader to execute or fetch: safe **by construction**, not by sanitising.
The last pass strips every `<`, `>`, `{`, `}`, `[` and `]` the module did not
turn into one of the four tokens (an unbalanced one would otherwise be eaten by
the reader's annotation pattern and swallow the rest of the verse), and strips
the importer's own private markers from the input so a module cannot smuggle
them in. `test/addons/markup_normaliser_test.dart` runs 10,000 random tag soups
through each dialect and asserts nothing bracketed survives.

## Fitting a module to the canon

| Case | Action |
|---|---|
| a book not in the 66 (Tobit, Maccabees, …) | dropped, **named** in the report |
| a MyBible `book_number` we do not know | dropped, the raw number quoted — never guessed |
| chapter < 1 or past the book's last chapter | dropped, counted |
| verse 0 (a psalm title in MyBible / MySword) | folded onto verse 1 as its **superscription** (the mechanism the LEB's psalm titles already use) |
| a verse past the usual last verse of its chapter | **kept** — the reader derives its verses from the list |
| the same (book, chapter, verse) twice | first wins, the rest counted |
| empty text | skipped, counted |
| a book name that is not an **exact** English / 简体 / 繁體 name (JSON, CSV) | dropped and named; **abbreviations are never guessed** ("Jud" is Judges or Jude) |
| Zefania `bnumber` and `bname` disagree | that book is **refused**, named; not guessed |
| a theWord file with the wrong number of verse lines | **refused, with the count**: with no verse numbers in the file, a wrong count cannot be placed, and placing Genesis 1:1 on 1:2 would be worse than not importing |

**Versification is recorded, never corrected.** A module whose
`info.russian_numbering` is true numbers the Psalms the Septuagint way; the
importer stores that fact, warns at import and on the add-on's detail sheet, and
leaves the numbers alone. Remapping would be inventing an alignment the file
does not carry. (`assets/versification.json` exists in this repository because
joining differently-numbered editions "handed 1,823 references another verse's
Hebrew".) Right-to-left modules are recorded and warned about; the reading
pane is not flipped yet.

### MyBible.zone book numbers

A fixed legacy numbering from the published specification's "Books reference"
table: Genesis 10 … Malachi 460, Matthew 470 … Acts 510, Romans 520 …
Hebrews 650, James 660 … Jude 720, Revelation 730 — with other traditions'
books in the gaps (Tobit 170, Judith 180, Wisdom 270, Sirach 280, Baruch 320,
1–4 Maccabees 462/464/466/467, …). Pinned in
`lib/utils/addons/mybible_book_numbers.dart` and
`test/addons/mybible_book_numbers_test.dart`.

## The SQLite reader

`lib/utils/addons/sqlite_reader.dart` — a **read-only, pure-Dart reader for the
SQLite file format** (https://www.sqlite.org/fileformat2.html).

*Why not a package.* `sqflite` has no web, Windows or Linux build. `sqlite3`
needs a native binary or a WebAssembly file served beside the app on each of
five platforms. And the input is a file somebody downloaded from a forum:
reading it with a C library is the riskier choice, not the safer one. A reader
written against the documented format, in a memory-safe language, with every
loop bounded, behaves identically everywhere and cannot be made to read outside
the bytes it was handed.

*What it reads.* Ordinary (rowid) tables: the b-tree of leaf and interior table
pages, with overflow chains — all a module needs, because nothing is looked up
by key; every row is read once. No index traversal, no collation, no freelist,
no WAL, no SQL.

*What it refuses, by name.* A non-SQLite header (including SQLCipher-encrypted
files); `WITHOUT ROWID` tables; UTF-16 databases; non-zero reserved space per
page; files over the limits.

*Hostile input.* No recursion (explicit stack); every page visited at most once
(cycles, shared pages and overflow loops all surface as a typed error); every
page number, cell pointer, varint and declared length checked against the bytes
actually present; long scans yield to the event loop and poll for cancel.

| Limit | Value |
|---|---|
| file | 64 MB |
| rows read from one table | 250,000 |
| one cell | 4 MB |
| decoded content in one scan | 48 MB |
| the app's own normalised payload | 24 MB |

`test/addons/sqlite_reader_test.dart` compares every table of seven fixture
databases, row for row, with what **Python's own `sqlite3`** returned — an
independent implementation — including a multi-level b-tree (page size 512), a
65,536-byte page, and overflow chains straddling the local-payload thresholds.
`sqlite_reader_hostile_test.dart` truncates real files at every 97th byte,
points interior pages at themselves, builds three-page cycles, lies about page
counts and varints, flips 600 random bytes, and requires every result to be a
typed refusal in under two seconds.

## What is verified, and what is not

This is the honest ledger. **No third-party module has been downloaded for this
work**; every fixture is generated here (`tools/make_addon_fixtures.py`).

| Claim | Evidence |
|---|---|
| MyBible.zone table and column layout, book numbers, markup | The published specification (https://mybible.zone/?p=1626 → "MyBible modules format"), read in full on 2026-10-17 |
| MySword `Bible(Book,Chapter,Verse,Scripture)`, plain 1–66 book numbers, GBF tags | `tools/import_yahweh_modules.py` (Sword) reading the publisher's real `cuvs+-YHWH.bbl.mybible`; the layout and tags also match BibleMultiConverter's importer |
| MySword `Details` columns | Documented field names (mysword.info/modules-format); the real importer does not exercise them, so **every column is treated as optional** |
| theWord `.ont`: 31,102 lines, BOM, KJV order, `key = value` block after, tag grammar and six real-world defect classes | `tools/import_yahweh_ont.py` (Sword) reading a real export; the shipped `asv-yhwh` came from a theWord module |
| theWord blank vs `- - -` for an absent verse; the full settings key list | **Not verified.** Both are accepted; only a few keys are read, leniently |
| Zefania structure | Example files and two independent libraries; the official XSD was not retrievable. Treated as **forgiving and experimental** |
| That a REAL module of each kind imports | **Not verified.** The fixtures prove the reader and the parsers against the documented layouts; only one real file per format closes that gap |

### Still to do by hand

`docs/addons-manual-verification.md` is the checklist: import one real module
per format on each platform (web in Chrome and Safari including private
browsing; iOS; Android; macOS **sandboxed release**; Windows), read a chapter,
restart, remove it.

Two public-domain KJVs — one MyBible.zone module, one theWord module — would
cover both SQLite and text formats. They would be used as private test inputs
and **not committed**; the committed fixtures stay synthetic. Say so and name
the file before anyone downloads one.

## Where the code lives

Shared, identical in both apps except for the package prefix (copied by
`tools/sync_addon_files.py`, which also fails when they drift):

| Path | Role |
|---|---|
| `lib/utils/addons/sqlite_reader.dart` | the SQLite reader |
| `lib/utils/addons/markup_normaliser.dart` | the four-token vocabulary, the security boundary |
| `lib/utils/addons/parse_{mybible,mysword,theword,zefania,plain,module}.dart` | one parser per format; `parse_module.dart` is the single entry point and detects by content |
| `lib/utils/addons/canon_fit.dart`, `addon_canon.dart`, `book_name_resolver.dart`, `mybible_book_numbers.dart` | fitting to the 66-book canon; `addon_canon.dart` is **generated** (`tools/gen_addon_canon.py`) |
| `lib/utils/addons/addon_payload.dart`, `addon_texts.dart`, `addon_types.dart` | encoding, the sentences the importer says, shared types |
| `lib/models/addon.dart` | `AddonEntry` and `AddonManifest` (`tryFromJson` never throws) |
| `lib/services/addons/*` | the store (native files / IndexedDB / in-memory for tests), the registry, the import service |
| `lib/utils/pick_module_file.dart` | the file picker (`file_selector`) |

Per-app: `lib/pages/addons_page.dart` and `lib/widgets/addon_import_sheet.dart`
(Material in Words, flat in Sword), the catalog wiring in
`lib/constants/bible_versions.dart`, the loader hook in
`lib/services/fetch_verses.dart`, the boot call in `lib/main.dart`, and
`test/addons/addon_integration_test.dart`.

The catalog: `importedVersionLabels`, `importedVersionScripts`,
`importedVersionFamilies` and `importedVersionCoverage` in
`bible_versions.dart` are plain maps filled by `AddonRegistry`; **`versionInfoFor(code)`**
is the one place that answers "what is this version", so no two callers can
disagree about an import's label, language or script. Imported editions sort
**last**: unvetted text must not sit above vetted text. They are left out of the
offline pack's URL list (they are not in the bundle) and out of the Strong's /
interlinear gates (they carry none of that data).

`AddonRegistry.restore()` runs at boot **before** `MainProvider.restoreState()`:
restoreState validates the remembered edition against the catalog, and a
catalog not yet filled would call an imported edition unknown, swap it for a
bundled one and remember the swap.

### Regenerating

```bash
python3 tools/make_addon_fixtures.py            # (re)write the fixtures
python3 tools/make_addon_fixtures.py --check    # fail if they drifted
python3 tools/gen_addon_canon.py --check        # canon vs assets + name maps
python3 tools/sync_addon_files.py --check       # Words ↔ Sword shared files
```

## Adding a format

1. A parser `parse_<name>.dart` returning a `ParsedModule`; use `CanonFitter`
   for every verse and `normaliseVerse` for every text.
2. A branch in `parse_module.dart`'s detection — by content first.
3. A fixture in `tools/make_addon_fixtures.py` and a test in
   `test/addons/parsers_test.dart` that names each thing the format does that
   the others do not.
4. Strings: `addonFormat_<name>` in `ui_strings.dart`, three locales.
5. Say in this document what evidence the layout rests on.

## History

The apps had a web-only importer for a reader's own JSON Bible (Sword, 2026-09-07,
"bwh47"). A broader "custom modules" idea (bwh48) was rejected the same day,
with the condition "re-open only if a reader arrives with a specific work and a
specific format". MyBible.zone's published specification meets that condition,
and the owner asked for it on 2026-10-16. The earlier importer is absorbed: its
IndexedDB database is opened at version 2 and its records are carried into the
manifest the first time the registry runs; two defects in it are fixed on the
way (it read every stored Bible at boot to list their names, and its language
classifier called every imported edition Chinese).
