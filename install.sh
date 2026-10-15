#!/bin/bash
# Polish Writer installer — run from the folder you downloaded:   bash install.sh
set -e

SRC="$(cd "$(dirname "$0")" && pwd)/polish"
HS="$HOME/.hammerspoon"
DEST="$HS/polish"

echo "→ Polish Writer installer"

# 1. Hammerspoon
if [ ! -d "/Applications/Hammerspoon.app" ]; then
  if command -v brew >/dev/null 2>&1; then
    echo "→ Installing Hammerspoon with Homebrew…"
    brew install --cask hammerspoon
  else
    echo "✗ Hammerspoon is not installed."
    echo "  Download it from https://www.hammerspoon.org, move it to Applications, then run: bash install.sh."
    exit 1
  fi
else
  echo "✓ Hammerspoon found"
fi

# 2. Copy files (keep the user's config.lua if updating)
mkdir -p "$DEST"
if [ -f "$DEST/config.lua" ]; then
  cp "$DEST/config.lua" "/tmp/polish-config-backup.lua"
fi
cp "$SRC"/*.lua "$SRC"/*.html "$DEST/"
if [ -f "/tmp/polish-config-backup.lua" ]; then
  mv "/tmp/polish-config-backup.lua" "$DEST/config.lua"
  echo "✓ Updated files (kept your config.lua)"
else
  cp "$DEST/config.example.lua" "$DEST/config.lua"
  echo "✓ Installed to $DEST"
fi

# 3. Load it from Hammerspoon's init.lua (without touching anything else in it)
touch "$HS/init.lua"
if ! grep -q 'require("polish")' "$HS/init.lua"; then
  printf '\n-- Polish Writer\nrequire("polish")\n' >> "$HS/init.lua"
  echo "✓ Added require(\"polish\") to $HS/init.lua"
else
  echo "✓ init.lua already loads Polish Writer"
fi

# 4. Start / reload Hammerspoon
if pgrep -xq Hammerspoon; then
  osascript -e 'tell application "Hammerspoon" to quit' >/dev/null 2>&1 || true
  sleep 2
fi
open -a Hammerspoon

cat <<'EOF'

✓ Done. Three things left (one time only):

  1. Allow Accessibility:  System Settings → Privacy & Security → Accessibility → turn on Hammerspoon
  2. Pick your AI provider: click ✍︎ in the menu bar → Edit settings… → set baseURL + model → save → ✍︎ → Reload
  3. Add your API key:      ✍︎ → Set API key…   then  ✍︎ → Test connection

Then select text in any app and press ⌥ Space (or click the ✨ button).
EOF
