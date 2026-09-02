# Shared transactional-write helpers for editing the user's
# omarchy-menu.jsonc extensions file. Sourced (not executed) by
# omarchy-theme-store-ensure-menu-entry and scripts/uninstall.sh so both the
# install-time add and the uninstall-time removal apply the same safety
# discipline to a file this plugin does not own.
#
# Usage:
#   menu_txn_dir_guard "$MENU_DIR" || exit 1
#   menu_txn_file_guard "$MENU_EXT" || exit 1
#   work=$(menu_txn_new_tmp "$MENU_DIR") || exit 1
#   ...write the new contents to "$work"...
#   menu_txn_commit "$MENU_EXT" "$work" || exit 1

MENU_TXN_MAX_BYTES=$((1024 * 1024))
MENU_TXN_VALIDATOR="$(dirname "${BASH_SOURCE[0]}")/omarchy-theme-store-validate-jsonc"

menu_txn_fail() {
  echo "theme-store-menu-txn: $*" >&2
  return 1
}

# Refuses to operate through a symlinked or not-our-own directory — a
# swapped parent could otherwise redirect the write outside the user's
# config, or make it land somewhere another user on the box controls.
menu_txn_dir_guard() {
  local dir="$1"
  [[ ! -L $dir ]] || { menu_txn_fail "refusing to write through symlinked directory: $dir"; return 1; }
  mkdir -p -- "$dir"
  [[ ! -L $dir ]] || { menu_txn_fail "refusing to write through symlinked directory: $dir"; return 1; }
  local owner
  owner=$(stat -c%u -- "$dir") || { menu_txn_fail "cannot stat $dir"; return 1; }
  (( owner == EUID )) || { menu_txn_fail "$dir is not owned by the current user"; return 1; }
  return 0
}

# Refuses to follow a symlinked target, a non-regular file (FIFO/device), a
# file owned by someone else, or a file far larger than any real menu
# extensions file should be.
menu_txn_file_guard() {
  local file="$1"
  [[ -e $file ]] || return 0
  [[ ! -L $file ]] || { menu_txn_fail "refusing to follow symlink: $file"; return 1; }
  [[ -f $file ]] || { menu_txn_fail "not a regular file: $file"; return 1; }
  local size owner
  read -r size owner < <(stat -c'%s %u' -- "$file") || { menu_txn_fail "cannot stat $file"; return 1; }
  (( owner == EUID )) || { menu_txn_fail "$file is not owned by the current user"; return 1; }
  (( size <= MENU_TXN_MAX_BYTES )) || {
    menu_txn_fail "$file is larger than expected ($size bytes); refusing to edit"
    return 1
  }
  return 0
}

# An unpredictable temp filename in the same directory as the target, so a
# predictable ".tmp" path can't be pre-created or symlinked by anything else
# with write access to that directory.
menu_txn_new_tmp() {
  local dir="$1"
  mktemp "$dir/.omarchy-menu.jsonc.XXXXXX"
}

# Validates the staged file, preserves the previous valid file as a ".bak",
# and atomically replaces the target. Leaves the target untouched and
# removes the staged file on any failure, so a bad transaction never
# corrupts what was there before.
menu_txn_commit() {
  local target="$1" work="$2"

  if ! python3 "$MENU_TXN_VALIDATOR" "$work" >/dev/null 2>&1; then
    menu_txn_fail "generated menu file failed validation; leaving $target unchanged"
    rm -f -- "$work"
    return 1
  fi

  if [[ -f $target ]]; then
    cp -p -- "$target" "$target.bak" 2>/dev/null || true
    chmod --reference="$target" "$work" 2>/dev/null || true
  fi

  mv -- "$work" "$target"
}
