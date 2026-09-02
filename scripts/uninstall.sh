#!/bin/bash
# Reverses install.sh: removes the plugin symlink and its menu entry, then
# asks the running omarchy-shell to drop it. Does not delete the cached
# catalog/thumbnails in ~/.cache/omarchy/theme-store — pass --purge-cache too.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PLUGIN_ID="community.theme-store"
PLUGIN_LINK="$HOME/.config/omarchy/plugins/$PLUGIN_ID"
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

# Same descriptor-safe, validated, backed-up transaction as the install-time
# add — see omarchy-theme-store-menu-txn.
if python3 "$SCRIPT_DIR/../bin/omarchy-theme-store-menu-txn" remove-entry | grep -qx removed; then
  echo "Removed the menu entry."
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
