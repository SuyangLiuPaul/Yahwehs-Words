# Words follow-up 1.7.3 — 2026-10-01

The owner authorized all previously reported login repairs, clearer localized reference actions, improved watch/car presentation and phone chapter synchronization, followed by a complete platform update. Existing 1.7.2 tags remain immutable. Sword has a separate reference repair; it does not acquire Firebase or car/watch capabilities.

## Implementation

- Windows Google sign-in and reauthentication retain the validated external browser credential bridge. Mac uses native GIDSignIn credentials; reauthentication calls the existing user, preserving wrong-account rejection.
- A live web popup experiment immediately returned `auth/popup-closed-by-user` while the account selector remained open. Web reauthentication now opens the existing same-origin helper in a separate tab and receives a bounded, one-use BroadcastChannel response. The 256-bit state, session-only isolated Firebase instance, four-minute deadline, `noopener`, current isolation headers, native loopback Origin validation and existing OAuth scopes are retained.
- Android/iOS retain supported Google provider flows. Apple and email authentication retain their established paths. Firebase console confirms all three providers enabled; the authorized Android Identity Toolkit/Token Service API repair retains Pollen and application restrictions.
- Apple Watch and Wear OS receive the active phone player's title, source, actual artwork (or the app icon), locale, progress and pause/seek/skip state. Controls act on the same phone audio session. Connected/fresh state remains explicit; saved progress does not advance when disconnected.
- Both watches display the phone's currently selected Bible chapter and edition. Only public verse text, split-verse labels and scripture headings transfer; notes, credentials and user annotations do not. Chapters are bounded at complete verse boundaries (44,000 bytes), with an explicit message if the rest must be read on the phone. This is a companion chapter view, not an independent complete offline Bible library.
- Wear artwork uses a single worker, HTTPS, bounded download/decode, one-image cache and stale-result checks. Its weighted transport row adapts to small watch widths. Apple Watch uses SwiftUI and system Now Playing volume controls.
- CarPlay retains Apple's standard list and Now Playing templates, adds category symbols and a working Browse audio return action. Android Auto catalogue and covers follow the same phone session and UI locale. No video or non-audio task is offered while driving.
- External Sirach citations have Simplified/Traditional Chinese labels. Unsupported citations explain their source instead of promising an unavailable reader passage; canonical references retain their reader jumps. The shared beta guide's Contact support opens the support form and also offers a visible, copyable email address.

## Verification to date

- 56 targeted Words regressions passed: credentials/cancellation/wrong account/order of deletion, strict Windows callbacks, helper separation, external citation feedback, bounded watch chapter data and shared audio metadata/catalogue localization.
- Watch SwiftUI type checking against watchOS 9 simulator SDK succeeded. Wear `assembleDebug` succeeded.
- Actual owner Google account sign-in and reauthentication through the helper succeeded in Chrome on `yswords-dev.netlify.app`; existing user identity remained equal. No account was deleted, no credentials were printed, and the isolated test session was signed out. Screenshot: `web-google-coop-safe-reauthentication.png` in the publication evidence directory.
- Windows callback/backend handoff and Android public auth API probes remain documented in the 1.7.2 evidence. Those do not substitute for physical Windows/Play/Mac end-to-end authentication.

## Remaining delivery gates

Full CI, final production site fingerprints, tagged GitHub artifacts, signed four Apple deliveries and corresponding Google Play/Wear submissions remain to be completed. New screenshots must come from the actual built applications. Physical watch pairing, dashboard interaction, phone playback linkage and device-specific login remain separate verification gates. Pending public Apple and Microsoft reviews must not be cancelled; approval timing is not promised.
