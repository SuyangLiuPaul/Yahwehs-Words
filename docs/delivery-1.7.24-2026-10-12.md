# Words 1.7.24 — paired Genesis display correction

## Source correction

- Corrected the localized display name for Genesis across reading, search, study, saved references, export/share, projection, feedback, and Watch snapshot labels. Traditional and Simplified Chinese now use the formal localized name.
- Kept legacy corpus names, saved IDs, lookup aliases, and Scripture text unchanged. Regression tests cover display labels and persisted identities.
- Merged source PR [#89](https://github.com/SuyangLiuPaul/Yahwehs-Words/pull/89) at `7153394a`; exact source CI run `38217744313` passed, including the full Flutter test job and companion-native checks.
- The same PR fixes the Play release-note loader to accept the repository's three-locale map as well as API-style records, with required-language validation and regression tests. Guard tests passed locally (22).

## 1.7.24 preparation

- Paired release branch is being prepared from merged main. Visible version target: **1.7.24**; Apple build target **1070024**. Play phone/Wear codes remain workflow-allocated and must be validated against the current Play API before upload.
- Localized Play and Microsoft release notes are prepared in `store-notes-1.7.24.json` and `microsoft-store-release-notes-1.7.24.json`.
- **No 1.7.24 tag, package build, website deployment, or store upload is claimed yet.** Before each upload, read current store state and preserve active reviews/drafts. Upload, processing, review, and public availability are separate states.

## Verification limits

- Static analysis and the paired display, saved-reference, projection and Watch-label regression suites passed in the source PR. Store package validation and live screens for the 1.7.24 build remain pending.
- Genesis data keys and original Scripture content are intentionally unchanged.

## 2026-10-13 00:00 Melbourne delivery checkpoint (supersedes the earlier pending-package note)

- The immutable `v1.7.24` source and web deployments were not changed. The existing GitHub `v1.7.24` release assets include current APK, Windows installer/ZIP, macOS ZIP, Linux archive, and unsigned iOS CI artifacts; these are direct downloads, not store packages.
- Apple App Store Connect accepted and processed all four 1.7.24/1070024 builds as `VALID`; both Mac builds declare minimum macOS 12. Builds: Words iOS `12f45098-8c68-4903-b1a6-5972185c7385`, Mac `f2a5a538-d498-4bb5-a0a3-9545c54ee84f`; Sword iOS `d232c63c-da34-4c85-b4c8-d45688031d94`, Mac `43fa553d-fa79-4273-953e-ce629d9e40a5`. Package SHA-256: iOS Words `692b91a7dcf281b4b7d52c9c0a8f20a221c5516af371bb81919d3c04dd59c82c`, Sword `a266328b8f6d109e88fb1be3907efe6858ce593e43bb5710a7073b81fd9bcb86`; Mac Words `5fbab7698989e89811c7c609415d09ab268c69d014edb3556b001e8d2159dc77`, Sword `dc4489ed63a740f70c22b2bae4aaea95092195ee446cf8ce5a1c87f885d1aefb`. Full API evidence: `/Users/pliu0036/Downloads/Yahweh-Store-API-20261011/apple-1724-processing.json`. This confirms processed builds only; no 1.7.24 App Store version has been newly submitted. Older pending initial/public reviews remain intact.
- Google Play Words run `38231180100` used exact runtime tag content plus the merged upload guard (`717b06b83d5efcffab4c073ac53f7ffb1da77682`); signed phone AAB `20003066` SHA-256 `b693fa01ebb5ab4738464fdaccf79ee2ae792a18effda3df440de4f74899783c` and Wear AAB `20003067` SHA-256 `8a428ba5117c42caa687652d32d468882304848f23404e9b593a41e195a0afaa` were uploaded separately to `internal` and `wear:internal`, both `completed`. Read-only API run `38251898630` confirmed both tracks and codes. Sword run `38224359377`, source SHA `fc2901cb807cb0c80ae35b707f6986dccca32a0c`, uploaded phone code `2000027`, SHA-256 `5eee463b1642f10ab17570828fac95c0521b4c6700d5edf7946538b72824a065`, to `internal` as `completed`; read-only run `38251903748` confirmed it. These are internal-test availability, not public production. Production remains empty and the real tester qualification gate remains separate.
- Microsoft Words exact MSIX SHA-256 `983b09408f911af27dcfd51822c7afd2559d4bd061b559f870b9d7e7a6f96477`, version `1.7.24.0` x64, was staged/read back from existing draft `1152921505702102644`; guarded workflow `38230687428` returned `CommitStarted` with Immediate publication and verified `en-us`, `zh-hans`, `zh-hant` release notes. A subsequent read-only check found no pending draft; certification/publication is not independently confirmed here.
- Microsoft Sword exact MSIX SHA-256 `a142b871f746ca6d1429843edeffd33b37182e38bf152afc808bdf298702f0a7`, version `1.7.24.0` x64, was built from MSIX run `38226914550`. Existing draft `1152921505702101034` still reads `PendingCommit` with its uploaded 1.7.22 package. First guarded staging attempt `38251852939` returned HTTP 409 on draft update and did not upload or commit anything. PR #74 added the staging/commit guards; follow-up PR #75 changes the 1.7.24 filename to avoid colliding with the prior package. At this checkpoint PR #75 CI is still running; do not claim Sword's 1.7.24 MSIX staged or submitted until its exact SHA is read back from Microsoft storage.

External status limits: Play is internal-only; App Store review/publication remains pending; Microsoft certification and Store publication must be checked after `CommitStarted`. No pending Apple review was canceled, no duplicate submission was created, and the immutable release packages were not rebuilt.
