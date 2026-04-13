#!/bin/bash
set -euo pipefail

# ═══════════════════════════════════════════════════════════════════════
# bundle.sh — Build, sign, and package Maclaque.app + MaclaqueDaemon
# Usage: ./Scripts/bundle.sh
# ═══════════════════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/.build/release"
APP_NAME="Maclaque"
APP_BUNDLE="$PROJECT_DIR/dist/$APP_NAME.app"
DMG_NAME="$APP_NAME-v1.0.dmg"
DMG_PATH="$PROJECT_DIR/dist/$DMG_NAME"

# ── Config (set via environment or edit here) ───────────────────────────
DEVELOPER_ID_CERT="${DEVELOPER_ID_CERT_NAME:-Developer ID Application}"
TEAM_ID="${APPLE_DEVELOPER_TEAM_ID:-}"

echo "╔═══════════════════════════════════════╗"
echo "║  Maclaque Build & Bundle              ║"
echo "╚═══════════════════════════════════════╝"

# ── Step 1: Build ───────────────────────────────────────────────────────
echo ""
echo "▸ Building release..."
cd "$PROJECT_DIR"
swift build -c release 2>&1

echo "✓ Build succeeded"

# ── Step 2: Create .app bundle ──────────────────────────────────────────
echo ""
echo "▸ Creating app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources/Packs"
mkdir -p "$APP_BUNDLE/Contents/Library/LaunchDaemons"

# Copy binaries
if [ ! -f "$BUILD_DIR/Maclaque" ]; then
    echo "✗ ERROR: Maclaque app binary not found at $BUILD_DIR/Maclaque"
    exit 1
fi
cp "$BUILD_DIR/Maclaque" "$APP_BUNDLE/Contents/MacOS/Maclaque"
cp "$BUILD_DIR/MaclaqueDaemon" "$APP_BUNDLE/Contents/MacOS/MaclaqueDaemon"

# Copy resources
cp -R "$PROJECT_DIR/Resources/Packs/"* "$APP_BUNDLE/Contents/Resources/Packs/" 2>/dev/null || true
cp "$PROJECT_DIR/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns" 2>/dev/null || true

# Copy daemon plist
cp "$PROJECT_DIR/Daemon/com.maclaque.daemon.plist" "$APP_BUNDLE/Contents/Library/LaunchDaemons/"

# Create Info.plist
cat > "$APP_BUNDLE/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>Maclaque</string>
    <key>CFBundleDisplayName</key>
    <string>Maclaque</string>
    <key>CFBundleIdentifier</key>
    <string>com.maclaque.app</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleExecutable</key>
    <string>Maclaque</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>© 2026 Maclaque. Tous droits réservés.</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.entertainment</string>
</dict>
</plist>
PLIST

echo "✓ App bundle created"

# ── Step 3: Code signing ────────────────────────────────────────────────
echo ""
echo "▸ Code signing..."
if [ -n "$TEAM_ID" ]; then
    # Create production entitlements (no get-task-allow)
    cat > "$PROJECT_DIR/dist/app.entitlements" << 'ENT'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <true/>
</dict>
</plist>
ENT
    cat > "$PROJECT_DIR/dist/daemon.entitlements" << 'ENT'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <true/>
</dict>
</plist>
ENT

    # Sign daemon first, then app
    codesign --force --sign "$DEVELOPER_ID_CERT" \
        --options runtime \
        --timestamp \
        --entitlements "$PROJECT_DIR/dist/daemon.entitlements" \
        "$APP_BUNDLE/Contents/MacOS/MaclaqueDaemon"

    codesign --force --sign "$DEVELOPER_ID_CERT" \
        --options runtime \
        --timestamp \
        --entitlements "$PROJECT_DIR/dist/app.entitlements" \
        "$APP_BUNDLE"

    rm -f "$PROJECT_DIR/dist/app.entitlements" "$PROJECT_DIR/dist/daemon.entitlements"
    echo "✓ Code signed with: $DEVELOPER_ID_CERT"
else
    echo "⚠ APPLE_DEVELOPER_TEAM_ID not set — skipping code signing"
    echo "  Set DEVELOPER_ID_CERT_NAME and APPLE_DEVELOPER_TEAM_ID to enable"
fi

# ── Step 4: Create DMG ──────────────────────────────────────────────────
echo ""
echo "▸ Creating DMG..."
rm -f "$DMG_PATH"
mkdir -p "$PROJECT_DIR/dist"

# Create a temporary DMG folder
DMG_TEMP="$PROJECT_DIR/dist/dmg_temp"
rm -rf "$DMG_TEMP"
mkdir -p "$DMG_TEMP"
cp -R "$APP_BUNDLE" "$DMG_TEMP/"
ln -s /Applications "$DMG_TEMP/Applications"

hdiutil create -volname "$APP_NAME" \
    -srcfolder "$DMG_TEMP" \
    -ov -format UDZO \
    "$DMG_PATH" 2>/dev/null

rm -rf "$DMG_TEMP"

# Sign the DMG itself (required for notarization to pass spctl)
if [ -n "$TEAM_ID" ]; then
    codesign --force --sign "$DEVELOPER_ID_CERT" --timestamp "$DMG_PATH"
    echo "✓ DMG created and signed: $DMG_PATH"
else
    echo "✓ DMG created (unsigned): $DMG_PATH"
fi

# ── Done ────────────────────────────────────────────────────────────────
echo ""
echo "╔═══════════════════════════════════════╗"
echo "║  Build complete!                      ║"
echo "║  → $DMG_PATH"
echo "╚═══════════════════════════════════════╝"
echo ""
echo "Next steps:"
echo "  1. Run ./Scripts/notarize.sh to notarize the DMG"
echo "  2. Install daemon: sudo cp dist/Maclaque.app/Contents/MacOS/MaclaqueDaemon /usr/local/bin/"
echo "  3. Load daemon: sudo launchctl load /Library/LaunchDaemons/com.maclaque.daemon.plist"
