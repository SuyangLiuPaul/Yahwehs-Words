# Learning release 1.7.0

## Owner visibility correction — 2026-10-01

Words hides all three new learning entries. Sermon resume navigation and the new teaching videos remain visible. Code and existing URLs are retained. This supersedes the visible-feature claims below; v1.7.0 stays immutable and the correction is prepared as 1.7.1. See `docs/release-visibility-1.7.1-2026-10-01.md`.


## Learning release 1.7.0 — 2026-10-01

- Both apps include the source-linked Passion wheel and 18 selected Bible principles. Words additionally includes the world-history wheel, saved-sermon return flow and all six paired Mandarin/Cantonese Jesus’s Disciples videos. Scripture assets are unchanged.
- Corrected functional source `2041a176693e00a149e24e7f9b19731322d9a0c6` passed [CI 36813965746](https://github.com/SuyangLiuPaul/Yahwehs-Words/actions/runs/36813965746): **3886 passed / 40 platform skips**, zero failures; analysis and secret scan succeeded. Two independent source-review rounds found no remaining blocker.
- Canonical web release deployed **1.7.0** and verified served versions/bundles on all six international/China sites. GitHub release, newly signed Apple deliveries and latest store packages are being prepared; this checkpoint does not claim their completion.
- Existing Microsoft certification, Google review and initial public Apple review remain preserved. New binaries must be verified before replacing editable drafts; do not cancel certification. Physical Windows/car/watch validation and Google production tester qualification remain open. Sword has no Firebase or car/watch companion.
- Additional storage cleanup reclaimed about **8.78 GiB net**, preserving signed archives, dSYMs, exports, source and screenshots. Builds consume some reclaimed space; consult the final measured free-space record.

## Release preparation

- Native Apple build number: 1070000; iOS deployment target: 15.0.
- Microsoft target: 1.7.0.0, x64, existing product identity and publisher. Packages are pending verified workflow output at this checkpoint.
- Google package codes are workflow-specific and must be read from built AABs, not inferred from the Apple build number.
- Pending certification/public reviews must be preserved; automatic publication remains enabled where already configured.
- Authentic browser preview manifests record source revision, viewport and hashes. Existing phone/car/watch galleries remain separately labelled.
- Prior source and package records remain historical evidence; do not retag previous versions.
