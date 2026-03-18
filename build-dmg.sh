#!/bin/bash
set -euo pipefail

APP_NAME="Claude Usage Mini"
BUILD_DIR=".build"
APP_BUNDLE="$BUILD_DIR/app/$APP_NAME.app"
DMG_OUTPUT="$BUILD_DIR/ClaudeUsageMini.dmg"
BG_IMAGE="$BUILD_DIR/dmg-bg.png"

# Step 1: Build the app
echo "Building app..."
./build-app.sh

# Step 2: Generate background with arrow if not exists
if [ ! -f "$BG_IMAGE" ]; then
    echo "Generating DMG background..."
    swift /tmp/gen_bg.swift 2>/dev/null || true
fi

# Step 3: Create DMG with create-dmg
echo "Creating DMG..."
rm -f "$DMG_OUTPUT"

create-dmg \
    --volname "$APP_NAME" \
    --background "$BG_IMAGE" \
    --window-pos 200 120 \
    --window-size 600 400 \
    --icon-size 128 \
    --icon "$APP_NAME.app" 150 200 \
    --app-drop-link 450 200 \
    --hide-extension "$APP_NAME.app" \
    --no-internet-enable \
    "$DMG_OUTPUT" \
    "$APP_BUNDLE" \
    || true  # create-dmg returns non-zero if codesign skipped

if [ -f "$DMG_OUTPUT" ]; then
    echo ""
    echo "DMG created: $DMG_OUTPUT"
    echo "  open $DMG_OUTPUT"
else
    echo "ERROR: DMG creation failed"
    exit 1
fi
