# Website-only 1.7.18 recovery follow-up

Owner authorized dev then production website delivery on October 11. Native packages and immutable v1.7.17 tags remain separate; no native/store build is started by this batch.

Includes merged UI/runtime-number/share repairs (PR72) and offline recovery (PR73), based on tested main f3a5ca03. Additional browser QA found an unlabeled single-song remove icon; it now has three localized labels, an explicit confirmation, and a retained-download error message. Six confirmation tests pass (confirm/cancel in English, Simplified and Traditional Chinese).

Actual browser checks: localhost8778 server was stopped, listener absence confirmed, latest page closed/reopened, saved song listed, and actual playback elapsed advanced 0:00 to0:14 of3:20. This tests origin unavailable, not entire-device network isolation or audible physical-device playback. Injected Cache.delete rejection in song-media-v1 retained the old3MB recording. First injection attempt used the wrong cache-name filter and did not inject; it is not counted as a failure-path pass.

Canonical release_web --bump produced the initial1.7.18 dev/QAT bundles before this extra confirmation fix. Those initial bundles are not final production candidates. Final correct-head CI, refreshed dev UI, update retention, photo/narrow PNG export, live hashes and production deploy evidence must be appended before claiming delivery.

Store1.7.17, physical iPhone/Android/Windows/watch/car and full device offline checks remain separately scoped. Source merge is not deployment proof.
