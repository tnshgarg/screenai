#!/bin/zsh
# Build a distributable screenAI DMG: app with the daemon bundled inside,
# a one-double-click installer, and an Applications shortcut.
set -e
cd "$(dirname "$0")/.."

echo "── building app ──"
(cd ui && ./build.sh)

# read the version AFTER the build — the pre-existing bundle may be stale
VERSION=$(defaults read "$(pwd)/ui/screenAI.app/Contents/Info" CFBundleShortVersionString 2>/dev/null || echo "0.1.0")

echo "── bundling daemon into the app ──"
RES="ui/screenAI.app/Contents/Resources/daemon"
rm -rf "$RES"
mkdir -p "$RES"
cp -R screenai "$RES/screenai"
find "$RES" -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
cp scripts/install.sh "$RES/install.sh"
chmod +x "$RES/install.sh"
codesign --force --deep --sign - ui/screenAI.app

echo "── staging ──"
STAGE=$(mktemp -d)
cp -R ui/screenAI.app "$STAGE/"
ln -s /Applications "$STAGE/Applications"
cat > "$STAGE/Install screenAI.command" <<'EOF'
#!/bin/zsh
# Double-click me after dragging screenAI.app into Applications.
exec /Applications/screenAI.app/Contents/Resources/daemon/install.sh
EOF
chmod +x "$STAGE/Install screenAI.command"

DMG="dist/screenAI-$VERSION.dmg"
mkdir -p dist
rm -f "$DMG"
hdiutil create -volname "screenAI" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"
# Stable-named copy so the landing page can link a permanent direct-download URL
# (github.com/.../releases/latest/download/screenAI.dmg) that never changes per version.
STABLE="dist/screenAI.dmg"
cp -f "$DMG" "$STABLE"
echo "✓ $DMG"
echo "✓ $STABLE (stable name for the landing-page direct link)"
echo ""
echo "Ship it: gh release create v$VERSION $DMG $STABLE --title \"screenAI $VERSION\" --notes \"...\""
echo "(upload BOTH: screenAI.dmg keeps the landing-page download link working)"
echo "(installed apps check GitHub Releases daily and offer the update in the menu bar)"
