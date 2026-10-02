## Current-song and live companion repair — October 2

[Repair scope and verification](audio-mix-and-companion-repair-2026-10-02.md): now-playing mix selection is per current song, transparent covers have a bright backing, visible Apple Watch uses live messages and foreground refresh, and both watch bridges detect seek discontinuities. Catalogue reselect resumes the same recording. New native packages and physical checks are still required; this is not a claim that existing1.7.3 binaries contain these changes.

## Latest companion checkpoint — 1.7.3, 2026-10-01

[Current platform delivery and gates](delivery-1.7.3-2026-10-01.md) supersedes the historical build numbers below. The signed iOS1070003 package includes the matching Watch app and granted CarPlay profile; Wear internal20001011 is published.

- [Apple Watch paired simulator gallery](screenshots/2026-10-01/apple-watch-1.7.3/README.md): current phone chapter refreshed from Matthew1 to Matthew2; actual song title/cover/progress arrived; Watch Pause stopped both at1:55 /4:26. Physical pairing remains separate.
- [CarPlay catalogue simulator gallery](screenshots/2026-10-01/carplay-1.7.3/README.md): root/categories, hymn and sermon libraries, song selection on the phone, and Browse audio return verified. Next track switched the phone song; native MPNowPlayingInfoCenter contained actual artwork, rate1 and elapsed49.974seconds. The system simulator Now Playing progress did not refresh after reconnection; that view is held from marketing and display/physical checks remain open. This does not establish a source defect.
- The Google Play capture emulator contains Android Auto's official stub; opening it requires Google Play account sign-in to install the full official app. Android Auto DHU and paired Wear captures remain blocked on that setup. Do not use unrecognized APK mirrors or fabricate state.

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
- Background phone↔watch context is throttled to 15 seconds; track/pause/seek changes publish immediately. Reachable Apple Watch receives live messages and requests fresh state on foreground entry. Neither companion collects health, location, microphone,
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

Android phone and Wear OS debug APKs built successfully. The containing iPhone simulator build, including the embedded Apple Watch app, also built successfully after correcting the embed-phase order. Both apps launched in paired iOS 26.5 / watchOS 26.5 simulators. New native artifacts still require signed release builds and store delivery. Physical car/watch playback remains unverified. Apple has granted CarPlay Audio; native activation, simulator validation and signed delivery 1060038 are complete, with Apple processing complete and internal Words TestFlight assignment completed; latest external build assignment blocked behind existing Beta App Review.

## Delivery evidence

Build results and device/preview inspection are recorded in HANDOFF.md.
Source implementation and a successful build are not evidence of a Play
or App Store release, approval, or successful physical vehicle/watch use.

## Store delivery update — 2026-10-01

Signed containing iOS build1.6.35/1060037, including its version-matched Watch app, and Mac build1.6.35/1060037 were processed by Apple and submitted for external TestFlight review. Internal Words testers are assigned. Phone Google Play 1006035 remains in review. Signed Wear OS AAB 20001005 (1.6.35) is available to the existing personal internal-test list at https://play.google.com/apps/internaltest/4699659407499218860; public Wear listing screenshots and opt-in review are still pending. Android Auto is in the new phone binary; it has not been verified in a physical car. The CarPlay capability and granted profile are verified, but1060037 predates activation.

## Granted CarPlay validation — 2026-10-01

The activated native target compiles successfully with Xcode, the actual granted entitlement and shared phone/dashboard engine. The simulator displays the Words icon, hymn/instrumental/sermon root, hymn sources, 60-item pages and native Now Playing metadata. Audio position advanced with a measured 4:03 duration. After a fresh simulator boot, Words launched solely from the CarPlay icon and rendered the root without opening the phone app. Logs show the host received the root at 07:42:50.706 and all three items at 07:42:52.390. A temporary blank host after forced termination did not establish a source defect; fresh-boot display and immediate sermon navigation were verified. This is not evidence of physical car verification.

Robustness review fixed download-index initialization before cold media browsing, published song errors, Flutter phone-scene lifecycle forwarding, non-nil template presentation completions, stale connection callbacks, bounded channel readiness/timeouts and retained-engine disconnect handling. Final local regression: **3,821 passed / 36 existing skips**, analysis clean; final native simulator build succeeds. Signed iOS 1.6.35 / 1060038 was delivered at 08:17 Melbourne on 1 October and finished Apple processing. The actual distribution profile and signed main binary grant CarPlay Audio; the embedded Watch version/build match. Build 1060037 remains in external beta review.


## Companion synchronization repair — 2026-10-01

The paired phone remains the playback owner: phone, car controls and watch commands operate its single audio session. The follow-up source repair publishes decoded hymn duration for the active item, replays Android preloaded handoff duration safely, and projects elapsed time on the watches between position transfers. Important title/subtitle/duration/loading/error/control changes transfer immediately; routine position transfers remain coalesced. Older snapshots are rejected; stale, loading and failed sessions disable playback commands until reconnection or refresh. Library request errors finish loading and allow Retry.

Sermon listening position is saved locally on the phone (five-second autosave and explicit pause/stop/seek saves). Existing resume behavior rewinds one minute for context. This does not synchronize a transcript to an audio word or paragraph, or establish resumable listening across independent phones.

Validation: 43 focused Flutter tests passed; Dart analysis clean; Apple Watch simulator target built; Swift snapshot/order checks and phone bridge typecheck passed; phone Android Kotlin and Wear Kotlin compiled. Expanded changes passed independent second review. They require rebuilt binary delivery before users of 1060038 receive them. Physical watch/car playback and Wear UI error recovery have not been exercised. New Watch Now Playing screenshots must be captured from the rebuilt app.
