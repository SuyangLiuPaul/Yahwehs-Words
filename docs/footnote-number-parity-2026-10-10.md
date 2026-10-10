# Footnote-number consistency — 2026-10-10

- Inline circled footnote numbers and note-card numbers share 55% of the local scripture reading size and w600 weight. Note prose stays at 85%. Verse/chapter numbers, numbering, copy semantics, note folding and scripture are unchanged.
- Sword's separate comparison-row inline marker uses the same rule relative to the pane's scripture size. Its tooltip and previous minimum hit area remain.
- Targeted tests cover Chinese/English, 18/28 reading sizes, inline/card parity, unchanged note prose and verse-number styles; existing note/copy/folding tests remain. Sword also covers its pane-size override and existing offline storage/download regressions.
- Scope: website maintenance at 1.7.16, no native/store build, version bump or tag. Physical iPhone/Android/Windows checks remain unverified. Exact CI, browser and live deploy evidence: `/Users/pliu0036/Downloads/Yahweh-Footnote-Parity-20261010/`.

## Today's Words/Sword comparison

- Sermon offline download, visible download/manager entry, saved-audio playback and cold-start shell/cache handling: already synchronized through Sword PR48/49/50; preserved, not reimplemented. Existing actual desktop Chrome and persistent desktop WebKit recordings demonstrate cold offline playback. This is not a physical-device claim.
- Song bulk download/queue/management: Words feature; Sword has no song catalogue, so not applicable.
- Verse image share consolidation and own-photo crop/drag/zoom: Words features; Sword only copies selected verse text/link, so not applicable.
- Strong lexical AI/current-verse/late-answer guards: Words feature; Sword OriginalsSheet and StrongsEntryPage have no AI explanation path. Actual Sword G4201 search and lexicon resolve Acts24:27 and Πόρκιος. No AI feature is added.
- Circled footnote-number typography: inconsistent in both apps and corrected in this batch, including Sword's comparison pane.
