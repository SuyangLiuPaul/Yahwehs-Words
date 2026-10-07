# Basic and Advanced web Settings — 2026-10-08

Owner authorized paired dev/prod WEBSITE deployment and GitHub/documentation updates. No version bump, release tag, native build, store submission or admin database mutation.

Web Settings defaults to Basic: account, interface language, font/menu size, light/dark/system theme, reading mode, update check and diagnosis ID. Advanced expands on demand: detailed appearance, copy formats, projection, reading tools/cache, notification preferences, import/export; Words also contains Home layout and AI configuration. Sword has no AI or companion settings introduced by this change.

The original control widgets and handlers are retained. Original section links auto-expand Advanced when needed, including later changes to the initial section. A simple disclosure avoids animated height estimation that previously destabilized Settings scrolling. Native Settings keeps its original order through kIsWeb gating; installed packages are untouched.

Both changed Settings files passed Flutter 3.44.2 static analysis. Deployment and browser verification results will be appended after completion. About/CN official badge layout from the prior mobile pass is included in Words. Portal mobile CSS remains separately committed locally, pending explicit portal deployment.

Evidence/log folder: /Users/pliu0036/Downloads/Yahweh-Settings-Tiers-20261008/.

## October8 — Basic/Advanced web Settings delivered

Web-only Settings now defaults to Basic; Advanced expands on demand and existing section links open the required group. Maintenance/offline/reset controls are inside Advanced; the About summary remains compact. All six Words international/China dev, QAT and production sites were deployed with the canonical no-bump wrapper and re-fetched successfully, including matching full main.dart.js and startup manifests. Version remains 1.7.15; native/store packages and immutable release tags are unchanged.

PR52 source 98a0d4251226601010cea45d2028f52234c57422 passed exact-head CI37687023733 and merged efad561e9a948f536c6a3ff951031ccf3ace673c. Live mobile production Basic/Advanced and the AI section link were inspected; evidence is under /Users/pliu0036/Downloads/Yahweh-Settings-Tiers-20261008/. Netlify upload timeout recovery reused the same canonical China file and then verified live output. No database, account or security setting was changed. Admin mobile work remains local-only.

