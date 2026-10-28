#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

./build.sh --universal
APP_PATH="build/NotepadMac.app"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")
ARCHIVE="NotepadMac-universal.zip"
mkdir -p build/release
codesign --verify --deep --strict "$APP_PATH"
lipo "$APP_PATH/Contents/MacOS/NotepadMac" -verify_arch arm64 x86_64
# Exclude filesystem metadata so a public download contains only the app bundle.
ditto -c -k --norsrc --keepParent "$APP_PATH" "build/release/$ARCHIVE"
(cd build/release && shasum -a 256 "$ARCHIVE" > SHA256SUMS.txt)
echo "Version $VERSION release archive: build/release/$ARCHIVE"
