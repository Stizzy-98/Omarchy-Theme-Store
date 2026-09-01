#!/bin/bash
# Links this checkout into Omarchy's shell plugin directory, registers
# "Install > Omarchy Theme Store" in the user's menu extensions, and asks
# the running omarchy-shell to pick it up. Safe to re-run.
set -euo pipefail

PLUGIN_ID="community.theme-store"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGINS_HOME="$HOME/.config/omarchy/plugins"
PLUGIN_LINK="$PLUGINS_HOME/$PLUGIN_ID"

fail() {
  echo "install.sh: $*" >&2
  exit 1
}

command -v omarchy-shell >/dev/null 2>&1 || fail "omarchy-shell not found; this must be run on an Omarchy install"

mkdir -p "$PLUGINS_HOME"
if [[ -L $PLUGIN_LINK ]]; then
  rm "$PLUGIN_LINK"
elif [[ -e $PLUGIN_LINK ]]; then
  fail "$PLUGIN_LINK already exists and is not a symlink; remove it manually first"
fi
ln -s "$REPO_DIR" "$PLUGIN_LINK"
echo "Linked $PLUGIN_LINK -> $REPO_DIR"

"$REPO_DIR/bin/omarchy-theme-store-ensure-menu-entry"

omarchy-shell shell rescanPlugins >/dev/null

discovered=0
for _ in $(seq 1 40); do
  if omarchy-plugin-list --json 2>/dev/null | jq -e --arg id "$PLUGIN_ID" 'any(.[]; .id == $id)' >/dev/null 2>&1; then
    discovered=1
    break
  fi
  sleep 0.05
done

if (( discovered )); then
  omarchy-plugin-enable "$PLUGIN_ID" >/dev/null 2>&1 || true
  echo "Enabled $PLUGIN_ID"
else
  echo "Warning: $PLUGIN_ID was not discovered after rescan; check omarchy-shell logs" >&2
fi

omarchy menu refresh >/dev/null 2>&1 || true

echo "Done. Open the menu with Super+Space -> Install -> Omarchy Theme Store."
