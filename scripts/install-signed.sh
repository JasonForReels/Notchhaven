#!/usr/bin/env bash
# Builds Notchhaven and installs it to /Applications signed with a real identity.
# macOS ties privacy permissions (Calendar, Camera, Accessibility, ...) to the app's
# signature; an ad-hoc signature changes on every build, which resets them each time.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED="${DERIVED_DATA_PATH:-/private/tmp/NotchhavenDerivedData}"
BUILT="$DERIVED/Build/Products/Release/DynamicNotch.app"
TARGET="/Applications/Notchhaven.app"
ENTITLEMENTS="$ROOT/DynamicNotch/Application/DynamicNotch.entitlements"
IDENTITY="${SIGN_IDENTITY:-$(security find-identity -v -p codesigning | sed -n 's/.*"\(Apple Development:[^"]*\)".*/\1/p' | head -1)}"

[[ -n "$IDENTITY" ]] || { echo "No 'Apple Development' signing identity found. Set SIGN_IDENTITY." >&2; exit 1; }

if [[ "${SKIP_BUILD:-0}" != "1" ]]; then
  xcodebuild -project "$ROOT/DynamicNotch.xcodeproj" -scheme DynamicNotch -configuration Release \
    -destination 'platform=macOS' -derivedDataPath "$DERIVED" CODE_SIGNING_ALLOWED=NO build
fi

pkill -f "$TARGET/Contents/MacOS" 2>/dev/null || true
sleep 1
rm -rf "$TARGET"
ditto "$BUILT" "$TARGET"

# Sign nested code first, then the app, keeping its entitlements and hardened runtime.
find "$TARGET/Contents" \( -name '*.framework' -o -name '*.xpc' -o -name '*.app' -o -name '*.dylib' \) -print0 \
  | sort -rz | xargs -0 -I{} codesign --force --options runtime --timestamp=none -s "$IDENTITY" "{}"
codesign --force --options runtime --timestamp=none --entitlements "$ENTITLEMENTS" -s "$IDENTITY" "$TARGET"

codesign --verify --deep --strict "$TARGET"
echo "Installed $TARGET signed as: $IDENTITY"
codesign -dr - "$TARGET" 2>&1 | tail -1
