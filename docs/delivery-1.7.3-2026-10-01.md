# Platform delivery checkpoint — 1.7.3, 2026-10-01

This record distinguishes released downloads, submitted store builds and public approval. It supersedes earlier preparation checkpoints; older dated records remain history.

## Verified delivery

| Destination | Words | Sword |
|---|---|---|
| GitHub v1.7.3 | Published, seven assets; all five platform workflows passed | Published, six assets; all five platform workflows passed |
| Websites | Six sites serve 1.7.3; international and China bundles verified separately | Dev and production serve 1.7.3 with matching bundle |
| Google Play phone | Closed Alpha 1.7.3 / 1007003 submitted for review | Closed Alpha 1.7.3 / 2000010 submitted for review |
| Wear OS | Internal test 1.7.3 / 20001011 published at 22:07 on October 1 | Not an application capability |
| Apple iOS | Signed 1.7.3 / 1070003 processed, internal testing available; external submission hit Apple's daily beta-review limit | Signed 1.7.3 / 1070003 processed; external beta Waiting for Review |
| Apple macOS | Signed universal 1.7.3 / 1070003 processed; external beta Waiting for Review | Signed universal 1.7.3 / 1070003 processed; external beta Waiting for Review |
| Microsoft Store | Submission 4 remains in certification; verified 1.7.3.0 package queued | Submission 4 remains in certification; verified 1.7.3.0 package queued |

The initial public Apple submissions remain Waiting for Review (Words iOS1.6.33/Mac1.6.34, Sword iOS1.6.328/Mac1.6.329). They were preserved. A newer TestFlight build does not replace those public submissions. After the initial versions are approved and released, create 1.7.3 updates using the processed 1070003 builds; do not cancel an existing review. Microsoft follows the separate latest-package guards in `microsoft-followup-1.7.3.md`. Google production still requires genuine closed-test qualification; internal Wear publication does not satisfy phone production eligibility.

## Source and verification

- Words immutable tag/source `201bacb96771770758805d07a0a0cf2f230f7655`: source CI36853294302 and merged main CI36854545006 passed. Local full suite: 3,951 passed / 36 skips. Actual Google web sign-in and existing-account reauthentication succeeded without replacing the user; isolated session was signed out and temporary diagnostic harness removed.
- Sword immutable tag/source `3ec9bc78c160d91c3b5e06df8bcb2c75e9e77f92`: source CI36854357940 passed. Local full suite: 6,006 passed / 10 skips, plus five corpus guards. Signed Mac was built from documentation head `a90bf599b7f3dac07f8efca59499048a92d2745f`, regenerated release history and the preserved local generated-Pods configuration override; that provenance is recorded separately, not asserted to equal the tag tree.
- Actual production/development version and full bundle fingerprints were checked across all eight hosts. Each deployment group matched internally; Words international and China differed as intended. Local evidence: `all-sites-1.7.3-verification.json`.
- Each Apple package was checked for version, signing and required metadata, hashed, uploaded and visibly processed in App Store Connect. Words iOS includes the matching Watch application. Four-package record: `apple-companion-auth-1.7.3-verification.json`.
- Windows MSIX identity/publisher/version/architecture and Google AAB signing/version continuity were independently checked. Records: `store-msix-1.7.3-verification.json` and `store-reference-clock-1.7.3-verification.json`.

## Screenshots and remaining device checks

Existing genuine phone/macOS galleries retain their measured dimensions, original versions and source/hash manifests. Additional 1.7.3 Mac and Wear captures are kept separately. A disconnected Wear Now Playing capture is QA evidence and is held from Store marketing. Do not relabel older screenshots as 1.7.3 or portray simulated state as verified physical pairing.

The source includes Words phone/watch current-chapter and shared audio progress, covers and localized car catalogues. Physical Windows/Play/Mac account flows, paired Apple Watch/Wear playback and Bible refresh, and vehicle dashboard controls require actual device confirmation. Sword has local profiles and no Firebase, watch or car companion. Green CI and successful upload do not close these hardware checks or declare every historical parity item complete.

## Storage and reproducibility

Recoverable generated caches were removed; full signed archives, dSYMs, exports, source, private keys and existing simulator data were retained. Verified older archives and current iOS archives are on T7 with recorded file hashes. New signed Mac archives are retained in the APFS sparse image `/Volumes/T7/Yahweh-Release-Backups-20261001/YahwehSignedMac173.sparseimage`, mounted at `/Volumes/YahwehSignedMac173`. Original archive paths are symlinks; mount the image before reopening them. Keep the external disk and image intact. Free space was approximately9GiB after offload and before the final simulator screenshot build; this is a dated measurement, not guaranteed remaining capacity.

## Follow-up rules

1. Recheck Words iOS external TestFlight once its daily submission limit resets; submit processed1070003 to the existing Public beta group with current test notes. Preserve pending older beta reviews.
2. Preserve pending Apple public reviews and Microsoft certification. Submit only when the platform permits a new update, preserve approved descriptions and genuine screenshot sets, and skip when1.7.3 or newer is already submitted.
3. Use the verified signed packages and hashes; never move immutable tags or rebuild a different source under an existing release tag.
4. Notify the owner only for completion, failure, meaningful review status changes or required owner action. Public approval dates cannot be promised.

All local evidence paths above are relative to `/Users/pliu0036/Downloads/Yahweh-Publication-Assets-20261001/`. No credentials or private account data are included in this repository record.
