#!/bin/bash
# Reverses install.sh: removes the plugin symlink and its menu entry, then
# asks the running omarchy-shell to drop it. Does not delete the cached
# catalog/thumbnails in ~/.cache/omarchy/theme-store — pass --purge-cache too.
set -euo pipefail

PLUGIN_ID="community.theme-store"
PLUGIN_LINK="$HOME/.config/omarchy/plugins/$PLUGIN_ID"
MENU_EXT="$HOME/.config/omarchy/extensions/omarchy-menu.jsonc"
MENU_ENTRY_ID="install.theme-store"
CACHE_DIR="$HOME/.cache/omarchy/theme-store"

if [[ -L $PLUGIN_LINK ]]; then
  rm "$PLUGIN_LINK"
  echo "Removed $PLUGIN_LINK"
elif [[ -e $PLUGIN_LINK ]]; then
  echo "$PLUGIN_LINK is a real directory (installed via 'omarchy plugin add')."
  echo "This only cleans up the menu entry/cache — run 'omarchy plugin remove $PLUGIN_ID' too."
else
  echo "$PLUGIN_LINK not found (already removed?)"
fi

if [[ -f $MENU_EXT ]] && grep -q "\"$MENU_ENTRY_ID\"" "$MENU_EXT"; then
  grep -v "\"$MENU_ENTRY_ID\"" "$MENU_EXT" > "$MENU_EXT.tmp"
  mv "$MENU_EXT.tmp" "$MENU_EXT"
  echo "Removed '$MENU_ENTRY_ID' from $MENU_EXT"
fi

if command -v omarchy-shell >/dev/null 2>&1; then
  omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
  omarchy menu refresh >/dev/null 2>&1 || true
fi

if [[ ${1:-} == "--purge-cache" ]]; then
  rm -rf "$CACHE_DIR"
  echo "Purged $CACHE_DIR"
fi

echo "Done."
