# Shared tagline — 2026-10-07

Owner explicitly selected the same tagline for both apps; product names stay unchanged.

| Locale | Tagline / store subtitle |
| --- | --- |
| English | Study Yahweh's Words |
| Simplified Chinese | 研读雅伟的话 |
| Traditional Chinese | 研讀雅偉的話 |

English subtitle is 20 characters, suitable for the 30-character App Store subtitle field. Use the same lead phrase in Google Play short descriptions, Microsoft listing descriptions, website metadata and app About/Settings/footer. Preserve accurate feature details and existing translations/screenshots following the lead. Do not edit Bible text, permission titles, historical release records or references merely because they describe bilingual content.

## Source preparation

The shared appTagline and fallback strings, README introduction, pubspec descriptions, web manifests and search/share metadata have been changed locally. Words site-specific manifest overlays and their generator use the new phrase too. The social-card generator has the updated English and Chinese tagline. No version bump, tag mutation, production deployment or native/store package rebuild is part of this wording task; changes require the next authorized build/deployment.

## Store gates observed

Words App Store App Information explicitly shows old English subtitle `A bilingual Bible`, disabled because macOS 1.6.34 is In Review. Apple says editing requires removing that review. Preserve the pending review and apply the prepared subtitle once unlocked; do not cancel for wording. Words iOS 1.7.11 now shows Ready for Distribution.

Words Google Alpha1.7.3 remains in review; latest Alpha1.7.12 and data-safety changes are saved unsubmitted. A metadata edit must not cancel/restart that review. Keep same/newer packages, identities, approved screenshots and privacy declarations.

Google/Microsoft/Apple live publication must be reported separately from local wording edits. No source preparation alone proves a live listing changed.

## Saved store wording checkpoint

Sword App Store English subtitle was saved successfully as `Study Yahweh's Words` (Saved confirmation), with pending iOS 1.7.8 and Mac 1.6.329 reviews preserved. Apple says changes release with the next app version; this is not a live-publication claim. Only English is available in its disabled language picker.

Both Google Play default listings now have the English, Simplified Chinese and Traditional Chinese short descriptions saved as drafts. Google showed `Your changes have been saved`; no review was cancelled or restarted and no package changed. Full descriptions and visual assets were preserved.

Words social share card was regenerated from the existing project renderer and logo. No native tests or builds were run for this copy-only task.

Microsoft Words metadata-only draft Submission13 `1152921505702059790` preserves the inherited validated package. All three descriptions have the matching tagline prepended and were saved. Sword metadata draft Submission10 `1152921505702059903` has been created from its published listing for the same edit. These draft IDs must be reused rather than creating duplicates. Certification/publication are separate from saving a draft.

Final copy checkpoint: Sword Microsoft English/Simplified/Traditional description edits were also saved; both Microsoft drafts now contain all three matching tagline leads. All original full descriptions, screenshots, package selection, languages and listing identities were retained. Metadata remains drafted, not certified/published. Basic diff whitespace and manifest JSON syntax inspection completed; no runtime tests were requested or run.
