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
- Scroll gesture guard plus pure/batch tests:23 passed after fixing the report text to yield scrolling to its surrounding scroll view.
- Flutter analysis: no issues.
- Isolated browser UI correctly reports three synthetic failures and retains the original index/bodies after recheck. Same dev origin/profile retained cdc:e0460 across19→20: expected/actual3217162bytes and ID3 prefix. These are separate from the unresolved original production failure.
- Native/store 1.7.17 tags and packages are unchanged. Sword has no song download feature and remains web 1.7.18.

## Original production failure remains unresolved

Same production Chrome profile/tab/origin retained one song record across web 18→19 but reported unavailable audio. The previous explicit retry already replaced that test body before detailed diagnostics existed. Original keys/body/bytes cannot now be recovered from UI evidence. Recovery and later playback passed; direct upgrade retention did **not** pass. Host storage pressure is only a hypothesis, not a proven cause. The new report can distinguish the next occurrence; it does not retrospectively prove the original cause.

Owner screenshots (575 downloads / about 3 GB, versus 563 pending) still need the exact app/site/browser/PWA context. No owner download/cache/index was cleared and no bulk batch was requested. Physical iPhone/Watch/vehicle and audible route checks remain unverified.

Current and final delivery evidence is maintained at `/Users/pliu0036/Downloads/Yahweh-Store-API-20261011/storage-diagnosis-20261011/checkpoint.json`, with build manifests and seven-resource checks in the parent evidence directory. Check its current state before assuming production delivery.
