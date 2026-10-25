#!/bin/bash
# Builds build/ScreenCrop.app with an ad-hoc signature.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release
app=build/ScreenCrop.app
/bin/rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
/bin/cp .build/release/ScreenCrop "$app/Contents/MacOS/"
/bin/cp Info.plist "$app/Contents/"
codesign --force --sign - "$app"
echo "Built $app"
