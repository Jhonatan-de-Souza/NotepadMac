#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="NotepadMac"
BUILD_DIR="build"
APP_DIR="$BUILD_DIR/$APP_NAME.app"

echo "Cleaning previous build..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

echo "Compiling..."
swiftc -O -o "$APP_DIR/Contents/MacOS/$APP_NAME" Sources/main.swift -framework Cocoa

if [ -f "AppIcon.png" ]; then
    echo "Generating app icon..."
    ICONSET="$BUILD_DIR/AppIcon.iconset"
    rm -rf "$ICONSET"
    mkdir -p "$ICONSET"
    sips -z 16 16     AppIcon.png --out "$ICONSET/icon_16x16.png"      >/dev/null
    sips -z 32 32     AppIcon.png --out "$ICONSET/icon_16x16@2x.png"   >/dev/null
    sips -z 32 32     AppIcon.png --out "$ICONSET/icon_32x32.png"      >/dev/null
    sips -z 64 64     AppIcon.png --out "$ICONSET/icon_32x32@2x.png"   >/dev/null
    sips -z 128 128   AppIcon.png --out "$ICONSET/icon_128x128.png"    >/dev/null
    sips -z 256 256   AppIcon.png --out "$ICONSET/icon_128x128@2x.png" >/dev/null
    sips -z 256 256   AppIcon.png --out "$ICONSET/icon_256x256.png"    >/dev/null
    sips -z 512 512   AppIcon.png --out "$ICONSET/icon_256x256@2x.png" >/dev/null
    sips -z 512 512   AppIcon.png --out "$ICONSET/icon_512x512.png"    >/dev/null
    sips -z 1024 1024 AppIcon.png --out "$ICONSET/icon_512x512@2x.png" >/dev/null
    iconutil -c icns "$ICONSET" -o "$APP_DIR/Contents/Resources/AppIcon.icns"
fi

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.local.notepadmac</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>11.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Personal use</string>
</dict>
</plist>
PLIST

echo "APPL????" > "$APP_DIR/Contents/PkgInfo"

echo "Ad-hoc signing..."
codesign --force --deep --sign - "$APP_DIR"

echo "Done. Built app: $APP_DIR"
