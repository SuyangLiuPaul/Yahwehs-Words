#!/usr/bin/env bash
# Upload only; does not submit review, distribute to testers or publish.
set -euo pipefail
platform="${1:-}"
package="${2:-}"
case "$platform:$package" in
  ios:*.ipa|macos:*.pkg) ;;
  *) echo 'Usage: tools/apple_upload.sh ios App.ipa | macos App.pkg' >&2; exit 2;;
esac
[ -f "$package" ] || { echo 'Package missing' >&2; exit 2; }
case "$package" in *unsigned*) echo 'Unsigned package refused' >&2; exit 2;; esac
: "${ASC_KEY_ID:?set ASC_KEY_ID}" "${ASC_ISSUER_ID:?set ASC_ISSUER_ID}"
[ -f "$HOME/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID}.p8" ] || { echo 'Existing ASC key missing' >&2; exit 2; }
# Xcode 27 altool's live help defines positional package validation/upload.
# Legacy man7 pages describe a different implementation; refuse that CLI here.
help="$(xcrun altool --help 2>&1)"
[[ "$help" == *"altool --validate-app <file>"* ]] || { echo 'Modern altool positional validation is required' >&2; exit 2; }
# Server validation checks signatures, provisioning and the real package metadata;
# a filename alone never proves distribution signing. Failure stops before upload.
xcrun altool --validate-app "$package" --api-key "$ASC_KEY_ID" --api-issuer "$ASC_ISSUER_ID" --output-format json
xcrun altool --upload-package "$package" --api-key "$ASC_KEY_ID" --api-issuer "$ASC_ISSUER_ID" --output-format json
echo 'Upload command completed. Confirm processing separately in App Store Connect.'
