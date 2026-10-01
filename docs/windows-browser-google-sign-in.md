# Windows browser Google sign-in — 1.7.2

Windows Firebase supports `signInWithCredential`, while its mobile provider UI returns “operation is not supported on non mobile system”. Words now opens the system browser, uses the existing Firebase Google provider on a dedicated HTTPS helper, and exchanges the returned Google credential through the Windows Firebase SDK. Main sign-in requests email/profile only. Existing web redirect, macOS GIDSignIn and iOS/Android provider flows are preserved. Apple sign-in remains offered on supported Apple platforms; email/password remains available where Firebase is configured. China builds remain local-only.

## Lifecycle and privacy

- Listen only on `127.0.0.1`, an ephemeral port, a fixed path, and a five-minute total deadline. Close on success, cancellation, timeout or failed browser launch; suppress concurrent attempts.
- Each attempt has a cryptographically random 256-bit state. Require exact HTTPS helper Origin, loopback Host, POST form content type and state. Limit body to64KiB and tokens to16KiB each; accept once and reject invalid requests without ending a valid attempt.
- Google credential tokens return in a form POST, never query strings or application logs/files. The helper uses a named Firebase app and session-only Firebase persistence, signs that helper out before return, and leaves the main website account untouched. Firebase validates the Google credential; the app then uses its existing profile-adoption/sync path.
- The helper bypasses the PWA service-worker cache, has no-store/no-referrer headers, and allows only the Google SDK script origins and Firebase authentication endpoints needed by the existing provider. No embedded OAuth client secret or Admin credential.
- Windows Google account reauthentication uses the same credential bridge. Legacy Drive refresh returns unavailable on Windows, since main sign-in does not grant Drive access; normal Realtime Database sync remains available.

## Android API restriction repair — 2026-10-01

Google Cloud’s Android key for `ysword` was restricted to Pollen API alone. After explicit owner confirmation, **Identity Toolkit API** and **Token Service API** were added while preserving Pollen. The console readback shows3allowed APIs. No database rules, account roles, scopes or key value were changed. Historical Gemini API usage generated a warning; Gemini remains excluded from this public Firebase client key.

Public authentication-endpoint probes of the actual Android APK/Play, Apple and web/Windows configurations returned HTTP200 and a Google authorization URI. This verifies the reported API restriction is resolved, not a full device login. Dedicated browser round-trip and physical Windows/Play-installed verification are separate gates.

## Verified delivery and complete provider audit — 2026-10-01

Words 1.7.2 passed source CI (3,926 tests, 40 existing platform skips), main CI and all five GitHub platform builds. Seven release assets are uploaded. All six international/China websites were re-fetched and their versions and matching build bundles verified. The real Google browser flow reached the native loopback receiver, and the returned credential was accepted by Firebase's signInWithIdp backend (HTTP200). The actual Windows Firebase DLL exchange and Play-installed Android login still require physical-device confirmation; a browser/backend success is not evidence of those device-specific steps.

A follow-up audit found that Google account reauthentication on Mac still used the generic provider API unsupported by the macOS Firebase plugin. It now acquires a Google credential using the same GIDSignIn flow as main Mac login, then calls reauthenticateWithCredential on the existing user. Windows retains its browser credential bridge; web uses the live-verified same-origin helper plus a one-use BroadcastChannel credential response; Android/iOS retain their provider API. No reauthentication path signs in a replacement Firebase user. Cancellation and the SDK's wrong-account rejection stop before cloud deletion.

The Apple branch was checked in the installed firebase_auth 6.4.0 Objective-C source: apple.com takes launchAppleSignInRequest before the macOS generic-provider rejection, for both sign-in and reauthentication. The existing iOS/Mac Apple entitlement remains present. No custom replacement Apple OAuth flow is needed. Email sign-in, registration, reset, account-collision privacy and timeout behavior are covered by the existing regression tests. The initial combined platform/desktop/email authentication checks passed 105 tests; the updated helper/companion/reference checks passed 56 targeted cases; static analysis has no issues. This follow-up source still needs its own full CI, immutable release and native deliveries; it is not in the already-uploaded 1.7.2 binaries.

## Checks and release gates

Loopback regressions cover valid completion, wrong state/origin/path/method, oversized/missing credentials, cancellation, duplicate attempts, browser disconnect, deadline, retries, closed listener and config consistency. Existing email authentication, Windows Firebase initialization and PWA tests are retained. The full updated GitHub CI, actual browser flow and signed Windows build must be checked before declaring release complete. Device credentials remain for the owner to enter.

References: [Firebase Google provider](https://firebase.google.com/docs/auth/web/google-signin), [redirect storage requirements](https://firebase.google.com/docs/auth/web/redirect-best-practices), [Firebase API restrictions](https://firebase.google.com/docs/projects/api-keys).

### Browser validation correction

A real Google redirect exposed an overly strict requirement for both token types. Firebase may return an access token without an ID token; both the browser helper and native bridge now accept either, normalize missing tokens to null and retain all state, origin and size checks. Dedicated regressions cover both single-token cases and reject a response with neither. The public helper config is allowlisted by its exact file path in Gitleaks, alongside the existing Firebase client configs, and its complete key set and values are checked in tests. No private credential is added.

A second real-browser check reached the local listener but was rejected because a non-CORS form under `no-referrer` sends an opaque `Origin: null` (WHATWG Fetch). The helper keeps no-referrer while authenticating, then switches its meta policy to origin only immediately before the fixed loopback POST. This discloses only the helper’s domain, never path/query or tokens, and retains the native exact HTTPS Origin check; opaque origins remain rejected. See [Fetch origin-header algorithm](https://fetch.spec.whatwg.org/#append-a-request-origin-header).
