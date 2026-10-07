# Settings verification — 2026-10-07

Owner requested thorough checks of both apps and local commits plus dev/prod web deployment without changing 1.7.13.

## Words changes and validation

- Source commits: 03d4752df42fd9d680cee7a2a1ceb98fe6a4fc1e and 2baf52a7e0775d038b70846c30e6ba739971324d.
- Current Home sections terminology, fixed notice placement and frequent/expandable Quick links descriptions in English, Simplified and Traditional Chinese. Existing eight-section visibility/order remains; Read Bible stays mandatory.
- Both analyses clean. Words full suite 4055 passed/36 skipped before the final localization correction; final related copy/layout/deep-link/update tests 23 passed afterward.
- All 21 value-bound settings have traced consumers. UI checks: English/Chinese desktop and 390px width; locked Bible entry; Quick links off persists after reload and restored on; final Featured description rendered correctly in Simplified/Traditional Chinese. Language restored to English and temporary viewport reset.
- Canonical tools/release_web.sh --no-bump --include-prod completed with exit 0 after targeted transport retries. All six live versions are 1.7.13; independent complete main/bootstrap digest checks passed.

| Build | main.dart.js SHA-256 | bootstrap SHA-256 |
|---|---|---|
| international | bf08d1bcf090352171e1b7b152d4ddfc68a1df1b871f3b219946345312153a56 | 89b805e3a81824326df12c79c32ff403b37bef8b9e2c6dce75aaf78b65b20661 |
| china | 34656b85c6e8377480b31abe0dab1ea6101488756ce23b6f47d416efa58510ec | 89b805e3a81824326df12c79c32ff403b37bef8b9e2c6dce75aaf78b65b20661 |

Sites: yswords-dev.netlify.app, yswords-qat.netlify.app, yswords.netlify.app; yswords-cn-dev.netlify.app, yswords-cn-qat.netlify.app, yswords-cn.netlify.app.

## Paired scope and evidence

Sword static analysis, full suite 6097 passed/10 skipped and final related 60 tests passed; both final dev/prod bundles now match their complete local hashes. Final English/Chinese installation guidance was verified on prod, including Chinese 390px layout. All eight paired sites verified; see all-eight-final-live-verification.json.

Evidence: /Users/pliu0036/Downloads/Yahweh-Settings-20261007/ (settings-control-consumers.json, settings-verification.json, international-final-live-verification.json, china-final-live-verification.json, logs and screenshots).

Native/store packages were not rebuilt for these copy changes; a future explicitly authorized native release is required. No new physical companion, notification delivery or installation-flow verification is claimed. Existing preference keys, content, routes, immutable tags and pending store reviews remain preserved. No GitHub push in this task.

## Follow-up: Home reading shortcut and update timing

Home's English shortcut now says `Reading stats`; the page title remains `Reading statistics`, and both Chinese labels remain unchanged. Font size and wrapping/accessibility behavior are preserved. This follow-up is local source only, not part of the eight deployed bundles above; no version bump or deployment.

Source inspection: Settings has a manual update check for native direct-download builds and a channel-aware manual check for store/web builds. Direct-download automatic checks default to daily when Home is initialized, with launch/daily/weekly/monthly choices. Store eligibility is checked through the relevant store; registry announcements alone do not prove an installable store update. Web checks start after 20 seconds, repeat every 30 minutes, and also check on resume.

Songs call a best-effort background refresh on catalogue load, throttled for 12 hours after a successful fetch. Upstream's configured song workflow runs daily at 18:00 UTC; this is a schedule, not proof that its latest run succeeded. Admin overlays cache successful reads for 30 minutes and refetch on a later request, not on a continuous background timer. SermonService currently caches its merged index for the process lifetime, so an already loaded sermon list does not automatically reapply subsequent admin changes. SongService.refresh exists, but no production UI call site was found; do not promise a Songs pull-to-refresh action based on stale comments. No runtime/UI tests were run for this follow-up.

## Additional owner request: one recommended AI model

Removed the Words Fast/Standard/Deep selector. Current clients send `auto`, resolved to stable Gemini 3.8 Flash with medium thinking through official GenerateContent. Legacy saved choices migrate to auto without changing the stored API key or export key names. Old native aliases remain accepted by the functions. BYOK remains mandatory; no shared developer credential or silent fallback. Sword has no AI subsystem, so no AI feature was added.

Official sources: https://ai.google.dev/gemini-api/docs/latest-model and https://ai.google.dev/gemini-api/docs/generate-content/latest-model. Availability depends on the reader's Google project. Real provider responses with the owner's key have not been exercised. Mock transport verified model/medium/JSON mode, filtering thought parts and forwarding quota errors; three function syntax checks passed. Existing settings/key/deep-link tests: 11 passed. Flutter analysis clean.

Home follow-up: shortened English shortcut to Reading stats, then removed redundant arrows on the four frequent shortcuts after 390px local inspection showed the label alone still wrapped. Full Reading statistics page title and Chinese labels preserved. Two prior deployment attempts were interrupted to incorporate this final owner request. Final deployment confirmation will be recorded after live bundle checks. App version remains 1.7.13; no native tag/build or GitHub push.
