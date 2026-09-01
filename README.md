# Omarchy Theme Store

A Quickshell plugin for [Omarchy](https://omarchy.org) that turns
[omarchy.org/themes](https://omarchy.org/themes/) into a fullscreen gallery
inside the Omarchy menu: `Super + Space` → `Install` → `Omarchy Theme Store`.

- Browse every community theme as thumbnail cards, filter by typing.
- Press `Enter` on a theme to see a full-size preview with **Back** and
  **Install** buttons.
- **Install** opens a floating terminal that runs `omarchy-theme-install
  <repo-url>` — Omarchy's own theme installer.

## How it works

- `bin/omarchy-theme-store-fetch` scrapes omarchy.org/themes/ (it's static
  HTML, no API) and caches the parsed catalog + thumbnails under
  `~/.cache/omarchy/theme-store/`, refreshing at most once every 24h
  (`OMARCHY_THEME_STORE_TTL` env var to change that) unless a stale cache is
  all that's available.
- `ThemeStore.qml` / `ThemeStoreModel.js` are the plugin itself: a
  Quickshell `overlay` plugin (see `manifest.json`) built the same way as
  Omarchy's first-party `image-picker` and `reminders` plugins.
- Installing a theme just shells out to the same `omarchy-theme-install`
  script the built-in `Install > Style > Theme` menu item uses, so removal
  (`Remove > Theme`) and theme-switching behave exactly as they already do.

## Install

```sh
./scripts/install.sh
```

This symlinks the repo into `~/.config/omarchy/plugins/community.theme-store`,
adds an `install.theme-store` entry to
`~/.config/omarchy/extensions/omarchy-menu.jsonc`, and asks the running
`omarchy-shell` to rescan and enable it. Re-running it is safe.

The entry lands at the bottom of the `Install` list — the extensions file's
merge order is "all default items, then all extension items," with no
`after`/`index`/`priority` field, so a new id can't be inserted between two
existing rows. The only way to place it elsewhere is editing the
package-owned `/usr/share/omarchy/default/omarchy/omarchy-menu.jsonc`
directly, which `omarchy update` will silently revert.

## Uninstall

```sh
./scripts/uninstall.sh          # remove the plugin + menu entry
./scripts/uninstall.sh --purge-cache   # also delete the cached catalog/thumbnails
```

## Development

Edits to `ThemeStore.qml` take effect on the next summon — no rebuild step.
After changing `manifest.json` or adding/removing files, run:

```sh
omarchy-shell shell rescanPlugins
```

Summon it directly for testing without going through the menu:

```sh
omarchy-shell shell summon community.theme-store '{}'
```
