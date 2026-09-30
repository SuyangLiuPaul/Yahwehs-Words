# Words audio companions

## Implemented source

- Android Auto media browser declaration, root with hymns, instrumental
  mixes and recorded sermons, grouped by source/series. Large hymn lists
  page at 60 items. Video-only songs are excluded. Voice text searches the
  audio catalogue without requesting a microphone permission.
- A single `audio_service` media session dispatches to songs or sermons.
  Sermon controls use the whole-talk timeline, +30/-15 seconds, saved resume
  positions and automatic tape-side progression. Song focus pauses the
  sermon and sermon focus pauses songs. Existing queue/mix/download URL
  resolution remains in place.
- Apple Watch native SwiftUI companion embedded in iPhone Runner: daily
  English/Chinese verse, now playing, audio browser and transport controls.
  Cached daily text remains available offline. Audio plays on the phone.
- Wear OS native `:wear` companion: same daily verse/audio browser/controls.
  Data Layer uses the same package ID and signing identity as the phone.
  Google Play ID is set via `ORG_GRADLE_PROJECT_playAppId`; GitHub packages
  retain the existing default ID. A watch cannot connect to a phone app
  signed with a different certificate.
- Phone↔watch metadata is throttled to 15 seconds; item/pause changes send
  immediately. Neither companion collects health, location, microphone,
  contacts or account credentials.

## Build and distribution

Apple Watch requires watchOS 9 or later. Build the containing iPhone app
with its paired device ID. Flutter refuses a simulator build with a Watch
companion unless `-d` selects an iPhone simulator. A real App Store upload
requires provisioning the watch ID `com.example.yswords.watchkitapp` under
the existing team, a signed archive, and watch screenshots in App Store
Connect. Ordinary watch functionality has no CarPlay entitlement gate.

Wear OS requires Android API 30 or later. Build with
`cd android && ./gradlew :wear:assembleDebug` or `:wear:bundleRelease`.
Release builds read the same `android/key.properties` as the phone;
release tasks fail if the signing key is absent. Debug builds are for local development only. Upload the signed watch AAB to the
Wear OS form-factor track and complete its listing/screenshot requirements.
The phone AAB must be updated too for the new bridge/media catalogue.

Android Auto becomes discoverable only in a newly installed phone package
with the new metadata and browser implementation. Google’s car app quality
review/distribution rules apply. Installing the old phone binary does not
add this feature.

CarPlay Audio was approved on 1 October; see permissions/carplay-request.md.
It must not be enabled by adding a guessed entitlement to an ordinary
signing profile. Activation checked the actual Apple-issued profile before enabling the CarPlay scene and compilation condition.

## Current status — 2026-09-30

Android phone and Wear OS debug APKs built successfully. The containing iPhone simulator build, including the embedded Apple Watch app, also built successfully after correcting the embed-phase order. Both apps launched in paired iOS 26.5 / watchOS 26.5 simulators. New native artifacts still require signed release builds and store delivery. Physical car/watch playback remains unverified. Apple has granted CarPlay Audio; native activation, simulator validation and signed delivery 1060038 are complete, with Apple processing complete and TestFlight group assignment awaiting re-login.

## Delivery evidence

Build results and device/preview inspection are recorded in HANDOFF.md.
Source implementation and a successful build are not evidence of a Play
or App Store release, approval, or successful physical vehicle/watch use.

## Store delivery update — 2026-10-01

Signed containing iOS build1.6.35/1060037, including its version-matched Watch app, and Mac build1.6.35/1060037 were processed by Apple and submitted for external TestFlight review. Internal Words testers are assigned. Phone Google Play 1006035 remains in review. Signed Wear OS AAB 20001005 (1.6.35) is available to the existing personal internal-test list at https://play.google.com/apps/internaltest/4699659407499218860; public Wear listing screenshots and opt-in review are still pending. Android Auto is in the new phone binary; it has not been verified in a physical car. The CarPlay capability and granted profile are verified, but1060037 predates activation.

## Granted CarPlay validation — 2026-10-01

The activated native target compiles successfully with Xcode, the actual granted entitlement and shared phone/dashboard engine. The simulator displays the Words icon, hymn/instrumental/sermon root, hymn sources, 60-item pages and native Now Playing metadata. Audio position advanced with a measured 4:03 duration. After a fresh simulator boot, Words launched solely from the CarPlay icon and rendered the root without opening the phone app. Logs show the host received the root at 07:42:50.706 and all three items at 07:42:52.390. A temporary blank host after forced termination did not establish a source defect; fresh-boot display and immediate sermon navigation were verified. This is not evidence of physical car verification.

Robustness review fixed download-index initialization before cold media browsing, published song errors, Flutter phone-scene lifecycle forwarding, non-nil template presentation completions, stale connection callbacks, bounded channel readiness/timeouts and retained-engine disconnect handling. Final local regression: **3,821 passed / 36 existing skips**, analysis clean; final native simulator build succeeds. Signed iOS 1.6.35 / 1060038 was delivered at 08:17 Melbourne on 1 October and finished Apple processing. The actual distribution profile and signed main binary grant CarPlay Audio; the embedded Watch version/build match. Build 1060037 remains in external beta review.
