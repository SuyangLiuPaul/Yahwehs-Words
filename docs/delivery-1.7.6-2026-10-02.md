# Paired 1.7.6 release preparation — 2 October 2026

Both apps use visible version **1.7.6**. Build/version codes remain specific to each
platform and increase from its last accepted delivery. Existing tags and pending
store reviews remain unchanged. This record is preparation, not store publication.

## Update prompts

- Google Play: official flexible in-app update API, current installed package,
  account and track eligibility; download progress and explicit restart; no APK fallback.
- iOS / Mac App Store: public Apple lookup for this app, platform and locale country;
  only a newer public version produces a prompt, with a corresponding store link.
- Microsoft Store: asynchronous StoreContext package-update query, with store link.
  No GitHub installer in a Store package. Windows runner compiled and packaged the integration successfully
  (Words preflight 36979332124; Sword preflight 36979335268). The final
  release must use the final tested tag, not an older preflight artifact.
- Direct APK / EXE: retain the existing corresponding GitHub asset/update flow.
- Web: visible refresh prompt from deployed version metadata, preserving local data.
- Prompt labels and actions cover English, Simplified Chinese and Traditional Chinese.

## Delivery gates

Flutter analysis passed for both complete workspaces before version stamping.
No new tag or store delivery is claimed by this document. Merge only after matching
current-head CI, compile Windows integration before publishing, and retain the
existing initial Apple reviews and Words Microsoft certification. After acceptance,
check the actual signed packages and every applicable track/version before upload.

## Words companion and audio repair

Apple Watch, Wear OS, CarPlay and Android Auto share the phone queue. Added browsing
for current queue and local favourites/custom/smart playlists (40 rows per page).
Playlist selection preserves its saved order and recording preference. Queue rows
carry recording identity, preventing a stale numeric index from selecting another
song after shuffle. Missing mixes remain unavailable.

Shuffle/repeat commands carry explicit modes, are allowlisted and serialized on the
companion channel. Metadata immediately publishes queue index/count/label and modes.
Watch controls and CarPlay buttons use the same modes; Android Auto uses native
session actions and custom labelled controls. Repeat-one governs natural completion;
manual Next/Previous can still move to a different track. Shuffle restores the
original playlist order and preserves a loaded current recording even paused at zero.

Added phone-call/route interruption handling and native focus reacquisition before
play/resume. OS focus denial pauses state and keeps the queue; it is not treated as a
broken recording. User Pause cancels automatic recovery. Resume is permitted only
for the same active source/item and when the OS allows it.

Apple Watch UI SDK type-check passed. Actual CarPlay bridge/templates type-checked
against iOS SDK with a stub for app-delegate engine plumbing; two pre-existing Swift
warnings remain. Final Wear Activity compiled against Android 36 and official wearable libraries
(exit 0, wear-final-compile.log). Existing queue/remote/media-control tests passed
49 checks.
Physical vehicle, phone-call recovery, Watch/Wear linkage and real Play older-to-newer
update installation remain required verification gates. Do not describe them as
verified or use disconnected screenshots as marketing.

The real-car report showed CarPlay retaining Play while the phone claimed playback.
Both Play and Pause remain callable in the native media session even during a
stale dashboard icon; Play reactivates audio focus. Sermon Play also attempts
recovery even when its last cached state claimed playing. Interruption snapshots
report paused across songs and sermons. CarPlay reuses existing Now Playing and
pagination templates, avoiding duplicate-template and stack-depth failures.
These are source repairs; audible physical CarPlay recovery is not yet verified.

## Build repair checkpoint

Sword v1.7.5 Android failed AAR metadata validation: url_launcher transitive AndroidX requires AGP8.9.1. Its immutable tag remains unchanged. The paired final delivery target is now1.7.6. Words1.7.5 complete CI timed out in song_media_metadata_test teardown; engine subscriptions are now canceled before disposal and widget teardown uses the real event loop. All12 existing metadata/remote checks passed after repair. No test was removed or skipped. Existing1.7.5 signed preparation archives are not the final source and must not be uploaded as the final delivery. Build final1.7.6 after successful current-head CI.

## Verified delivery checkpoint — 2 October 2026, 19:15 Melbourne

This checkpoint supersedes the preparation-only statements above. Both final PRs passed matching-head full CI and merged; immutable v1.7.6 tags use their tested source heads. Words PR30/head b4ea583351c6393c9c0cc8f7b5b71fcf53cdb098/run36984883890; Sword PR28/head c4731257a049365490ba8adc79b357758857acb7/run36984957180. All Sword five-platform release builds succeeded; Words iOS, Android, Linux and Windows succeeded and Mac is still running at this checkpoint. Source tags were not moved.

Both Microsoft submission5 updates published1.7.3. The validated1.7.6.0 x64 packages were submitted as submission6 with English, Simplified and Traditional Chinese release notes and approved listing assets preserved. Words submission1152921505702026942; Sword1152921505702027491. Both visibly In certification/Pre-processing, automatic publication after approval. Do not cancel or duplicate.

Signed iOS and universal Mac1.7.6/1070006 archives and exports succeeded for both apps. Words iOS includes Watch1.7.6 and CarPlay Audio=true. The exported iOS distribution entitlements have get-task-allow=false. Mac installer signatures and arm64+x86_64 were verified. Transporter uploads are in progress, not yet claimed delivered or processed. Existing initial public and earlier beta reviews remain preserved.

Latest source and package evidence is under /Users/pliu0036/Downloads/Yahweh-Companion-175. Final cleanup remains queued while uploads/builds are active; preserve all signed archives, dSYMs, source, certificates, packages and existing T7 APFS images. User explicitly excluded yahwehdehua from this work; do not change or troubleshoot that repository.

Words phone internal release5 now serves1.7.6/1007006 and Wear internal release5 serves1.7.6/20001013. Both visibly Available to internal testers, three note languages preserved. Proof google-words-internal-176-published.jpg and google-wear-176-published.jpg. Alpha review/public qualification has not yet been rechecked; internal distribution is not production. Physical CarPlay/audio/watch pairing remains unverified.


## Verified follow-up — 2 October 2026, 20:09 Melbourne

Supersedes the 19:15 build/upload checkpoint. Both five-platform GitHub workflow sets succeeded at the immutable v1.7.6 source; Words seven release assets and Sword six are public. Three Android APK signatures and downloaded asset digests were verified. All eight websites serve 1.7.6; the Sword web changelog was restored to the exact tagged 32-entry history without source or tag mutation. Evidence: github-apks-176-verified.json and web-sites-1.7.6-verification.json in Yahweh-Companion-175.

Google Words phone internal1.7.6/1007006, Wear internal1.7.6/20001013 and Sword phone internal1.7.6/2000012 are Available to internal testers. Words Alpha1.7.6 is saved unsubmitted while1.7.3 review remains pending; do not cancel/restart it. Sword Alpha1.7.6 was sent for review. All three release-note languages retained. Microsoft submission6 for both apps remains submitted for automatic publication after certification; never duplicate.

Apple Words iOS, Sword iOS and Sword Mac1.7.6/1070006 are delivered and processed, assigned to the existing internal groups and submitted to the existing Public beta group with automatic notification. Sword Mac now exposes Remove from Review; Transporter states Waiting for Review. Words Mac delivery failed20:00 due host No space left on device, including local log/database persistence errors. A normal Transporter restart and package reimport are in progress; do not claim it delivered or processed yet. Preserve pending initial public reviews.

Urgent storage recovery: additional unused Flutter test caches removed with lsof guard (storage-upload-recovery-176-tests.json);12 already-compressed retained1.7.1–1.7.3 cache-symbol archives (2,153,982,501bytes) copied to /Volumes/T7/Yahweh-Release-Backups-20261002/Retained-Older-Cache-Symbols, each size/SHA256 verified before local duplicate removal. Inventory storage-symbol-archives-transfer-176.json. All symbols remain archived, latest signed installable packages, archives, source/signing and T7 images preserved. Host free space rose to3,299,414,016bytes before resumed upload. Final cleanup is not complete.

Owner requests Watch auto-open with phone. Apple documents audio-triggered automatic Watch launch via WKApplicationDelegate.handleRemoteNowPlayingActivity; mere phone App opening cannot guarantee Watch foreground. Current1.7.6 has foreground snapshot refresh but no explicit new remote-Now-Playing app delegate implemented yet. Keep tags immutable; implement any further feature in a separate source change. Physical vehicle/watch, audible call recovery and real Play update installation remain unverified. Sword has no Watch/car/audio capability.


### 20:09 Transporter recovery confirmed
Words Mac1.7.6/1070006 is now DELIVERED2October20:09 and Processing. All four Apple latest packages are delivered; do not re-upload. Evidence apple-all-four-176-delivered.jpg. Words Mac server processing/compliance/group assignment/external submission remains next step. Initial public reviews remain preserved.
