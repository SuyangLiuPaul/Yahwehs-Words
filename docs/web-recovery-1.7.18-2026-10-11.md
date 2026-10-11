# Website-only 1.7.18 recovery follow-up

Owner authorized dev then production website delivery on October 11. Native packages and immutable v1.7.17 tags remain separate; no native/store build is started by this batch.

Includes merged UI/runtime-number/share repairs (PR72) and offline recovery (PR73), based on tested main f3a5ca03. Additional browser QA found an unlabeled single-song remove icon; it now has three localized labels, an explicit confirmation, and a retained-download error message. Six confirmation tests pass (confirm/cancel in English, Simplified and Traditional Chinese).

Actual browser checks: localhost8778 server was stopped, listener absence confirmed, latest page closed/reopened, saved song listed, and actual playback elapsed advanced 0:00 to0:14 of3:20. This tests origin unavailable, not entire-device network isolation or audible physical-device playback. Injected Cache.delete rejection in song-media-v1 retained the old3MB recording. First injection attempt used the wrong cache-name filter and did not inject; it is not counted as a failure-path pass.

Canonical release_web --bump produced the initial1.7.18 dev/QAT bundles before this extra confirmation fix. Those initial bundles are not final production candidates. Final correct-head CI, refreshed dev UI, update retention, photo/narrow PNG export, live hashes and production deploy evidence must be appended before claiming delivery.

Store1.7.17, physical iPhone/Android/Windows/watch/car and full device offline checks remain separately scoped. Source merge is not deployment proof.

## Verified website delivery — October11

PR74 exact head da50002b31554604f0e309bdb347c165cea75f14 passed complete CI38115955514. Merged main66c3e85344655aa324e74ee261975c40b7d847ef has the same source tree. Canonical `tools/release_web.sh --no-bump --include-prod` completed all six international/China dev, QAT and production sites at1.7.18. Full SHA256 of seven deployed resources per site matches the captured local build; source status contained only the retained untracked build symlink. Evidence: web-sites-1.7.18-full-verification.json and web18-deploy-build-manifests under /Users/pliu0036/Downloads/Yahweh-Store-API-20261011.

Actual local compiled1.7.17→1.7.18 cache upgrade retained one saved song/3MB. Separately, the real dev website was seeded before the final runtime redeployment; cold reload retained that song and playback advanced0:00→0:25 before Pause. Production cold startup showed1.7.18; Hebrews7:27 selected the correct verse actions. A single-song production download completed1/3MB, Remove download opened its named confirmation, Cancel kept the file, and playback advanced0:00→0:16 before Pause.

Browser Cache.delete and Cache.put quota rejection were injected through a visible local QA control only; both retained the older saved song. No actual device storage was filled. The production enqueue API skips an unchanged ready recording, so ready-record replacement rejection was not exercised through a browser UI; existing rollback tests remain separate evidence. Origin-unavailable cold playback does not mean whole-device network isolation. AI request smoke stopped at the own-key gate; no Gemini request or key was sent.

Real dev390×844 cold share preview fits; exported Chinese PNG includes body/reference/version/licence. Public image-fixture selection and PNG export passed. A viewport resize without cold reload initially left an old-sized frame and is excluded from the responsive pass. Physical iPhone/Android/Windows, audible output, watch/car and complete network isolation remain unverified. This batch does not update native/store1.7.17 packages or immutable tags.
