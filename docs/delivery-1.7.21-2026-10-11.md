# Words 1.7.21 — web and APK delivery

Owner authorized latest source, dev/prod websites and APK delivery on October 11. Prepared from latest main plus the local Chinese Genesis display correction. This release does not replace, cancel or re-upload the submitted 1.7.17 store packages.

## Included

- Improve offline song download status, pause, retry and recovery
- Inspect saved browser audio and retain first failure diagnostics
- Refine reading, Settings and search layouts across screen sizes
- Correct the Chinese Genesis book display name

## Delivery gates

- Source PR [79](https://github.com/SuyangLiuPaul/Yahwehs-Words/pull/79) merged. Matching-head CI 38139153575 and merged-main CI 38139863714 succeeded (4186 passed / 40 skipped).
- Canonical web deployment complete; all 6 sites serve 1.7.21. Each of seven live resources matches its captured build bytes and SHA-256.
- Signed direct Android APK 1.7.21 published; embedded version, certificate and GitHub digest verified. Phone versionCode 10070211.
- Existing store reviews and Google production qualification remain separate.

## Verification limits

Previously checked source/CI and browser recovery do not prove the original owner's lost-audio failure cause, the full 575-song physical iPhone batch, or audible vehicle/watch behavior. Preserve existing audio, download records, signing and archives. Chinese Genesis aliases remain accepted; scripture text is unchanged.

## Genesis compatibility repair

Initial release CI caught obsolete display expectations and a real daily-verse lookup regression: frozen bundle keys retain the old Genesis spelling. Book comparisons now use canonical identity in reference jumps, daily verses and reading/search previews, preserving bundled text and saved keys. Traditional testament grouping accepts the corrected spelling and retains old aliases.

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
