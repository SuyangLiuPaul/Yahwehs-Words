#!/usr/bin/env bash
# Upload a signed .ipa to App Store Connect (TestFlight) with an API key,
# so no Xcode login is needed. It only uploads; it does NOT submit for review.
#
# One-time setup (the owner does this in App Store Connect, never an AI):
#   Users and Access > Integrations > Team Keys > "+" (role App Manager),
#   download AuthKey_<KEYID>.p8 once, then:
#     mkdir -p ~/.appstoreconnect/private_keys
#     mv ~/Downloads/AuthKey_<KEYID>.p8 ~/.appstoreconnect/private_keys/
#     export ASC_KEY_ID=<KEYID> ASC_ISSUER_ID=<issuer uuid>
#
# Usage: tools/ios_upload.sh path/to/App.ipa
set -euo pipefail
ipa="${1:-}"
[ -f "$ipa" ] || { echo "usage: $0 path/to/App.ipa" >&2; exit 2; }
: "${ASC_KEY_ID:?set ASC_KEY_ID}" "${ASC_ISSUER_ID:?set ASC_ISSUER_ID}"
key="$HOME/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID}.p8"
[ -f "$key" ] || { echo "missing $key" >&2; exit 2; }
case "$ipa" in *unsigned*) echo "refusing the unsigned CI .ipa" >&2; exit 2;; esac
xcrun altool --upload-app --type ios --file "$ipa" \
  --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"
echo "Uploaded. Finish in App Store Connect (TestFlight / Submit for Review)."
