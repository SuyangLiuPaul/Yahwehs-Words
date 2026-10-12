# Words 1.7.21 — web and APK delivery

Owner authorized latest source, dev/prod websites and APK delivery on October 11. Prepared from latest main plus Chinese Genesis display-name changes in locale-aware views; some legacy-key-driven UI still shows the old spelling. This release does not replace, cancel or re-upload the submitted 1.7.17 store packages.

## Included

- Improve offline song download status, pause, retry and recovery
- Inspect saved browser audio and retain first failure diagnostics
- Refine reading, Settings and search layouts across screen sizes
- Correct the Chinese Genesis spelling in locale-aware labels

## Delivery gates

- Source PR [79](https://github.com/SuyangLiuPaul/Yahwehs-Words/pull/79) merged. Matching-head CI 38139153575 and merged-main CI 38139863714 succeeded (4186 passed / 40 skipped).
- Canonical web deployment complete; all 6 sites serve 1.7.21. Each of seven live resources matches its captured build bytes and SHA-256.
- Signed direct Android APK 1.7.21 published; embedded version, certificate and GitHub digest verified. Phone versionCode 10070211.
- Existing store reviews and Google production qualification remain separate.

## Verification limits

Previously checked source/CI and browser recovery do not prove the original owner's lost-audio failure cause, the full 575-song physical iPhone batch, or audible vehicle/watch behavior. Preserve existing audio, download records, signing and archives. Chinese Genesis aliases remain accepted; scripture text is unchanged. This is not a UI-wide rename: the 1.7.21 `translateBookName` compatibility function maps displayed `创世记` back to the frozen key `创世纪`, and some headers/selectors show that legacy spelling. The owner reports seeing it in both the Microsoft Store 1.7.21 install and the web version, confirming this is shared display logic rather than a Store-only packaging issue. Do not describe the correction as complete across all screens.

## Genesis compatibility repair

Initial release CI caught obsolete display expectations and a real daily-verse lookup regression: frozen bundle keys retain the old Genesis spelling. Book comparisons now use canonical identity in reference jumps, daily verses and reading/search previews, preserving bundled text and saved keys. Traditional testament grouping accepts the corrected spelling and retains old aliases. However, 1.7.21 did not separate display strings from lookup keys everywhere: `translateBookName` deliberately returns `创世纪` for compatibility, and some UI still renders that value. Uniformly showing `创世记` requires a later source change and screen verification in both apps; the immutable 1.7.21 store packages cannot be changed in place.

## Final website / APK checkpoint

- Immutable v1.7.21 source: `80d9bc1ed2a63f29437de03e9d5a06405e216159`. Merged source main: `75e4c46e4c19833f724cff0fecefba9291e5056e`. Tested tag and merge have identical trees.
- Public downloads: https://github.com/SuyangLiuPaul/Yahwehs-Words/releases/tag/v1.7.21
- Phone release certificate SHA-256: `a5f480f38ed323956e9cc6f2c8d7d9c84d300fbdef92bf7600178fbe8c7948ab`.
- Live websites: https://yswords-dev.netlify.app, https://yswords-qat.netlify.app, https://yahwehword.com, https://yswords-cn-dev.netlify.app, https://yswords-cn-qat.netlify.app, https://yswords-cn.netlify.app.
- Full live proof: `/Users/pliu0036/Downloads/Yahweh-Store-API-20261011/web-sites-1.7.21-paired-full-verification.json` (checked 2026-10-11T12:58:51.301833+00:00). All eight paired sites / 56 resource checks passed.
- APK proof: `/Users/pliu0036/Downloads/Yahweh-Store-API-20261011/github-apks-1721-Words-verification.json`; retained packages in `apk-1.7.21/` beside it.
- Browser checks: Settings Basic / Advanced expanded and collapsed; actual prod version 1.7.21. Words mobile fresh-load layout also checked. Screenshots retained beside the proof files.
- These are website and GitHub direct-download deliveries. Existing Apple, Google Play and Microsoft Store 1.7.17 submissions were not changed by this task. Store monitoring remains separate.
- Wear APK also verified: versionCode 21070021, same release certificate.
- Words CN Netlify uploads encountered server-side 500 errors. Sequential reuse of the same built artifact recovered delivery; QAT CLI ended with an error but its actual deployment was ready and all live hashes matched. Logs preserve this distinction.

## Apple API upload checkpoint — 2026-10-12

- Uploaded Words iOS and macOS 1.7.21 / build 1070021 to App Store Connect with the existing API key and Xcode cloud-managed Apple Distribution signing. iOS build is `VALID`; macOS upload returned success and is awaiting its build record/processing confirmation.
- macOS package is universal arm64 + x86_64 and has minimum macOS 12.0, as previously authorized. The isolated Flutter 3.44.2 SDK worktree needed a local Xcode 27 `lipo -verify_arch` compatibility patch; application source and installed SDK were not changed.
- Delivery UUIDs and package SHA-256 values: `/Users/pliu0036/Downloads/Yahweh-Store-API-20261011/apple-1.7.21-upload-proof.json`.
- Upload/validation logs and signed packages are retained under `/Volumes/YahwehRelease1713/Store-1.7.21/Apple/`. No new App Store review was submitted; pending 1.7.17 reviews remain untouched.
- Repeatable steps and existing credential locations (no key material): `/Users/pliu0036/Downloads/Yahweh-Store-API-20261011/apple-api-upload-playbook.md`.

## Store API readiness checkpoint — 2026-10-12

- Read-only Play API preflight 38184028167 succeeded: credentials verified; internal/alpha tracks still contain completed 1.7.17 code 10070171; no 1.7.21 upload. Retained 1.7.21 phone AAB is code 10070211 and is eligible numerically. Upload was held because the existing workflow would attach stale 1.7.17 release notes; prepare accurate localized 1.7.21 notes before creating a Play draft.
- Microsoft API preflight verified access and no pending draft before upload. Verified v1.7.21 MSIX was uploaded through the create-only API as draft 1152921505702099400 (source 80d9bc1ed2a63f29437de03e9d5a06405e216159; SHA-256 30813cefe639221208ebd621c337972748c3665f5d1982b5a245415c56a78364). Partner Center read-back is PendingCommit / package PendingUpload. Certification was not submitted; publication is not claimed. Run 38184158639.
- Backup before this checkpoint: `/Users/pliu0036/Downloads/Yahweh-Store-API-20261011/store-api-1721-checkpoint-20261012-102654/`.


## Google Play / Microsoft Store checkpoint — 2026-10-12 11:51 Melbourne

- Microsoft Words submission `1152921505702099400` was committed via the guarded API workflow `38188399035`. Exact staged package remains 1.7.21.0 x64, SHA-256 `30813cefe639221208ebd621c337972748c3665f5d1982b5a245415c56a78364`; release-note locales `en-us`, `zh-hans`, `zh-hant` verified; API returned `CommitStarted`, automatic publication enabled. This is submitted/processing, not a claim of public publication.
- Words Play 1.7.21 upload is held to preserve the existing review. Paul95 Play Console visibly shows app update status `In review`, with 12 testers opted in for 7 continuous days of the required 14 and Production access disabled. Do not cancel the review. Google Play `ERROR_IF_IN_REVIEW` is retained as a guard.
- Fixed the shared phone/Wear package version-code allocation and paired AAB upload in PR [82](https://github.com/SuyangLiuPaul/Yahwehs-Words/pull/82), merged as `63bf5ed652b4c4f3f01cf85f9424de42eef9b664`. Exact-head CI `38188711297` and matching main CI `38189295003` passed. The next internal release can upload both AABs with distinct increasing codes once the active review permits an edit.
- Store API preflight `38188508816` did not reach read-only store checks: the repository's legacy guard test expects a literal draft-only parameter that the current guarded uploader no longer uses. No Play/Microsoft mutation occurred in that preflight.
- File-level backup before this checkpoint: `/Users/pliu0036/Downloads/Yahweh-Store-API-20261011/store-api-1721-final-checkpoint-20261012-115100/delivery-words-1.7.21.md`.
