# Words 1.7.24 — paired Genesis display correction

## Source correction

- Corrected the localized display name for Genesis across reading, search, study, saved references, export/share, projection, feedback, and Watch snapshot labels. Traditional and Simplified Chinese now use the formal localized name.
- Kept legacy corpus names, saved IDs, lookup aliases, and Scripture text unchanged. Regression tests cover display labels and persisted identities.
- Merged source PR [#89](https://github.com/SuyangLiuPaul/Yahwehs-Words/pull/89) at `7153394a`; exact source CI run `38217744313` passed, including the full Flutter test job and companion-native checks.
- The same PR fixes the Play release-note loader to accept the repository's three-locale map as well as API-style records, with required-language validation and regression tests. Guard tests passed locally (22).

## 1.7.24 preparation

- Paired release branch is being prepared from merged main. Visible version target: **1.7.24**; Apple build target **1070024**. Play phone/Wear codes remain workflow-allocated and must be validated against the current Play API before upload.
- Localized Play and Microsoft release notes are prepared in `store-notes-1.7.24.json` and `microsoft-store-release-notes-1.7.24.json`.
- **No 1.7.24 tag, package build, website deployment, or store upload is claimed yet.** Before each upload, read current store state and preserve active reviews/drafts. Upload, processing, review, and public availability are separate states.

## Verification limits

- Static analysis and the paired display, saved-reference, projection and Watch-label regression suites passed in the source PR. Store package validation and live screens for the 1.7.24 build remain pending.
- Genesis data keys and original Scripture content are intentionally unchanged.
