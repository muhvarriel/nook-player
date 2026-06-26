#!/bin/bash
set -e

echo "Building NookPlayer via SPM..."
swift build -c release

APP_DIR="build/NookPlayer.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"
RESOURCES_DIR="$APP_DIR/Contents/Resources"

echo "Creating App Bundle..."
rm -rf "build"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

cp -f ".build/release/NookPlayer" "$MACOS_DIR/NookPlayer"
cp -f "Packaging/Info.plist" "$APP_DIR/Contents/Info.plist"
cp -R Resources/* "$RESOURCES_DIR/"

# Self-sign the app bundle
if [ -f "Packaging/entitlements.plist" ]; then
    echo "Signing app bundle with entitlements..."
    codesign --force --sign - --entitlements Packaging/entitlements.plist "$MACOS_DIR/NookPlayer"
    codesign --force --sign - "$APP_DIR"
else
    echo "Signing app bundle..."
    codesign --force --sign - "$MACOS_DIR/NookPlayer"
    codesign --force --sign - "$APP_DIR"
fi

echo "NookPlayer.app built successfully at build/NookPlayer.app"
