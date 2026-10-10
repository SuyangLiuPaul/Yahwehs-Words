#!/usr/bin/env bash
# Compatibility entry point; key remains in its existing local directory.
set -euo pipefail
exec bash "$(dirname "$0")/apple_upload.sh" ios "${1:-}"
