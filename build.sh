#!/bin/bash
# Builds a universal (arm64 + x86_64) build/ScreenCrop.app, signed with the "ScreenCrop Local Signing"
# certificate when the keychain has it (see README), else with an ad-hoc signature.
# Set VERSION (for example 0.2.0) to stamp the bundle version.
set -euo pipefail
cd "$(dirname "$0")"

for arch in arm64 x86_64; do
    swift build -c release --triple "$arch-apple-macosx14.0"
done

app=build/ScreenCrop.app
/bin/rm -rf "$app" build/AppIcon.iconset
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" build/AppIcon.iconset
lipo -create -output "$app/Contents/MacOS/ScreenCrop" \
    .build/arm64-apple-macosx/release/ScreenCrop \
    .build/x86_64-apple-macosx/release/ScreenCrop
/bin/cp Info.plist "$app/Contents/"

for px in 16 32 128 256 512; do
    sips -z $px $px Resources/AppIcon.png --out "build/AppIcon.iconset/icon_${px}x${px}.png" >/dev/null
    sips -z $((px * 2)) $((px * 2)) Resources/AppIcon.png --out "build/AppIcon.iconset/icon_${px}x${px}@2x.png" >/dev/null
done
iconutil -c icns build/AppIcon.iconset -o "$app/Contents/Resources/AppIcon.icns"

if [[ -n "${VERSION:-}" ]]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$app/Contents/Info.plist"
fi

# A stable local identity keeps Screen Recording and Accessibility permissions across rebuilds.
identity="ScreenCrop Local Signing"
security find-certificate -c "$identity" >/dev/null 2>&1 || identity="-"
codesign --force --sign "$identity" "$app"
echo "Built $app"
