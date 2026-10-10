# iPhone song status repair — 2026-10-11

Owner supplied IMG_9613–9616 from installed iPhone 1.7.16.

- Mini-player now distinguishes loading and unknown duration from a zero-length recording; loading uses an indeterminate progress line.
- Absent/unreachable artwork now uses the same bundled source icon as the catalogue (including CDC), with a safe fallback for unknown sources.
- Download manager suppresses its empty-state message while a batch is active or failures are listed. Initial batch progress is indeterminate until the first item completes; the summary uses an active download icon. Existing per-song byte progress, timeout, cancel and retry handling remains.

Checks: 14 focused tests passed (playback status in three locales, offline source artwork, native song downloads and shared recording download safety); targeted Flutter analysis clean.

These screenshots alone do not establish a network or disk failure. Actual iPhone playback and download recovery remain device checks. No new signed package or store acceptance is claimed by source tests. Sword has no song player/download catalogue; these changes belong to Words.
