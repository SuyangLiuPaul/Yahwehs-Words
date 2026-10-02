# Words1.7.4 delivery — October2,2026

## Scope

Current-song recording selection, silent paused loading, Watch/Wear readability and state delivery, and idempotent car catalogue resume. [Repair and verification](audio-mix-and-companion-repair-2026-10-02.md). Sword has no song/watch/car capability and retains1.7.3.

## Release state

The canonical web wrapper bumped Words to1.7.4 for the owner-authorized production release. Publication/build processing is recorded below as it completes; preparation is not store delivery. Initial Apple public review and Microsoft1.7.3 submission5 must be preserved. When a new public update becomes editable, choose the latest accepted build rather than replacing a pending review.

- Source repair PR26 merged; exact-head Flutter CI36943978155 passed.
- Web: all six international/China dev, QAT and production sites serve1.7.4; full main.dart.js hashes verified. Evidence: `web-sites-1.7.4-verification.json` in the repair evidence folder.
- Immutable GitHub tag `v1.7.4` is `df5ed7beeb6a19892fb859c8399cd921b2c96b82`; version PR27 exact-head CI36945351325 passed and merged. Android, Wear APK, iOS unsigned IPA, Linux, Windows ZIP and EXE release workflows succeeded; macOS download workflow36946636879 also succeeded; all five desktop/phone release workflows are successful.
- Google phone internal release4 published October2 at10:57 Melbourne:1.7.4/1007004, Available to internal testers. Existing tester access and all three note languages preserved. Wear internal release4 published at10:58:1.7.4/20001012, Available to internal testers. Alpha1.7.4/1007004 is saved and validated; sending now would cancel/restart the existing1.7.3 review, so it is queued for submission after that review completes. Neither internal track means public production qualification.
- Apple iOS archive and store export1.7.4/1070004 succeeded, including Watch1.7.4/1070004. Exported store profile has CarPlay Audio entitlement and get-task-allow=false. Apple browser login is restored. The native Transporter window recovered; both iOS and universal Mac1.7.4/1070004 packages were successfully delivered (iOS11:12, Mac11:10 Melbourne). Mac archive/export and installer signature verification succeeded (arm64+x86_64, macOS11.0 minimum). Owner DELIVER handoff is obsolete. Both signed Apple1.7.4/1070004 builds are processed with standard-encryption compliance saved, preserving France as the sole unavailable country. The existing internal Words group visibly lists both iOS and macOS as Testing. Mac1.7.4 was submitted to the existing Public beta group and is Waiting for Review with automatic tester notification. iOS1.7.4 external submission hit Apple’s two-build daily Beta App Review limit; retry after reset with the saved current notes, without re-uploading or cancelling any review. Words Mac1.7.3 external beta is now Approved.
- Microsoft1.7.4.0/x64 MSIX built successfully by36946640354; identity, publisher, ZIP integrity and SHA-256 verified. Both apps submission5 remain1.7.3 In certification. Latest Words package is queued under [immutable guards and localized notes](microsoft-followup-1.7.4.md); preserve pending certification.

## Retention

Builds/archives are being written to the dedicated APFS image /Volumes/T7/Yahweh-Release-Backups-20261002/YahwehMedia174Builds.sparseimage, mounted at /Volumes/YahwehMedia174Builds. Preserve signed archives,dSYMs,latest packages,source and previous release backups. Simulator QA candidate was source6c7caa55,display version1.7.3/build1070004; it is not a released1.7.4 binary.

## Evidence and open checks

Evidence folder: `/Users/pliu0036/Downloads/Yahweh-Media-Repair-20261002`. Package manifest and hashes: `packages-1.7.4-verification.json`; exported iOS metadata: `ios-store-1.7.4-verification.json`; Google phone publication: `google-phone-internal-1.7.4-published.jpg`. Android phone1007004 and Wear20001012 are separate artifacts. The phone AAB upload certificate matches the recorded1.7.3 certificate.

Phone simulator proved unavailable Ask backing/instrumental buttons are disabled with the574-song queue intact. Watch pure state ordering/publication and SDK type checks passed, but paired simulator UI was temporarily restored: bright artwork/title/album and controls were visible, and Watch Pause changed the phone to paused at1:38/3:03. The window menu failed again during phone-next/Watch verification; current paired next/seek capture remains incomplete. Physical watch/vehicle behavior and CarPlay simulator system progress remain unverified. Never present these gaps as verified marketing.

## Apple beta processing checkpoint

Proof: `apple-beta-1.7.4-delivery.json`, `apple-internal-1.7.4-testing.jpg`, `apple-mac-1.7.4-external-submitted.jpg`, and `apple-ios-1.7.4-beta-daily-limit.jpg`. Prepared localized test notes are in `apple-test-notes-1.7.4.json`. Documentation PR28 passed matching-head CI36950009973 at08fa6cdb46fc8a0badf8186c6d03ecfdab0d780d and merged as85fbf9d1980b1e8d8160f22b7f60b4f8406b2378. Runtime code and immutable tags were not changed. Latest public review, Microsoft certification and Google production qualification remain separate gates.
