# Authentication follow-up 1.7.3 — 2026-10-01

The owner asked to finish every previously reported login repair and push the complete update. 1.7.2 is already immutable and delivered; this additional Google reauthentication repair is a Words patch, not a replacement tag or a new Sword capability.

## Scope

- Windows Google sign-in and reauthentication retain the validated external-browser credential bridge.
- Mac Google sign-in and reauthentication share the native GIDSignIn credential acquisition. Reauthentication calls the existing user's credential method, never signs in a replacement Firebase user.
- Web reauthentication uses the web popup API. Android and iOS retain the supported provider method. No database rule, OAuth scope or account permission is widened.
- The installed Firebase Apple source explicitly handles Apple before rejecting the unsupported generic Mac provider API; Apple sign-in and reauthentication remain on that supported path.
- Email sign-in, registration, password reset, collision privacy and bounded failures retain existing behavior.
- Firebase console readback confirms Email/Password, Google and Apple are all enabled. The Android public key's Identity Toolkit/Token Service repair preserves its Pollen restriction and application restriction.
- Sword has local profiles and no Firebase login. Its completed 1.7.2 delivery remains the current Sword release.

## Verification

105 combined authentication regression tests passed; analysis has no issues. Cases exercise Windows/Mac credential reauthentication, web/mobile routing, cancellation, wrong-account rejection and reauthentication ordering before cloud deletion. The previous live browser callback and Firebase backend exchange succeeded without logging credentials. No real owner account is deleted during verification.

Full updated CI, immutable tag, five GitHub platform workflows, six site version/bundle checks and new signed Words native deliveries remain required. Physical Windows/Play/Mac authentication, and web popup behavior under the production isolation headers, remain distinct verification gates. A provider being enabled is not proof of a complete physical-device login.
