# Store API draft uploads — 2026-10-11

Play phone AAB upload is optional and draft-only on internal/alpha/beta. Phone and Wear artifacts remain separate. The Play REST upload preserves existing track releases, refuses existing drafts and commits with changesNotSentForReview=true only. There is no fallback that sends review.

Microsoft optional MSIX upload uses the create-only REST API and refuses existing pending submissions. The official CLI publish command can replace drafts, so it is not invoked. Listing/localization fields from the cloned draft are retained; no DELETE or certification commit is issued.

Apple local tools/apple_upload.sh supports ios IPA and macos PKG. It uses the existing local ASC key, validates via Apple before uploading, and never submits review. Acceptance and processing require separate checks. Existing uploaded build numbers must not be reused. No credential is copied to GitHub.

Store API preflight reads Play tracks/bundles in a temporary edit and deletes only that edit without committing. It reads Microsoft application/pending state. Output contains identifiers/status only, no secrets or upload URLs. Credential names alone do not establish permissions or upload acceptance.

Checks: workflow YAML parsed, shell syntax valid, pending-submission unit tests passed. Actual API/workflow outcomes are recorded separately. No new version/tag/publication is implied by these automation changes.
