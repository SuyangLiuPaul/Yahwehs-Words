# Google Play in-app updates — prepared for the next shared release

Owner requested the same home-screen update affordance in Words and Sword on October 2, 2026.

## Implemented

- Official `com.google.android.play:app-update:2.1.0`, flexible update flow.
- Only Android `STORE_BUILD=true` phone/tablet builds show this banner, and native code additionally requires installation by `com.android.vending`.
- Availability comes from Google Play for the actual package, signing identity, device and tester account. GitHub release versions are not used to claim Play eligibility. Play exposes a version code, not a reliable display version name, so the translated prompt says an update is available on Google Play.
- Home/workbench banner has English, Simplified Chinese and Traditional Chinese text; controls wrap on narrow screens.
- User chooses Update now or Not now. Play handles consent and downloads in the background. Foreground download polling shows progress; resume refresh recovers a completed download. Installation/restart requires a second explicit user tap.
- Failed start/install provides an Open Google Play action, never a GitHub APK fallback. Offline or unsupported installs do not prevent Bible reading.
- Direct APK self-update, web refresh and other store delivery paths are retained. No new account, storage permission or unknown-source installation prompt is added to the Play route.

## Next publication: both apps 1.7.5

This change is source preparation for the next push, not a new store delivery. Words currently has immutable1.7.4 artifacts; Sword has immutable1.7.3 artifacts. Preserve those tags, accepted packages and pending reviews.

For the next release cycle set both app versions explicitly to1.7.5 using the existing version tooling, then run each canonical web wrapper without a second bump. Confirm pubspec, Dart default, website version.json, native manifest/versionName, GitHub tag and release notes all use1.7.5 before uploading. Android versionCodes and Apple build numbers remain platform-specific monotonically increasing values; they need not be numerically equal between apps. Keep both existing Google phone internal and Alpha tracks current using the matching phone AAB. Wear uses its separate artifact/code.

## Verification and remaining gate

Flutter analysis is clean in both projects. Both native bridges were compiled together against Android36, Flutter embedding and the official Play Update2.1.0 classes successfully. No device update transaction has been completed: genuine end-to-end validation requires a Play-installed build containing this feature and a higher eligible build on the same test track. Internal app sharing can also be used with the official Play testing workflow. Never infer successful installation from the start-flow return alone; Play remains responsible for the final transaction.

References: https://developer.android.com/guide/playcore/in-app-updates and https://developer.android.com/guide/playcore/in-app-updates/kotlin-java.
