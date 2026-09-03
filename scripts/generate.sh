#!/usr/bin/env bash
# Regenerate the Xcode project. Use this instead of a bare `xcodegen generate`.
#
# xcodegen 2.44.x mishandles the StoreKit configuration in the shared scheme:
#
#   * `run.storeKitConfiguration` is written into <LaunchAction> as
#     `../../SecondLook.storekit`. Xcode resolves that identifier relative to
#     SRCROOT (the folder holding SecondLook.xcodeproj), so `../../` points two
#     levels ABOVE the repo at a file that does not exist. Xcode then silently
#     ignores the missing config and the paywall shows "Plans couldn't be
#     loaded". The correct identifier is just `SecondLook.storekit`.
#   * `test.storeKitConfiguration` is dropped entirely - nothing is written into
#     <TestAction>, so `xcodebuild test` / Cmd-U gets no StoreKit config.
#
# This wrapper fixes both, idempotently. Only affects local StoreKit testing -
# the archive / App Store build never uses the .storekit file.
set -euo pipefail
cd "$(dirname "$0")/.."

xcodegen generate

SCHEME="SecondLook.xcodeproj/xcshareddata/xcschemes/SecondLook.xcscheme"
[ -f "$SCHEME" ] || { echo "warning: $SCHEME not found, skipping StoreKit patch" >&2; exit 0; }

python3 - "$SCHEME" <<'PY'
import sys, re

path = sys.argv[1]
xml = open(path).read()
ref = ('      <StoreKitConfigurationFileReference\n'
       '         identifier = "SecondLook.storekit">\n'
       '      </StoreKitConfigurationFileReference>\n')
changed = False

# 1. LaunchAction: correct whatever path xcodegen emitted.
new = re.sub(r'<StoreKitConfigurationFileReference\s+identifier = "[^"]*SecondLook\.storekit">',
             '<StoreKitConfigurationFileReference\n         identifier = "SecondLook.storekit">',
             xml)
if new != xml:
    xml, changed = new, True

# 2. TestAction: inject the reference if xcodegen left it out.
def patch_testaction(m):
    global changed
    block = m.group(0)
    if 'StoreKitConfigurationFileReference' in block:
        return block
    changed = True
    return block.replace('</Testables>\n', '</Testables>\n' + ref, 1)

xml = re.sub(r'<TestAction\b.*?</TestAction>', patch_testaction, xml, flags=re.S)

if changed:
    open(path, 'w').write(xml)
    print(f"patched StoreKit config (LaunchAction + TestAction) in {path}")
else:
    print(f"StoreKit config already correct in {path}")
PY
