#!/bin/bash
set -euo pipefail

[[ $# -eq 1 ]] || { echo 'Expected archive path' >&2; exit 1; }
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
app="$1/Products/Applications/MoneySnap.app"
entitlements="$script_dir/../MoneySnap/MoneySnap.entitlements"
[[ -d "$app" && -f "$entitlements" ]] || exit 1

# This is an intermediate archive signature solely to carry capabilities into
# exportArchive. It is NOT a distribution signature and must never be uploaded.
# Export re-signs with Apple Distribution; verify_testflight_signing.py enforces
# that certificate trust, App Store profile and all capabilities before upload.
/usr/bin/codesign --force --sign - --entitlements "$entitlements" "$app"
/usr/bin/codesign --verify --deep --strict "$app"
/usr/bin/codesign -d --entitlements :- "$app" 2>/dev/null | python3 -c '
import plistlib, sys
entitlements = plistlib.loads(sys.stdin.buffer.read())
if entitlements.get("com.apple.developer.applesignin") != ["Default"]:
    raise SystemExit("Archive Apple login entitlement missing")
print("Archive Apple login entitlement preserved; distribution export still required")
'
