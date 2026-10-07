# Search Console structured-data repair — 2026-10-07

Owner requested repair of Gmail notice WNC-10030322. Message 1a115cf4e32e93f5 is from Google Search Console to the existing owner account. Search Console identifies one affected URL, https://yahwehword.com/, Incorrect value type, last crawl 2026-10-04. The captured source highlights an HTML comment inside the JSON-LD featureList array at line150. The current production source reproduces the same strict JSON parse failure.

Repair moves that HTML comment outside application/ld+json. Existing SEO test previously parsed a comment-stripped copy of the whole page, masking the fault; it now parses the raw script body. All21 existing SEO tests passed on Flutter3.44.2. No app version bump, native/store rebuild, tag mutation, account/permission change, unsubscribe or outbound email.

Canonical Words web wrapper --no-bump --include-prod deploys the existing1.7.15 release with this HTML-only repair to international and China dev/QAT/prod. International sites and actual yahwehword.com have passed strict raw JSON decoding. Search Console Validate fix was submitted through normal visible UI after production verification; status Validation Started, started07/10/2026. This is acceptance of revalidation, not final Google clearance or a guaranteed indexing/rich-result outcome. Final six-site evidence is seo-six-sites-live.json; canonical exit/log in words-web-seo-fix.log.

Targeted primary files synchronized with pre-edit backups. Runtime signing/store packages/pending reviews unchanged; prior goal stays completed and heartbeat paused. Evidence: /Users/pliu0036/Downloads/Yahweh-SEO-20261007.
