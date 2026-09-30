# Words CarPlay Audio request — 2026-09-30

Apple Developer team YC5JZD3DY7 (SUYANG LIU); existing iOS bundle ID
`com.example.yswords`, App Store Apple ID 6817557892.

Owner accepted the CarPlay Entitlement Addendum in Chrome. The official
request page https://developer.apple.com/contact/request/carplay/ displayed
“Thank you for your submission. We’ll review your request and contact you
soon with a status update.” Audio was selected. No app-specific details
field was offered in this flow. This is receipt of the request, not grant
of the entitlement.

## Explanation ready for Apple’s follow-up

Yahweh’s Words is a Bible reader with an audio library of hymns,
instrumental music, and recorded sermons. In CarPlay mode its primary
purpose is audio playback. The planned interface uses native CarPlay list
and Now Playing templates, with a short category hierarchy and bounded
song pages. Drivers can browse audio by source or sermon series, select
an item, play or pause, skip hymns, and seek within sermons. Audio uses a
single platform media session and resumes saved sermon positions.

The CarPlay interface does not show Bible reading, lyrics, web pages,
video, login, messaging, commerce, or study editing. It will launch the
shared playback engine directly from the dashboard without requiring the
driver to interact with the iPhone. Phone media interruptions and existing
playback focus continue to apply.

Website: https://yahwehword.com/.

## Before enabling or distributing

1. Receive Apple’s written approval and granted audio provisioning profile.
2. Run `python3 tools/configure_carplay.py --profile /path/to/profile.mobileprovision`.
   The script checks the actual Apple-issued entitlement, team and app ID;
   it preserves other app entitlements and enables the shared phone/car
   scene configuration only after that check.
3. Compile, inspect the dashboard and cold-launch path, and sign a new iOS
   build with the granted profile. Include the CarPlay use in review notes.
4. Submit the new build. Do not call the current TestFlight/Store binary
   CarPlay-compatible while this step remains pending.

Default builds do not access CarPlay APIs: `CARPLAY_ENABLED` is absent and
the ordinary Flutter scene remains in place. Prepared native scene source
has not been compiled or used against restricted APIs before the grant.
