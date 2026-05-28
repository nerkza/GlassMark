#!/usr/bin/env bash
set -euo pipefail

# Builds a notarized, stapled, zipped Glassmark.app for direct download (GitHub
# Releases). This is the build that contains the in-app updater (the App Store
# build does NOT — it's archived from Xcode on the Release config).
#
# Prerequisites (one-time):
#   1. A "Developer ID Application: Recurse LTD" certificate in your keychain
#      (Xcode → Settings → Accounts → Manage Certificates → + → Developer ID Application).
#   2. A notarytool keychain profile (default name: glassmark-notary):
#        xcrun notarytool store-credentials glassmark-notary \
#          --key ~/.blitz/AuthKey_YWTDSUC357.p8 \
#          --key-id YWTDSUC357 \
#          --issuer <YOUR_ASC_ISSUER_ID>
#      (issuer id is in your App Store Connect API keys page / ~/.blitz config.)
#
# Usage:
#   script/release.sh                 # build, notarize, staple, zip
#   NOTARY_PROFILE=my-profile script/release.sh
#   script/release.sh --publish       # also create the GitHub release via gh

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

PROJECT="GlassMark.xcodeproj"
SCHEME="GlassMark"
CONFIG="ReleaseDirect"
TEAM_ID="R57FJUULSB"
NOTARY_PROFILE="${NOTARY_PROFILE:-glassmark-notary}"
BUILD_DIR="$ROOT_DIR/build/release"
PUBLISH=false
[[ "${1:-}" == "--publish" ]] && PUBLISH=true

if [[ ! -d "$PROJECT" ]]; then
  echo "Missing $PROJECT. Run: xcodegen generate"; exit 1
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' GlassMark/Resources/Info.plist)"
TAG="v$VERSION"
echo "▶︎ Releasing Glassmark $VERSION (tag $TAG), config $CONFIG"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
ARCHIVE="$BUILD_DIR/Glassmark.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
OPTS_PLIST="$BUILD_DIR/exportOptions.plist"

cat > "$OPTS_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>developer-id</string>
  <key>teamID</key><string>$TEAM_ID</string>
  <key>signingStyle</key><string>automatic</string>
</dict>
</plist>
PLIST

echo "▶︎ Archiving…"
xcodebuild archive \
  -project "$PROJECT" -scheme "$SCHEME" -configuration "$CONFIG" \
  -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates

echo "▶︎ Exporting (Developer ID)…"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportOptionsPlist "$OPTS_PLIST" \
  -exportPath "$EXPORT_DIR" \
  -allowProvisioningUpdates

APP="$EXPORT_DIR/Glassmark.app"
ZIP="$BUILD_DIR/Glassmark-$VERSION.zip"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "▶︎ Notarizing (profile: $NOTARY_PROFILE)…"
xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait

echo "▶︎ Stapling…"
xcrun stapler staple "$APP"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"   # re-zip the stapled app
xcrun stapler validate "$APP"

echo "✓ Built notarized: $ZIP"

if $PUBLISH; then
  echo "▶︎ Publishing GitHub release $TAG…"
  gh release create "$TAG" "$ZIP" \
    --title "Glassmark $VERSION" \
    --notes "Glassmark $VERSION. Download the zip, unzip, and drag Glassmark.app to /Applications."
  echo "✓ Published $TAG"
else
  echo "To publish: gh release create $TAG \"$ZIP\" --title \"Glassmark $VERSION\" --notes \"…\""
fi
