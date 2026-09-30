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

CarPlay is awaiting Apple’s approval; see permissions/carplay-request.md.
It must not be enabled by adding a guessed entitlement to an ordinary
signing profile. Default iOS builds exclude restricted CarPlay source.

## Current status — 2026-09-30

Android phone and Wear OS debug APKs built successfully. The containing iPhone simulator build, including the embedded Apple Watch app, also built successfully after correcting the embed-phase order. Both apps launched in paired iOS 26.5 / watchOS 26.5 simulators. New native artifacts still require signed release builds and store delivery. Physical car/watch playback remains unverified. CarPlay request was received by Apple; entitlement approval is pending.

## Delivery evidence

Build results and device/preview inspection are recorded in HANDOFF.md.
Source implementation and a successful build are not evidence of a Play
or App Store release, approval, or successful physical vehicle/watch use.
