#!/bin/bash
# Build "Polish Writer.app" and "Polish-Writer-<version>.dmg" from an installed Hammerspoon.app.
# Run on a Mac:   bash scripts/build-dmg.sh 1.0.0
# Needs: Hammerspoon in /Applications (brew install --cask hammerspoon), Xcode command line tools are NOT needed.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:-1.0.0}"
HS_APP="${HS_APP:-/Applications/Hammerspoon.app}"
OUT="$ROOT/dist"
APP="$OUT/Polish Writer.app"
PB=/usr/libexec/PlistBuddy

[ -d "$HS_APP" ] || { echo "✗ $HS_APP not found. Install it: brew install --cask hammerspoon"; exit 1; }

echo "→ Building Polish Writer $VERSION from $HS_APP"
rm -rf "$OUT"; mkdir -p "$OUT"
ditto "$HS_APP" "$APP"
R="$APP/Contents/Resources"
P="$APP/Contents/Info.plist"

# 1. Program files
mkdir -p "$R/polish"
cp "$ROOT"/polish/*.lua "$ROOT"/polish/*.html "$R/polish/"
cp "$ROOT/app/boot.lua" "$R/boot.lua"
cp "$ROOT/app/HAMMERSPOON-LICENSE.txt" "$R/"
cp "$ROOT/LICENSE" "$R/POLISH-WRITER-LICENSE.txt"

# 2. Start Polish Writer instead of ~/.hammerspoon/init.lua
python3 - "$R/setup.lua" "$ROOT/app/setup-patch.lua" <<'PY'
import sys
path, patch = sys.argv[1], open(sys.argv[2]).read()
s = open(path).read()
old = "return require'hs._coresetup'.setup(...)"
if old not in s:
    sys.exit("setup.lua format changed — update app/setup-patch.lua")
open(path, "w").write(s.replace(old, patch))
PY

# 3. Icon
TMP="$(mktemp -d)"; ICONSET="$TMP/AppIcon.iconset"; mkdir -p "$ICONSET"
SRC="$ROOT/app/icon-1024.png"
for s in 16 32 128 256 512; do
  sips -z $s $s "$SRC" --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
  sips -z $((s*2)) $((s*2)) "$SRC" --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$R/AppIcon.icns"
rm -f "$R/Assets.car"   # the old asset catalog would override the new icon

# 4. App identity (Info.plist)
$PB -c "Set :CFBundleName Polish Writer" "$P"
$PB -c "Add :CFBundleDisplayName string Polish Writer" "$P" 2>/dev/null || $PB -c "Set :CFBundleDisplayName Polish Writer" "$P"
$PB -c "Set :CFBundleIdentifier bd.amrita.polishwriter" "$P"
$PB -c "Set :CFBundleShortVersionString $VERSION" "$P"
$PB -c "Set :CFBundleVersion $VERSION" "$P"
$PB -c "Set :CFBundleIconFile AppIcon" "$P"
$PB -c "Delete :CFBundleIconName" "$P" 2>/dev/null || true
$PB -c "Delete :SUFeedURL" "$P" 2>/dev/null || true                  # never update itself into Hammerspoon
$PB -c "Set :SUEnableAutomaticChecks false" "$P" 2>/dev/null || true
$PB -c "Delete :CFBundleURLTypes" "$P" 2>/dev/null || true           # don't take over hammerspoon:// links
$PB -c "Delete :CFBundleDocumentTypes" "$P" 2>/dev/null || true
$PB -c "Delete :NSUserActivityTypes" "$P" 2>/dev/null || true
$PB -c "Add :NSHumanReadableCopyright string © 2026 Amrita Chandra Das · amrita.bd · Built on Hammerspoon (MIT)" "$P" 2>/dev/null \
  || $PB -c "Set :NSHumanReadableCopyright © 2026 Amrita Chandra Das · amrita.bd · Built on Hammerspoon (MIT)" "$P"
EXE="$($PB -c "Print :CFBundleExecutable" "$P")"
if [ "$EXE" != "Polish Writer" ]; then
  mv "$APP/Contents/MacOS/$EXE" "$APP/Contents/MacOS/Polish Writer"
  $PB -c "Set :CFBundleExecutable Polish Writer" "$P"
fi

# 5. Sign (ad-hoc: free, no Apple account; users right-click → Open the first time)
xattr -cr "$APP" 2>/dev/null || true   # some macOS-protected tags can't be removed; that's fine
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict "$APP" && echo "✓ Signed (ad-hoc)"

# 6. DMG with an Applications shortcut
STAGE="$TMP/dmg"; mkdir -p "$STAGE"
ditto "$APP" "$STAGE/Polish Writer.app"
ln -s /Applications "$STAGE/Applications"
cp "$ROOT/app/First time - how to open.txt" "$STAGE/"
DMG="$OUT/Polish-Writer-$VERSION.dmg"
hdiutil create -volname "Polish Writer" -srcfolder "$STAGE" -ov -format ULMO "$DMG" >/dev/null
rm -rf "$TMP"

echo "✓ App: $APP"
echo "✓ DMG: $DMG ($(du -h "$DMG" | cut -f1))"
