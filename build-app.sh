#!/bin/bash
set -euo pipefail

APP_NAME="Claude Usage Mini"
BUNDLE_ID="com.local.ClaudeUsageMini"
BUILD_DIR=".build/app"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

echo "Building..."
swift build -c release 2>&1

echo "Creating app bundle..."
rm -rf "$BUILD_DIR"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy binary
cp .build/release/ClaudeUsageMini "$APP_BUNDLE/Contents/MacOS/ClaudeUsageMini"

# Copy SPM resource bundle
RESOURCE_BUNDLE=$(find .build -path "*/release/ClaudeUsageMini_ClaudeUsageMini.bundle" -type d | head -1)
if [ -n "$RESOURCE_BUNDLE" ]; then
    cp -R "$RESOURCE_BUNDLE" "$APP_BUNDLE/Contents/Resources/"
    cp -R "$RESOURCE_BUNDLE"/* "$APP_BUNDLE/Contents/Resources/" 2>/dev/null || true
fi

# Copy icon
cp Sources/ClaudeUsageMini/Resources/AppIcon.icns "$APP_BUNDLE/Contents/Resources/" 2>/dev/null || true

# Create Info.plist
cat > "$APP_BUNDLE/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.local.ClaudeUsageMini</string>
    <key>CFBundleName</key>
    <string>Claude Usage Mini</string>
    <key>CFBundleDisplayName</key>
    <string>Claude Usage Mini</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleExecutable</key>
    <string>ClaudeUsageMini</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>LSUIElement</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>26.0</string>
</dict>
</plist>
PLIST

# Ad-hoc code sign
codesign --force --deep -s - "$APP_BUNDLE" 2>/dev/null || true

echo ""
echo "App bundle created at: $APP_BUNDLE"
echo ""
echo "To install:"
echo "  cp -R \"$APP_BUNDLE\" /Applications/"
echo ""
echo "To run directly:"
echo "  open \"$APP_BUNDLE\""
