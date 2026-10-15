#!/bin/bash
# Polish Writer uninstaller. Removes Polish Writer; leaves Hammerspoon itself installed.
HS="$HOME/.hammerspoon"

if [ -f "$HS/init.lua" ]; then
  sed -i '' '/-- Polish Writer/d; /require("polish")/d' "$HS/init.lua"
  echo "✓ Removed require(\"polish\") from init.lua"
fi
if [ -d "$HS/polish" ]; then
  mv "$HS/polish" "$HOME/.Trash/polish-writer-$(date +%s)"
  echo "✓ Moved $HS/polish to the Trash"
fi
security delete-generic-password -s polish-writer-api >/dev/null 2>&1 && echo "✓ Removed API key from Keychain"
osascript -e 'tell application "Hammerspoon" to quit' >/dev/null 2>&1 || true
echo "Done. (To remove Hammerspoon too, drag it from Applications to the Trash.)"
