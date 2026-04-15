#!/bin/bash
set -e
cd "$(dirname "$0")/.."

APP="build/Release/Island.app"
DMG="build/Island-1.0.0.dmg"
STAGING="build/dmg_staging"

if [ ! -d "$APP" ]; then
  echo "App not built. Run ./build.sh first."
  exit 1
fi

rm -rf "$STAGING" "$DMG"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

hdiutil create \
  -volname "Island" \
  -srcfolder "$STAGING" \
  -ov -format ULFO \
  "$DMG"

rm -rf "$STAGING"
echo "DMG created at $DMG"
