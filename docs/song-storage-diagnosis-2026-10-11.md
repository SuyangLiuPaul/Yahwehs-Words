# Browser song storage diagnosis — web 1.7.20

## What changed

- Startup reads and validates each existing cache body once, then uses that same body for playback. No second read can silently leave a ready recording without its offline source.
- Downloads waits for its records/catalogue to finish loading before presenting totals.
- A manual **Inspect storage (no download)** report includes exact origin, redacted cache keys, expected/actual bytes, prefix, validation phase, workers and storage quota. It does not fetch audio, delete cache/index, or send the report to a server. Copy is explicit.
- Missing bucket/key, Vary mismatch, empty body, size mismatch, rejected prefix and read exception have separate reasons. A local first-failure journal survives retry; it contains diagnostics, not audio or credentials.
- **Recheck saved audio (no download)** retries reads only when no download is pending. It captures failure evidence first and leaves original bodies/index/queue intact.

## Verification

- Pure classification/redaction and existing batch-plan tests: 18 passed.
- Isolated real Chrome CacheStorage tests: 4 passed (missing bucket/key, actual bytes/prefix without body mutation, Vary mismatch, first failure retained without index mutation).
- Flutter analysis: no issues.
- Native/store 1.7.17 tags and packages are unchanged. Sword has no song download feature and remains web 1.7.18.

## Original production failure remains unresolved

Same production Chrome profile/tab/origin retained one song record across web 18→19 but reported unavailable audio. The previous explicit retry already replaced that test body before detailed diagnostics existed. Original keys/body/bytes cannot now be recovered from UI evidence. Recovery and later playback passed; direct upgrade retention did **not** pass. Host storage pressure is only a hypothesis, not a proven cause. The new report can distinguish the next occurrence; it does not retrospectively prove the original cause.

Owner screenshots (575 downloads / about 3 GB, versus 563 pending) still need the exact app/site/browser/PWA context. No owner download/cache/index was cleared and no bulk batch was requested. Physical iPhone/Watch/vehicle and audible route checks remain unverified.
