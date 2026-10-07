# Paired 1.7.14 diagnosis and support release — 2026-10-07

Owner authorized robust cross-platform diagnosis IDs, admin report lookup, official About/CN store badges and a paired all-platform release. Both apps are prepared at visible 1.7.14; previous tags remain immutable. Preparation is not publication.

## Implemented support flow

Each app/browser installation keeps a cryptographically random resettable YD identifier. It is not an account ID or hardware fingerprint. Concurrent reads and resets are serialized, storage failure retains a session ID, and only the latest 20 allowlisted status codes are kept locally. IDs/statuses are transmitted only with an explicit feedback/report action. Settings provides copy, report and reset controls in English, Simplified and Traditional Chinese. Both Netlify feedback handlers sanitize diagnostic input, identify their app server-side, reject malformed JSON and messages over the existing 4000-character database limit, and retain admin-only report reads under existing rules. No security rules were changed or deployed.

The admin portal has its own local diagnosis ID and a report-derived lookup view. App plus ID forms a group; this is not live device inventory or background tracking. Search includes app version/channel and valid companion IDs. User text is escaped and missing/invalid old metadata is tolerated. Delete requests are handled through the existing admin feedback inbox; resetting an app ID does not delete old reports.

## Words-specific changes

Words includes the already locally committed current Settings/Home/recommended AI changes previously deployed on the eight-site paired web delivery. Apple Watch and Wear OS keep their own random local IDs and send them over the existing paired channel. Phone reports can include the latest known peer IDs. CarPlay uses the phone installation ID. Sword has no companion/audio/AI capability.

About and generated /cn use original official Apple, Google and Microsoft badges with recorded source URLs and SHA-256. Words iPhone links to its already public App Store listing; Sword's unavailable Apple public listing remains a labeled TestFlight link. Google Play links are labeled testing. Microsoft badges are retained on /cn because China is selected in both existing worldwide listings. Privacy Markdown sources and generated policies describe voluntary diagnostic sharing and reset/removal limits.

## Verification checkpoint

Words full Flutter suite before the release version stamp: 4066 passed, 36 skipped, no failures. The initial missing SelectableText scroll physics was fixed and the full suite rerun successfully. Sword full suite is still being checked. Both feedback handlers each passed eight mocked Node checks, including malformed JSON, privacy allowlists, app spoofing rejection, network failure and length validation. Portal helper checks passed four assertions; local browser preview verified two app groups, peer-ID lookup, no-match state and escaped script text. No real diagnostic report has yet been submitted through the deployed release endpoint. Watch snapshot native checks and Watch SDK typecheck passed; Wear Kotlin compile succeeded. Matching release-head CI and signed packages remain required.

## Delivery gates

No 1.7.14 tag, GitHub release, website deployment or store upload is claimed by this preparation record. Preserve Apple pending public/beta reviews, Words pending Google Alpha1.7.3 review and existing tester access. Words latest closed-track changes may be queued without restarting that pending review. Existing 1.7.13 store/installable/archive evidence remains authoritative until newer delivery is visibly accepted. Apps deploy sequentially Words then Sword. Stage only named files and preserve Sword owner's PBX override SHA256 06a794e396afda48e413fd5d82f4c9978985c7a012d0aef9af0ba9fadaf3ed04.

Physical Watch/Wear pairing, vehicle audible/call recovery and Android Auto remain unverified. Do not claim full physical synchronization or Google production access from source checks/beta distribution. Final cleanup waits for latest accepted uploads and idle builds; preserve all signed archives/dSYMs/packages/signing and T7 images. Exclude yahwehdehua. The 10-hour automation remains paused.

Evidence directory: /Users/pliu0036/Downloads/Yahweh-Diagnosis-1714.
