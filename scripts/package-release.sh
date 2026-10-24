#!/bin/bash
# Builds a Developer ID signed, notarized Pomodoro.app and packages it as
# dist/Pomodoro-<version>.dmg.
#
# Signing and notarization go through Xcode's cloud signing with the Apple
# account signed in under Xcode > Settings > Accounts, so no local Developer ID
# certificate or notarytool password is needed. Set TEAM_ID to use another team.
set -euo pipefail

cd "$(dirname "$0")/.."

TEAM_ID=${TEAM_ID:-4L7FK6FA5W}
OUT=build/release
ARCHIVE=$OUT/Pomodoro.xcarchive
rm -rf "$OUT" && mkdir -p "$OUT" dist

xcodebuild -project Pomodoro.xcodeproj -scheme Pomodoro -configuration Release \
  -archivePath "$ARCHIVE" -allowProvisioningUpdates \
  DEVELOPMENT_TEAM="$TEAM_ID" CODE_SIGN_STYLE=Automatic CODE_SIGN_IDENTITY="Apple Development" \
  ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO archive | tail -n 1

cat > "$OUT/upload.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>method</key><string>developer-id</string>
<key>teamID</key><string>$TEAM_ID</string>
<key>signingStyle</key><string>automatic</string>
<key>destination</key><string>upload</string>
</dict></plist>
EOF

echo "Uploading to Apple for notarization..."
xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportOptionsPlist "$OUT/upload.plist" \
  -exportPath "$OUT/upload" -allowProvisioningUpdates | tail -n 1

# Notarization usually takes a few minutes, occasionally much longer.
echo "Waiting for notarization..."
i=0
until xcodebuild -exportNotarizedApp -archivePath "$ARCHIVE" -exportPath "$OUT/notarized" >"$OUT/notarize.log" 2>&1; do
  if ! grep -q "not ready for distribution" "$OUT/notarize.log"; then
    cat "$OUT/notarize.log"
    exit 1
  fi
  i=$((i + 1))
  if [ "$i" -ge 240 ]; then
    echo "Gave up after an hour. Rerun: xcodebuild -exportNotarizedApp -archivePath $ARCHIVE -exportPath $OUT/notarized"
    exit 1
  fi
  sleep 15
done

APP=$OUT/notarized/Pomodoro.app
spctl --assess --type exec "$APP"
xcrun stapler validate "$APP" >/dev/null
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP/Contents/Info.plist")

STAGE=$OUT/dmg
mkdir -p "$STAGE"
ditto "$APP" "$STAGE/Pomodoro.app"
ln -s /Applications "$STAGE/Applications"

DMG="dist/Pomodoro-$VERSION.dmg"
rm -f "$DMG"
hdiutil create -volname "Pomodoro $VERSION" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null

echo "Built $DMG"
shasum -a 256 "$DMG"
