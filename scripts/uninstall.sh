#!/bin/bash
# Reverses install.sh: removes the plugin symlink and its menu entry, then
# asks the running omarchy-shell to drop it. Does not delete the cached
# catalog/thumbnails in ~/.cache/omarchy/theme-store — pass --purge-cache too.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../bin/theme-store-menu-txn.sh
source "$SCRIPT_DIR/../bin/theme-store-menu-txn.sh"

PLUGIN_ID="community.theme-store"
PLUGIN_LINK="$HOME/.config/omarchy/plugins/$PLUGIN_ID"
MENU_DIR="$HOME/.config/omarchy/extensions"
MENU_EXT="$MENU_DIR/omarchy-menu.jsonc"
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

if menu_txn_dir_guard "$MENU_DIR" && menu_txn_file_guard "$MENU_EXT" &&
  [[ -f $MENU_EXT ]] && grep -qF "\"$MENU_ENTRY_ID\"" "$MENU_EXT"; then
  work=$(menu_txn_new_tmp "$MENU_DIR")
  trap 'rm -f "$work"' EXIT
  grep -vF "\"$MENU_ENTRY_ID\"" "$MENU_EXT" > "$work"
  if menu_txn_commit "$MENU_EXT" "$work"; then
    echo "Removed '$MENU_ENTRY_ID' from $MENU_EXT"
  fi
  trap - EXIT
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
