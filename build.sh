#!/bin/bash
set -e
cd "$(dirname "$0")"

echo "Generating Xcode project..."
xcodegen generate

echo "Building Island..."
xcodebuild \
  -project Island.xcodeproj \
  -scheme Island \
  -configuration Release \
  -derivedDataPath build/DerivedData \
  CONFIGURATION_BUILD_DIR="$(pwd)/build/Release" \
  build | xcpretty || true

APP="build/Release/Island.app"
if [ ! -d "$APP" ]; then
  echo "Build failed — $APP not found."
  exit 1
fi

echo "Done! App is at $APP"
