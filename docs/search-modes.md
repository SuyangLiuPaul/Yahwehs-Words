# Text search modes

Fuzzy and pinyin are mutually exclusive. Select either option to switch to that mode. Select the active option again to return to exact search. Enabling fuzzy search from Settings also turns pinyin off.

- **Exact:** both options off; normal literal text matching.
- **Fuzzy:** script variants, synonyms and English inflections, with expanded matches labelled.
- **Pinyin:** Chinese text in the selected edition, using full pinyin, tone-marked or spaced pinyin, or initials. Select a Chinese edition for queries such as `yesu` or `ys`.

These options apply to plain-text queries. Strong numbers and operator queries retain their existing rules. Book scope filters and chart units are unchanged.

Older releases allowed both options to be stored. On upgrade, that combination becomes fuzzy-only; pinyin-only and both-off preferences are preserved. Runtime matchers update before listeners, and preference writes are serialized for rapid taps and resets.

This requirement was added after Words v1.6.36 and Sword v1.6.331 were tagged and their signed packages uploaded. Those immutable packages do not include this follow-up. The follow-up release is 1.6.37: websites and GitHub assets are published, and signed iOS/Mac builds are delivered with external Beta review submitted. Microsoft Words1.6.37 is submitted for certification; Sword1.6.332 is queued after its current certification; Google draft status is recorded in `release-2026-09-30.md`. Store installations receive this behavior only after the new package is approved and installed; do not cancel pending reviews or describe old binaries as containing it.
