# Selection sharing — 2026-10-10

## Change

Removed the duplicate standalone **Verse image / 经文图片** icon from the Words selected-verses toolbar. Use **Share → Share image** for the same verse-card preview and PNG export. **Share → Share link** still copies the selected text and verse link. Copy, projection and every other selection tool remain available.

Only the obsolete icon and its dedicated comment were removed. The `onImage` callback, share chooser and `VerseCardSheet` are unchanged. Sword has no change in this task. Prior offline-media and EV corrections are preserved.

## Checks

- Flutter 3.44.2 analysis: no findings.
- Existing share chooser, verse-card and verse-photo tests: 38 passed.
- Actual compiled browser UI: English and Simplified Chinese selection, chooser dismissal, copied verse text/link, multi-verse preview and saved PNG verified at phone width, including larger Chinese menu/text sizing.
- Landscape (844×390) and desktop (1440×900): chooser cancellation, copied text/link, multi-verse preview/PNG and return to the reader passed.
- Additional English single-verse PNG export passed. Exported English/Chinese cards were visually inspected; no content/reference clipping observed.
- Final CI and website delivery receipt: `/Users/pliu0036/Downloads/Yahweh-Share-Entry-20261010/delivery-final.json` (written only after verified deployment).

Browser evidence: `/Users/pliu0036/Downloads/Yahweh-Share-Entry-20261010/`. Browser viewport checks are not physical iPhone, Android or Mac application verification.

## Delivery scope

Owner authorized GitHub main and Words dev/production websites. Keep version **1.7.16**; no new native package or tag. Deploy through the canonical no-bump wrapper so international/China dev, QAT and production sites receive their correct bundles. Record exact CI/source and build/live fingerprints after deployment.
