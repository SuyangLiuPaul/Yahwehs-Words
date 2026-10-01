# Learning features — 1 October 2026

## Passion wheel (Words and Sword)

Twenty source-linked scenes from the meal to burial, with where/when/what,
four-Gospel filtering and local Bible popups. Two clock rings follow the owner's
reference: day outside and night inside. Only the third, sixth and ninth daytime
hours receive approximate modern clock markers. Untimed scenes never receive an
invented 00:00/03:00 timestamp. Gospel filtering hides hours another account alone
supplies. Mark 15:25 and John 19:14 remain distinct; differing placement of scourging
and the temple curtain is disclosed. The scene list is an editorial reading guide,
not a claim that every narrated event has one proved cross-Gospel order.

Source passages: Matthew 26–27, Mark 14–15, Luke 22–23, John 18–19.
Full passage links and the editorial method are recorded in
`assets/passion_wheel.json`. Summaries are our wording; Scripture assets are unchanged.

## Bible principles (Words and Sword)

Eighteen selected study-guide entries, including turning the other cheek, the
face/back following illustration, the Golden Rule, humility, grace and good works,
first/last, agreement and self-denial. Each opens its original Pastor Eric H. H.
Chang sermon. The complete existing reference index of that source sermon is
shown as local Bible links. These are explicitly editorial summaries, not newly
attributed quotations or a claim to exhaust every possible biblical principle.
Literal sermon anchors and SHA-256 hashes allow the source claims to be checked.
`tools/build_learning_content.py` regenerates both datasets from these anchors.

## Words sermon resume

Dashboard Resume opens the sermon library beneath the saved detail route.
One Back returns to the correct expanded topic, focuses the current sermon and
highlights it. Transcript/audio restoration stays on the existing detail service;
this does not auto-play a different sermon. An obsolete saved ID leaves a usable
library. Named navigation forwards a typed request instead of discarding the
passed widget. Load errors no longer become an endless spinner. The selected row
has its own Material so the highlight does not hide tap feedback.

## Words world history wheel

The same audited Sword datasets and runtime merge loader are ported into a
namespace, preserving Words' existing chronology/family-tree models and assets.
The imported base has 22 streams, 82 nations, 305 powers, 44 ministries and 783
events; the current runtime merge contains 887 events, adding biblical narrative events from the unchanged copied
timeline through Sword's actual merge function. It retains conventional,
traditional, reconstructed and approximate date distinctions, Scripture and
dating references. Narrative passages and dating evidence appear in separately labelled groups. The mobile renderer supports pan/zoom, stream filtering,
search, dot/list details, nation and ministry lists. Undated nations are not
assigned invented years. This is a dedicated mobile renderer; Sword's existing
stacked/flat wheel and strip remain intact. Snapshot hashes are in
`docs/world-wheel-port-20261001.json`.

## Words channel import

All six public videos found on `@jesussdisciples1251` on 1 October 2026 are included
as three paired Mandarin/Cantonese teachings. Official oEmbed titles verified
both language and pairing. They are linked/embedded, never rehosted. Original
titles, channel identity and source evidence are in
`docs/jesussdisciples-channel-import-20261001.json`; English/Simplified/Traditional
catalog labels are editorial and do not create an English audio track.
The existing video health check includes these IDs.

## Delivery

The additions are published on the production websites as **1.7.0** through the canonical release wrappers; all served versions and bundles were verified. Native GitHub assets and freshly signed Apple/store deliveries are being prepared. Previous Words 1.6.37 and Sword 1.6.332 binaries do not contain these additions. Existing certification/reviews are preserved. Physical car/watch/Windows verification and Google production-access qualification remain open.

Authentic responsive browser previews are in [the gallery](screenshots/2026-10-01/web-learning/README.md); these are explicitly browser captures, not native device store screenshots.

## Verification follow-up

Full local regression suites passed before the visual follow-up: Words 3,888
tests / 36 existing skips, Sword 5,976 / 10 existing skips, zero failures.
Both static analyses were clean. Independent immutable-source review found two
Words world-wheel issues: canvas CJK fallback and an unlabelled mix of narrative
passages/dating evidence. Both are corrected with focused regression coverage.
Actual 402×874 browser inspection also found opaque dial marker backgrounds
overlapping hour labels; transparent markers retain 48px touch targets, and
each marker now exposes one actionable accessible button. Corrected source CI [36813965746](https://github.com/SuyangLiuPaul/Yahwehs-Words/actions/runs/36813965746) passed with 3886 passed / 40 platform skips, zero failures, clean analysis and secret scan. Both independent review rounds found no remaining blocker.
