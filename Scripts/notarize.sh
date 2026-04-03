#!/bin/bash
set -euo pipefail

# ═══════════════════════════════════════════════════════════════════════
# notarize.sh — Notarize Maclaque.dmg with Apple
# Usage: ./Scripts/notarize.sh
#
# Required environment variables:
#   NOTARIZATION_APPLE_ID    — Apple ID email
#   NOTARIZATION_PASSWORD    — App-specific password
#   APPLE_DEVELOPER_TEAM_ID  — Team ID
# ═══════════════════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DMG_PATH="$PROJECT_DIR/dist/Maclaque-v1.0.dmg"

APPLE_ID="${NOTARIZATION_APPLE_ID:?Set NOTARIZATION_APPLE_ID}"
PASSWORD="${NOTARIZATION_PASSWORD:?Set NOTARIZATION_PASSWORD}"
TEAM_ID="${APPLE_DEVELOPER_TEAM_ID:?Set APPLE_DEVELOPER_TEAM_ID}"

echo "╔═══════════════════════════════════════╗"
echo "║  Maclaque Notarization                ║"
echo "╚═══════════════════════════════════════╝"

if [ ! -f "$DMG_PATH" ]; then
    echo "✗ DMG not found: $DMG_PATH"
    echo "  Run ./Scripts/bundle.sh first."
    exit 1
fi

# ── Submit for notarization ─────────────────────────────────────────────
echo ""
echo "▸ Submitting for notarization..."
xcrun notarytool submit "$DMG_PATH" \
    --apple-id "$APPLE_ID" \
    --password "$PASSWORD" \
    --team-id "$TEAM_ID" \
    --wait

# ── Staple the ticket ──────────────────────────────────────────────────
echo ""
echo "▸ Stapling notarization ticket..."
xcrun stapler staple "$DMG_PATH"

# ── Verify ──────────────────────────────────────────────────────────────
echo ""
echo "▸ Verifying..."
if ! spctl -a -vvv --type install "$DMG_PATH" 2>&1; then
    echo ""
    echo "✗ Verification FAILED. Check notarization status with:"
    echo "  xcrun notarytool log <submission-id> --apple-id $APPLE_ID --team-id $TEAM_ID"
    exit 1
fi

echo ""
echo "✓ Notarization complete!"
echo "  DMG ready for distribution: $DMG_PATH"
