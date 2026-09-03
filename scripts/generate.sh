#!/usr/bin/env bash
# Regenerate the Xcode project. Use this instead of a bare `xcodegen generate`.
#
# xcodegen 2.44.x writes a broken relative path for the StoreKit configuration
# in the shared scheme (`../../SecondLook.storekit` instead of
# `SecondLook.storekit`), which makes the paywall show "Plans couldn't be
# loaded" when the app is run from Xcode. This wrapper fixes it. Only affects
# local StoreKit testing — the archive / App Store build never uses the
# .storekit file.
set -euo pipefail
cd "$(dirname "$0")/.."

xcodegen generate

SCHEME="SecondLook.xcodeproj/xcshareddata/xcschemes/SecondLook.xcscheme"
if [ -f "$SCHEME" ]; then
  sed -i '' 's|identifier = "../../SecondLook.storekit"|identifier = "SecondLook.storekit"|' "$SCHEME"
  echo "patched StoreKit config path in $SCHEME"
fi
