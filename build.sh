#!/bin/bash
set -e
cd "$(dirname "$0")"

echo "Generating Xcode project..."
xcodegen generate

echo "Building Island (unsigned)..."
xcodebuild \
  -project Island.xcodeproj \
  -scheme Island \
  -configuration Release \
  -derivedDataPath build/DerivedData \
  CONFIGURATION_BUILD_DIR="$(pwd)/build/Release" \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  build 2>&1 | grep -E "error:|warning:|BUILD" || true

APP="build/Release/Island.app"
if [ ! -f "$APP/Contents/MacOS/Island" ]; then
  echo "Build failed — binary not found."
  exit 1
fi

echo "Building XPC Helper in /tmp..."
XPC_TMP="/tmp/IslandXPC_$$"
mkdir -p "$XPC_TMP/IslandHelper.xpc/Contents/MacOS"
swiftc "App/XPCHelper/main.swift" \
  -o "$XPC_TMP/IslandHelper.xpc/Contents/MacOS/IslandHelper" \
  -target arm64-apple-macos14.0 \
  -framework Foundation 2>&1
cp App/XPCHelper/Info.plist "$XPC_TMP/IslandHelper.xpc/Contents/Info.plist"

# Add XPC to app bundle
mkdir -p "$APP/Contents/XPCServices"
cp -R "$XPC_TMP/IslandHelper.xpc" "$APP/Contents/XPCServices/"
rm -rf "$XPC_TMP"

# Sign everything
IDENTITY=$(security find-identity -v -p codesigning | grep "Apple Development" | head -1 | awk -F'"' '{print $2}')
if [ -n "$IDENTITY" ]; then
  echo "Signing with: $IDENTITY"
  # Copy through /tmp to strip provenance xattrs
  SIGN_TMP="/tmp/Island_sign_$$"
  rm -rf "$SIGN_TMP"
  mkdir -p "$SIGN_TMP/Island.app/Contents/MacOS"
  mkdir -p "$SIGN_TMP/Island.app/Contents/XPCServices"
  cat "$APP/Contents/MacOS/Island" > "$SIGN_TMP/Island.app/Contents/MacOS/Island"
  chmod +x "$SIGN_TMP/Island.app/Contents/MacOS/Island"
  cat "$APP/Contents/Info.plist" > "$SIGN_TMP/Island.app/Contents/Info.plist"
  cat "$APP/Contents/PkgInfo" > "$SIGN_TMP/Island.app/Contents/PkgInfo" 2>/dev/null || true
  if [ -d "$APP/Contents/Resources" ]; then
    mkdir -p "$SIGN_TMP/Island.app/Contents/Resources"
    for f in "$APP/Contents/Resources/"*; do
      [ -f "$f" ] && cat "$f" > "$SIGN_TMP/Island.app/Contents/Resources/$(basename "$f")"
    done
  fi
  cp -R "$APP/Contents/XPCServices/IslandHelper.xpc" "$SIGN_TMP/Island.app/Contents/XPCServices/"
  xattr -cr "$SIGN_TMP" 2>/dev/null || true
  codesign --force --sign "$IDENTITY" "$SIGN_TMP/Island.app/Contents/XPCServices/IslandHelper.xpc"
  codesign --force --sign "$IDENTITY" "$SIGN_TMP/Island.app"
  rm -rf "$APP"
  mv "$SIGN_TMP/Island.app" "$APP"
  rm -rf "$SIGN_TMP"
else
  echo "No signing identity found"
fi

echo "Done! App is at $APP"
