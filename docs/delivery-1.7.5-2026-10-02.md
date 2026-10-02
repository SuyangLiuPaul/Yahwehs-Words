# Paired 1.7.5 release preparation — 2 October 2026

Both apps use visible version **1.7.5**. Build/version codes remain specific to each
platform and increase from its last accepted delivery. Existing tags and pending
store reviews remain unchanged. This record is preparation, not store publication.

## Update prompts

- Google Play: official flexible in-app update API, current installed package,
  account and track eligibility; download progress and explicit restart; no APK fallback.
- iOS / Mac App Store: public Apple lookup for this app, platform and locale country;
  only a newer public version produces a prompt, with a corresponding store link.
- Microsoft Store: asynchronous StoreContext package-update query, with store link.
  No GitHub installer in a Store package. Windows compilation is an open gate until
  the Windows runner completes; Mac cannot compile this native Windows integration.
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
warnings remain. Wear Activity compiled against Android 36 and official wearable
libraries before final control-disabling adjustment; repeat compile required.
Physical vehicle, phone-call recovery, Watch/Wear linkage and real Play older-to-newer
update installation remain required verification gates. Do not describe them as
verified or use disconnected screenshots as marketing.
