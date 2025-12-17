#!/bin/bash

set -e

APP_NAME="SSH Baddie"

# Extract version from pubspec.yaml
VERSION=$(grep '^version:' pubspec.yaml | sed 's/version: //' | cut -d'+' -f1)

if [ -z "$VERSION" ]; then
    echo "❌ Could not extract version from pubspec.yaml"
    exit 1
fi

DMG_NAME="SSH-Baddie-${VERSION}"
APP_PATH="build/macos/Build/Products/Release/${APP_NAME}.app"
DMG_DIR="dmg_temp"
DMG_OUTPUT="${DMG_NAME}.dmg"

echo "🔨 Creating DMG for ${APP_NAME} v${VERSION}..."

# Check if app exists
if [ ! -d "$APP_PATH" ]; then
    echo "❌ App not found at: $APP_PATH"
    echo "Run: flutter build macos --release"
    exit 1
fi

# Clean up any existing DMG
rm -f "$DMG_OUTPUT"
rm -rf "$DMG_DIR"

# Create temporary directory
mkdir -p "$DMG_DIR"

# Copy app to temp directory
echo "📦 Copying application..."
cp -R "$APP_PATH" "$DMG_DIR/"

# Create Applications symlink
echo "🔗 Creating Applications symlink..."
ln -s /Applications "$DMG_DIR/Applications"

# Create DMG
echo "💿 Creating DMG..."
hdiutil create -volname "$APP_NAME" \
    -srcfolder "$DMG_DIR" \
    -ov -format UDZO \
    "$DMG_OUTPUT"

# Clean up
rm -rf "$DMG_DIR"

echo "✅ DMG created: $DMG_OUTPUT"
echo "📏 Size: $(du -h "$DMG_OUTPUT" | cut -f1)"