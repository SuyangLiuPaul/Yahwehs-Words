# Paired 1.7.11 release — 6 October 2026

Owner explicitly authorized all-platform publication on October6. Publish Words then Sword, sequentially. The latest October6 handoff remains authoritative except its release/push prohibition is waived for this requested cycle only. Keep existing Bible text frozen and all old tags/reviews intact.

## Included source

Words: admin overlays, announcement/version registry/manual checks, feedback/anonymous counters, latest Home/study content, Watch/Wear list and CarPlay redesign, readable media page names and instrumental-only counts. Android Auto root now has four browsable tabs (Hymns, Instrumental, Sermons, Library); existing queue/playlists remain accessible beneath Library. Official content-style hints request entry grids and readable child lists, with source artwork retained. Sword: latest admin sermon/link overlays, update registry, menu/study layout and existing content changes. Sword has no Watch/car/audio capability.

## Verification and limits

Words prior full suite4051passed/36skipped. New Android Auto catalogue checks7passed. Final-source remote CI, all signed native packages and web readback still required. Official DHU2.0-mac-arm64 is installed; adb currently reports no attached device. Owner has a Mi Pad, no Android phone. Tablet Android Auto support is not established; no genuine DHU screen or physical audible route verification claimed. Do not fabricate Android Auto screenshots or use Wear debug preview as Android Auto evidence. Existing real simulator Watch/CarPlay screenshots are under docs/screenshots/2026-10-06/car-watch-redesign.

## Delivery state

Preparation only: visible version1.7.11, no new tag or package uploaded at this checkpoint. Create immutable source tags only after current-head CI succeeds; signed Apple packages must include matching Watch and approved CarPlay profile for Words. Validate Play phone/Wear monotonic codes independently and preserve package/signing identity. Check current console versions before creating submissions; never cancel pending review or re-upload the same accepted build. Production Google tester qualification remains separate.

## Open checks

Admin portal live-data end-to-end announcement/overlay/feedback behavior still needs verification with temporary records restored. Physical Watch/CarPlay and Android Auto playback/route/call recovery remain open. Store uploads, Google internal/closed tracks, Apple processing/TestFlight/public updates, Microsoft submission, GitHub releases and eight web sites must each have separate verified status.

## October6 18:25 Melbourne verified checkpoint

Final source `584015fc4ec3a684de87047a24e63a6195e64bd2` passed CI37424735711; local suite4054passed/36skipped. PR42 merged; immutable v1.7.11 and public GitHub release now have all seven assets, with all five matching-tag native workflows successful. Both APK signatures and GitHub SHA256 digests match.

Google phone internal track4701597346876713171 release10 now serves1.7.11/10070111, visibly Available to internal testers. Wear internal track4699659407499218860 release10 serves1.7.11/20001019 with the same visible availability. All three release-note languages preserved. These internal tracks do not establish production qualification. Existing Alpha1.7.3 review remains preserved.

Signed iOS1.7.11/1070011 includes matching Watch, with distribution get-task-allow=false and CarPlay Audio=true. Transporter delivered at18:07; processed iOS buildcf1826e5-2a2a-4475-96a0-b2bae39d81ed is submitted to the existing Public beta group with automatic notification, Waiting for Review. Public iOS1.7.11 was separately submitted with that exact build and automatic release, now Waiting for Review; submissionf8e84277-2785-4766-a56e-8141f8f85d37. Previous public Mac1.6.34 In Review remains intact.

Universal signed Mac1.7.11/1070011 archive/export verified; package SHA256e238b72e03e2d9c6e8056d1daedba288edd8b2f33133447cd4da0e8f09099e08. Transporter upload is active, not yet delivered. Microsoft new Submission11 id1152921505702052468 has the verified1.7.11.0 x64 package uploading; do not duplicate. Six-site canonical web release is active: international sites verified1.7.11; China uploads pending.

Actual source collects anonymous daily launches/top-level page totals and copies optional feedback into the admin inbox. Apple Words privacy categories were corrected for optional account/cloud data, support, coarse country/region, interactions and diagnostics; no tracking. The central Words/Sword privacy HTML still needs its prepared policy-only update after the active web wrapper completes. Prepared copies and all proofs are under `/Users/pliu0036/Downloads/Yahweh-Release-1711`.

Admin Words registry was saved and reloaded: GitHub APK/Mac/Windows/Linux1.7.11, existing actual AppStore/Watch1.7.10, Microsoft1.7.10, Wear1.7.11 internal-test link. Pending public store1.7.11 is not falsely registered as available. Web registry awaits completed live verification. No minimum-version enforcement added.

Physical Watch/Wear/vehicle audible playback and Android Auto remain unverified. Owner has only Mi Pad; no compatible connected phone/DHU rendering has been established. Preserve source tags, signing, installables, archives/dSYMs, T7 images and pending reviews.

## October6 actual Android media-session defect and forward repair

Words Microsoft Submission11 now contains validated1.7.11.0 with all three current release notes and automatic publication; it is submitted and visibly In certification / Pre-processing. Alpha1.7.11 is saved unsubmitted while the existing Alpha1.7.3 review remains unchanged.

A real release-APK run on the dedicated existing Android capture emulator exposed `IllegalArgumentException: You must specify an icon resource id to build a CustomAction`. The installed1.7.11 release resource table omits `ic_shuffle`, `ic_repeat` and `ic_repeat_one`, despite those vectors existing in source. The system media session stayed NONE/inactive while the in-app timer advanced; no notification/Auto background-playback success is claimed. Add an Android resource keep file for these runtime-resolved icons and verify the repaired RELEASE APK resource table, live system state and genuine background media controls before publishing a forward fix. Never mutate v1.7.11 or rebuild different runtime code under it. Sword publication is held for a consolidated paired forward version after this check; previously submitted Words reviews remain preserved. A foreground-service declaration requires a real playback video link; no invented demonstration has been submitted.
