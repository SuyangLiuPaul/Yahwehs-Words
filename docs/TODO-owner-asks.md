# Owner's to-do list (Words and Sword)

Kept in the same words in both repos. Newest first. Each item says what was
asked, what was decided, and what blocks it. Nothing here is released until
the owner says "release".

## 1. Vertical continuous scrolling (asked 2026-10-16, user feedback)

"A mode that can scroll forwards and backwards in the Bible, for reading" —
Olive Tree's *Vertical Scrolling* switch in Quick Settings.

- A switch, default OFF: **Vertical continuous scrolling**, in Settings and in
  the reader's quick menu.
- On: chapters flow into one another both ways; a chapter heading divides
  them; the header's book/chapter follows the scroll; the bottom bar's
  previous/next jump to the neighbouring chapter's start.
- Built as a sliding window of neighbouring chapters in one list (append near
  the end, prepend near the start while keeping the reading position), not the
  whole Bible at once.
- Must keep working: verse selection, highlights, notes, search jumps, the
  reading plan's "read to the end of each chapter", reading history.
- Words and Sword each have their own reader code: do both, keep them alike.
- Difficulty: medium-high (the reader is the core). Verify in the web build
  with screenshots, ship to dev first; the owner tries it on the phone.
- Order: do this BEFORE item 2.

**Status 2026-10-16:** built in both apps, committed locally (no version bump),
deployed to dev/qat only (Words also cn-dev/cn-qat). Words: HomePage reader;
Sword: classic 阅读 mode only (the 对照 parallel pane is a different reader and
is not affected). Not covered: reading-plan sessions keep paging one chapter
at a time (Words); not yet tried on a phone by the owner. Tests:
`test/vertical_scroll_test.dart` in both repos.

## 2. Add-ons: importing third-party modules (asked 2026-10-16)

Owner's feedback: the apps are closed; long-lived free study software
(e-Sword, MyBible, 信望爱) lasts because users can import third-party modules
(dictionaries, commentaries, Bible versions). Power users want to import
SQLite and other custom formats.

Formats (what is known; verify every one against a REAL file before shipping):

| format | container | plan |
|---|---|---|
| TheWord Bible `.ont` `.ot` `.nt` | plain text, one verse per line, settings block at the end | **first** — easiest |
| TheWord `.dct.twm` `.cmt.twm` `.topic.twm` `.gbk.twm` | believed SQLite | verify |
| MyBible.zone `.SQLite3` | SQLite; spec is a Google Doc linked from https://mybible.zone/?p=1626 | **first** |
| MySword `.bbl/.cmt/.dct.mybible` | SQLite, HTML content; table layout not documented | **first**, inspect real files |
| e-Sword 9–10 `.bblx .cmtx .dctx` | reported as Microsoft Access (Jet), RTF | NOT supported; say so in the UI |
| e-Sword 11+ `.bbli .cmti .dcti`, 信望爱 | no confirmed spec | not promised |
| own JSON/CSV | defined by us | yes |

Module types, easiest first: reading plans (JSON/CSV), cross-references,
verse lists / memory sets, Bible versions, commentaries, dictionaries and
topical entries, personal notes/highlights (more import formats), devotional
or sermon texts (Markdown/JSON), custom fonts, hymn/lyric sets, audio keyed
to chapters. Timelines / genealogies / map layers: needs a data format first,
not now.

Shared framework (build once): an **Add-ons** page (import, list, enable,
disable, delete, size); importer with a report ("N verses did not match");
storage (IndexedDB on web, app documents folder natively); a licence
confirmation on import; everything stays on the device — **never uploaded,
never synced**. Imported text carries only what the file carries (no invented
Strong's tags). Same code in Words and Sword.

Dependencies to add: a SQLite reader (native library; WebAssembly build on
the web) and a file picker. Both change every platform's build — CI must be
green on all five before release.

Blocked on: real sample modules. Either the owner names files he has used, or
approves downloading free public samples one at a time (name, source URL and
size told first).

## 3. Smaller open items

- **Disk space** (99% full, 2026-10-16): safe-to-delete caches listed to the
  owner (`~/.dartServer/.analysis-driver` 14.4G and three updater caches
  ~2.7G); the delete was refused by the permission layer. Big items are the
  owner's own data (Codex sessions 152G, piano-site 78G, HomeAssistantVM
  30.7G, simulators, AVDs, Downloads). Old worktrees `Words-release-178`
  (uncommitted work and unpushed commits: do NOT delete),
  `*-settings-scroll-20261007` (linked from `~/Documents/Yahweh-Apps`).
- **About page**: the owner said much of its design still needs changing —
  ask which parts. Done so far: purpose + John 17:3 + the name Yahweh
  (6,828 occurrences, counted from WLC), stacked attribution rows, update
  controls only in Settings, no author credit, no "Update settings" button
  (committed locally, ships with the next version).
- **GitHub link on About** carries the owner's user name (SuyangLiuPaul):
  remove the button or replace the link? — undecided.
- **Tables not yet restyled**: the originals sheet and one family-tree table.
- **Store automation** (Play draft upload, Microsoft draft, iOS script) is
  wired but NEVER test-run; its workflow commits are not on the default
  branch.
- **雅偉的話** Apple review reply: owner decides licensing and records the
  device video.
- **Language gaps**: no flutter_localizations delegates (Back / Show menu /
  "4000 characters remaining" English in a Chinese UI), evidence page verse
  references English in Chinese, `/songs` English text contains 福音电台,
  Sword Chinese UI not audited, deep Sword menu pages not audited.
