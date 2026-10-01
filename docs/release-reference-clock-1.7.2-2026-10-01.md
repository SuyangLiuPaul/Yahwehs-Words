# Reference clock update 1.7.2 — 2026-10-01

The owner requested replacing the existing Passion clock with the supplied complete diagram. See [content provenance and interaction checks](passion-reference-clock.md). The Passion timetable is now visible in both apps under its dignified localized name; principles stay hidden, Words history stays hidden and Sword’s established history remains visible. Existing routes remain unchanged; no Scripture or saved-data migration.

## Delivery gates

1. Canonical web wrapper bumps both apps to1.7.2 and deploys dev for real interaction review.
2. Source PR CI, analysis and independent review must pass before merge and immutable tag.
3. Production sites, five GitHub platform workflows, signed iOS/macOS uploads and separate Play/MSIX builds must each be verified and recorded. A version bump or prepared package does not mean publication.
4. Existing public Apple reviews and Microsoft certification stay preserved. Store follow-ups use the latest verified artifact when editing becomes available; daily Microsoft automation now targets1.7.2. Google production still requires real closed testing qualification.
5. Android Auto/Wear real capture remains gated by owner Google Play login to the dedicated emulator. Physical paired watch/car and Windows checks remain open; Sword has no car/watch companion.

## Verified previous delivery

1.7.1: Words7/Sword6 GitHub assets are available; all eight websites were version/bundle verified. All four signed Apple packages1070001 delivered and processed. Words iOS external beta is waiting for review; other beta group workflows will be recorded as completed. Do not mislabel1.7.1 as containing this new diagram.

## Storage

Additional cleanup reclaimed cache space and moved older compressed backups, byte-verified, to T7. Original path links preserve access while T7 is connected. Latest signed archives, exports, source and original simulator data remain local. Current free space is a measurement, not the sum of gross cache deletion figures.

The first PR CI attempts failed the image audit (both apps) and Sword font-size ratchet. These were repaired with image failure handling, original-size decode bounds and scaled Sword badge/clock labels. Focused regression checks cover translations, language switching at 320px, both 08:00 descriptions, source image checksum, unchanged Gospel time semantics and owner visibility policy. Full CI must pass the updated source before public delivery.

Words also fixes Windows Google sign-in through the external browser and restores the Android Firebase key’s login/refresh API allowlist. See [authentication implementation and verification gates](windows-browser-google-sign-in.md). Sword has no Firebase login and does not claim this fix.
