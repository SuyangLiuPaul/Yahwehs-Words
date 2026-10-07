# Settings scroll stability and web manifest repair — 2026-10-07

## Owner evidence and scope

The owner supplied an iPhone TestFlight recording showing Settings jumping between variable-height sections near the AI card. The model card is static; the observed fault is viewport/scroll stability. Both apps now use an exactly measured finite scroll form instead of lazy list extent estimates. Deep-link sections are built before positioning. Long dropdown labels and About titles wrap within their available width. Words also gives offline checkboxes their own Material surface; Sword projector selectors render the complete selected label without sizing the closed control from unrelated menu options.

The owner separately supplied a Sword web AssetManifest.bin.json error marked 1.6.328 and a Bing crawler user agent. A live read-only check of sword.yahwehword.com found current version 1.7.14 and a valid /assets/AssetManifest.bin.json wrapper matching its 201155-byte binary; FontManifest had seven font families. This does not reproduce or establish the cause of the older crawler report. No user data/cache reset was performed.

Both canonical web release wrappers now verify actual startup manifests after matching version and bundle checks. HTTP 200 HTML fallback, malformed JSON/base64, empty/mismatched binary and malformed font lists fail verification. The binary manifest now has the same revalidation policy as its JSON wrapper. No API/identity/security rules or scripture data changed.

## Verification

- Seven pure manifest verifier checks passed for each app. Existing release wrapper tests passed: Words 37, Sword 11.
- Settings geometry checks cover iOS, Android, macOS and Windows target behavior; English, Simplified and Traditional Chinese; widths 390 and 1024; system text scale 1.3. Repeated forward/reverse jumps must retain exact scroll offset and total extent.
- Initial full suites revealed only affected Settings regressions: Words offline checkbox Material assertions and Sword projector truncation. Product fixes were applied; the final affected-file reruns passed (Words 69 and Sword 33). Stronger reruns removed the earlier debug warning filter and included manifest checks: Words 70 and Sword 34 passed. Final exact-head full CI remains the release gate.
- Actual compiled web preview at 390x844 verified English and Chinese AI card readability and backward scrolling. This is browser UI evidence, not physical iPhone/TestFlight verification.

## Release guards

Repair is intended for paired 1.7.15. Existing tags/packages remain immutable. Do not claim this source change delivered by the already built 1.7.14 packages. Preserve all current reviews; new packages require matching successful CI, signature/identity/version validation and accepted delivery. Words phone internal 1.7.14 draft was left Ready to release, not published, while the repair is prepared. Microsoft 1.7.14 submissions remain pending and must not be cancelled. All physical Watch/Wear/vehicle/Android Auto and actual store in-app upgrade gates remain open. Sword has no Words companion/audio/AI capabilities. Automation remains paused; yahwehdehua is excluded.

Evidence: /Users/pliu0036/Downloads/Yahweh-Diagnosis-1714. Original owner workspaces/builds and Sword PBX override were retained; this repair uses isolated git worktrees.
