#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$ROOT_DIR/GlassMark.xcodeproj"
SCHEME="GlassMark"
DERIVED_DATA="$ROOT_DIR/DerivedData"
CONFIGURATION="Debug"

if [[ ! -d "$PROJECT" ]]; then
  echo "Missing GlassMark.xcodeproj. Run: xcodegen generate"
  exit 1
fi

pkill -x Glassmark >/dev/null 2>&1 || true

xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED_DATA" \
  build

APP_PATH="$DERIVED_DATA/Build/Products/$CONFIGURATION/Glassmark.app"

case "${1:-}" in
  --verify)
    test -d "$APP_PATH"
    echo "Verified build artifact: $APP_PATH"
    ;;
  --logs)
    open -n "$APP_PATH"
    log stream --style compact --predicate 'process == "Glassmark"'
    ;;
  *)
    open -n "$APP_PATH"
    ;;
esac
