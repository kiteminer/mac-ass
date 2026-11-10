#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
APP="$PWD/build/MacAss.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$(swift build -c release --show-bin-path)/MacAss" "$APP/Contents/MacOS/MacAss"
cp scripts/Info.plist "$APP/Contents/Info.plist"
cp LICENSE "$APP/Contents/Resources/LICENSE"
cp THIRD_PARTY_NOTICES.md "$APP/Contents/Resources/THIRD_PARTY_NOTICES.md"
cp -R ThirdPartyLicenses "$APP/Contents/Resources/"
codesign --force --deep --sign - "$APP"
echo "Built: $APP"
