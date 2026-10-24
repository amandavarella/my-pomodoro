#!/bin/sh
# Builds a Release Pomodoro.app and packages it as dist/Pomodoro-<version>.dmg.
# The app is ad-hoc signed and not notarized (no Developer ID certificate),
# so first launch needs the Gatekeeper steps in the README.
set -eu

cd "$(dirname "$0")/.."

xcodebuild -project Pomodoro.xcodeproj -scheme Pomodoro -configuration Release \
  -derivedDataPath build/release ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO clean build | tail -n 3

APP=build/release/Build/Products/Release/Pomodoro.app
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP/Contents/Info.plist")

codesign --force --deep --sign - "$APP"
codesign --verify --strict "$APP"

STAGE=build/dmg
rm -rf "$STAGE" && mkdir -p "$STAGE" dist
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

DMG="dist/Pomodoro-$VERSION.dmg"
rm -f "$DMG"
hdiutil create -volname "Pomodoro $VERSION" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null

echo "Built $DMG"
shasum -a 256 "$DMG"
