# Words UI refinements — 2026-10-10

## Changes

- Inline circled footnotes are smaller (55% of the reader's selected font size), retaining middle alignment, note numbering, tap behaviour and text copying. Verse numbers and scripture text are unchanged.
- My photo verse cards have an Adjust photo viewfinder: drag, pinch, zoom controls, reset, cancel and apply. A cover crop retains the photo's proportions and prevents blank edges. Editor, preview and PNG use the same framing. Reselect/remove resets it; closing the share sheet releases the photo as before. Dimensions come from the cached decoded image rather than a second full-resolution decode.
- Both a top lexical Strong's number and a lower original-word chip offer AI for the displayed entry and its actual source verse. Related-entry navigation preserves that source; returning restores the original word. Generation guards reject late answers even after navigating away and back to the same number. Same-frame double taps start one request. Transcript copying uses the displayed lemma/number and source verse.

## Verification

- Local analysis clean; full suite 4,121 passed, 36 existing skips. Final focused suite 74 passed, including same-frame double tap, multi-verse Acts 24:26–27 context, stale-answer rejection and copied transcript. HTTP responses are mocked with a dummy key; no real AI call or reader key was used.
- Photo tests rasterise actual PNGs, check both crop edges at wide/tall ratios, pinch anchor preservation, drag/pinch/reset/cancel/reopen and original export/picker/contrast/error cases.
- Chrome actual app at mobile width: top and lower G4201 both show the AI action for Acts 24:27. Baseline top lacked it; baseline lower already had it. The old `LOWER AI false` log was a text-detection error, not evidence of missing lower AI.
- Genesis 1:20 before/after screenshots cover 18/28 font sizes and verse/paragraph modes. Footnote text/number and adjacent wrapping were visually checked.
- Photo fixture: actual file chooser, 150% zoom and drag, visible preview and a valid 1080×1164 PNG. Reopen retains the framing; resetting then cancelling preserves it. Landscape export is byte-identical to portrait export. A fresh share sheet releases the photo; reselect starts at 100% and remove clears it.

Evidence: `/Users/pliu0036/Downloads/Yahweh-Words-UI-20261010/`.

## Delivery scope

Words only. Website maintenance at 1.7.16, no version bump, tag, native build/upload or Sword change. Main/CI and six international/China dev/QAT/prod deploy receipts will be recorded after verified delivery. Physical iPhone/Android/macOS gesture and share-sheet checks remain device checks; browser and widget checks do not establish physical-device success. Previously completed offline downloads are preserved.
