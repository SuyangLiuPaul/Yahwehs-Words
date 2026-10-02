# Next companion release — 2 October 2026

Owner requested one consolidated next release for iPhone/Apple Watch/CarPlay and Android/Wear OS/Android Auto. Changes below are preparation, not delivered binaries. Keep v1.7.6 and existing reviews immutable. Sword has no media/watch/car companion; synchronize the eventual app release version and channel reminders without claiming companion support in Sword.

## Added after 1.7.6

- Apple Watch uses WKApplicationDelegate.handleRemoteNowPlayingActivity and the SwiftUI delegate adaptor. An OS-provided audio launch opens the existing playback screen and requests a current phone snapshot. A cold-launch flag is consumed once; no audio autoplay or forced phone-only foreground launch. Respect watchOS/user launch settings.
- Watch and Wear labels distinguish paused from playing in English, Simplified and Traditional Chinese.
- iPhone sends a changed pause/seek/track snapshot immediately when an in-flight Watch transfer completes instead of waiting for the next publication timer.
- Wear ignores replies and async node/data callbacks belonging to a previous foreground generation. Reopening a catalogue reloads its current folder; canceled loading state cannot remain indefinitely. Data buffers are released even for abandoned reads.
- A failed Wear cover fetch can retry after a fresh publication. Daily verse changes are part of Android publication identity.

## Verification so far

Watch SDK arm64/watchOS9 simulator type-check succeeded. Wear Activity compiled against Android36 and official Google wearable/base/task libraries with Kotlin2.0 compiler (wear-next-compile.log, exit0). iPhone companion Swift syntax parse succeeded. These checks are not physical synchronization or end-to-end audio proof.

## Required before next consolidated publication

1. Exact-head full CI, complete signed iOS/Watch/Mac and phone/Wear/Windows builds; use one new immutable source version.
2. Paired phone/watch UI: original recording identity, cover/title/album, current elapsed position, Pause/Play, previous/next, sermon seek, queue, shuffle/repeat, cold/foreground/reconnect, late reply and empty/offline library.
3. CarPlay/Android Auto: shared phone media session, same queue and modes, correct native transport controls, call interruption/resume and audio route/focus loss. Confirm actual audible vehicle output and OS progress on hardware; never infer them from compiler success.
4. Current-song unsupported mixes remain disabled; no playlist replacement, position reset or unrequested autoplay.
5. Real Play-install update transaction, channel-specific update prompts, three languages and consistent app version. Never offer direct installer to a Store install.
6. Preserve existing reviews; stage the next accepted package only when the platform permits a new submission without canceling pending certification.

## Platform scope

The phone owns playback; companion devices control it and receive snapshots. Offline pages show saved state and prevent unsupported controls. Apple audio-triggered launch is supported by the OS; merely opening the phone app is not a guaranteed Watch launch. Android should follow supported media/session and companion flows rather than silently forcing background activities.

[Apple remote Now Playing activity](https://developer.apple.com/documentation/watchkit/wkapplicationdelegate/handleremotenowplayingactivity())
