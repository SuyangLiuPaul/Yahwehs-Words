# Offline media downloads — 2026-10-10

## Changed

- Words: visible song-download entry on the songs page and Home. Batch downloads deduplicate IDs, show byte/progress and retry failures. Cancel waits for writers; interrupted/invalid files are not marked complete. Existing song files/index and downloaded sheet music are retained.
- Both apps: download sermon recordings by part, view progress, cancel/retry/delete and reopen the sermon. Playback prefers saved audio. Transcripts and EV/scripture assets are unchanged.
- Native: temporary file then atomic rename, network/stall timeouts, invalid/truncated response checks, disk-write failure handling. Blocked known church origins can retry through the existing media proxy.
- Web: real Cache Storage and blob playback; downloaded media is exempt from startup cache cleanup. Sword now has its own network-first app-shell worker and Windows audio plugin.

## Verification

- Flutter analysis: clean in both apps.
- Words full suite: 4,116 passed, 36 skipped. Sword full suite: 6,154 passed, 10 skipped; final additional proxy test passed separately.
- Shared queue/storage tests cover duplicate requests, cancellation/late writes, retry, cold restore, eviction, deletion, HTML/empty/truncated replies, disconnection and simulated quota/write failure. Words additionally tests the actual song native service and Windows local-path recognition.
- Both browser Cache Storage suites: 4 tests passed in Chrome each. Chrome controlled audio fixture also restored after cold offline navigation, played without network and deleted successfully.
- Mobile-width screenshots of Words song entries and both sermon pages reviewed. These are browser checks, not physical iPhone checks.
- WebKit persistent configuration: restored saved audio after a new page, played with HTTP/HTTPS requests blocked, then deleted successfully. Cold offline navigation remains unverified. WebKit persistence/audio checks and deployment results are recorded in the evidence folder. Playwright WebKit ephemeral contexts lose Cache Storage between pages; persistent contexts restore it. Its offline-emulation behavior is recorded separately from real Safari/PWA behavior.

## Limits / next device checks

Physical iPhone/TestFlight, Android, Windows, Safari and installed iOS PWA are not verified by these browser/unit checks. Safari and installed PWA may have separate storage; download in the instance used offline. Browser eviction and no-space conditions remain possible and must not be shown as successful downloads. Open the desired sermon online once to cache its text/app assets before using a web page offline. Audio fixtures establish playback mechanics, not availability of every upstream recording.

This task ships websites only, without a version bump or native store upload. Source remains version 1.7.16; existing tags are immutable. Native device fixes require a later built/installed release.

Evidence: `/Users/pliu0036/Downloads/Yahweh-Offline-Media-20261010/`.
