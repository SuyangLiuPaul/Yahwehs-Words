# Add-ons: what only a real module on a real device can prove

*Written 2026-10-17. Fill in the result column the day each check is done, and
say which file and which build.*

The unit suite proves a lot: the SQLite reader matches Python's `sqlite3` row for
row (including multi-level b-trees and overflow chains), survives truncation,
cycles and 600 random corruptions, every parser matches the layout its source
documents, and the normaliser keeps anything bracketed out of the reader. What it
**cannot** reach is IndexedDB, `path_provider`, the platform file chooser and a
real publisher's real file. That is this checklist.

**Rule: nobody downloads a module for this without the owner approving that file,
by name and source, in chat.** Two public-domain KJVs — one MyBible.zone module,
one theWord module — would cover the SQLite and text formats. Used as private
inputs; **never committed** (the committed fixtures stay synthetic).

## Per platform

For each: import one real module of each format you have; read a chapter; jump
to a verse from search; switch it off and on; restart the app; remove it.

| Platform | Picker opens | Imports | Reads a chapter | Survives restart | Remove works | Notes |
|---|---|---|---|---|---|---|
| Web — Chrome | | | | | | |
| Web — Safari | | | | | | |
| Web — private browsing | n/a | **must say "this device (or browser) wouldn't store it", not "your file is damaged"** | | | | |
| iOS (iPhone) | | | | | | |
| iPadOS | | | | | | |
| Android | | | | | | |
| macOS — **sandboxed release build** | | | | | | The `user-selected.read-only` entitlement: without it the panel opens and returns a path whose bytes are then refused |
| Windows | | | | | | |
| Linux | | | | | | |

## Per format (once, on any platform)

| Format | Real file used (name, source, size) | Verses read | Books dropped | Text spot-checked against the publisher's own app | Result |
|---|---|---|---|---|---|
| MyBible.zone Bible | | | | | |
| MySword Bible | | | | | |
| theWord `.ont` | | | | | |
| theWord `.nt` | | | | | |
| Zefania XML | | | | | |
| CSV / JSON (made by hand) | | | | | |

## Things to look for in a real module

* **Long verses survive.** A truncated verse is the failure mode an overflow-page
  bug produces and nothing would say so. Compare the longest verse (Esther 8:9)
  with the source.
* **Footnotes show as numbered markers**, not as raw `<n>…</n>` or `<RF>…<Rf>`.
* **No raw angle brackets, no numbers like `H5921` / `G3056`** anywhere in the
  reading text.
* **The report says what it did not import** (books, headings, cross-references,
  Strong's), and the counts are plausible for the file.
* **Psalm titles** (numbered 0 in MyBible / MySword) sit above verse 1.
* **A module that is not full-canon** (an NT-only theWord `.nt`): the picker
  lists it; opening it from Genesis lands on its own first verse; the daily-verse
  card for an OT reference falls back to a named edition instead of an empty card.
* **The app's own text is untouched.** The KJV still reads *Yahweh*; the import
  still reads *the LORD* exactly as its file has it, in the reader, when copied,
  and when projected.
* **Nothing about the import leaves the device.** Sync the reading position while
  reading an import and confirm the cloud copy names a bundled edition, not
  `user-…` (Words).

## When something fails

Record the file's name, source, size and SHA-256 prefix (the Add-ons detail sheet
shows it), the platform and build, and what the report said. A failure that is
a refusal with a plain sentence is the system working; a failure that is a blank
screen, an exception or silence is a bug.
