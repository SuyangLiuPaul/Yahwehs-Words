# Text search modes

Fuzzy and pinyin are mutually exclusive. Select either option to switch to that mode. Select the active option again to return to exact search. Enabling fuzzy search from Settings also turns pinyin off.

- **Exact:** both options off; normal literal text matching.
- **Fuzzy:** script variants, synonyms and English inflections, with expanded matches labelled.
- **Pinyin:** Chinese text in the selected edition, using full pinyin, tone-marked or spaced pinyin, or initials. Select a Chinese edition for queries such as `yesu` or `ys`.

These options apply to plain-text queries. Strong numbers and operator queries retain their existing rules. Book scope filters and chart units are unchanged.

Older releases allowed both options to be stored. On upgrade, that combination becomes fuzzy-only; pinyin-only and both-off preferences are preserved. Runtime matchers update before listeners, and preference writes are serialized for rapid taps and resets.

This requirement was added after Words v1.6.36 and Sword v1.6.331 were tagged and their signed packages uploaded. Those immutable packages do not include this follow-up. A later version must be built and delivered before store installations receive this behavior; do not cancel pending reviews or describe old binaries as containing it.
