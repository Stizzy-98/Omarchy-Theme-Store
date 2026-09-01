# Omarchy Theme Store

A Quickshell plugin for [Omarchy](https://omarchy.org) that turns
[omarchy.org/themes](https://omarchy.org/themes/) into a fullscreen gallery to remove all the annoying extra steps that go into installing themes in Omarchy's current state.

## How it works

- `bin/omarchy-theme-store-fetch` scrapes omarchy.org/themes/ (it's static
  HTML, no API) and caches the parsed catalog + thumbnails under
  `~/.cache/omarchy/theme-store/`, refreshing at minimum once every 24h
  (`OMARCHY_THEME_STORE_TTL` env var to change that) unless a stale cache is
  all that's available.
- `ThemeStore.qml` / `ThemeStoreModel.js` is the plugin itself: a
  Quickshell `overlay` plugin see `manifest.json` for more.
- Installing a theme opens a shell the same way `omarchy-theme-install`
  script does `Install > Style > Theme` removal (`Remove > Theme`) and theme-switching behave exactly the same.

## Install

```sh
omarchy plugin add https://github.com/stizzy-98/Omarchy-Theme-Store.git --enable
```

Using omarchy's own plugin installer — it clones the repo straight into
`~/.config/omarchy/plugins/community.theme-store`, validates and enables it.
The first time it loads it registers its own "Super + Space > Install > Omarchy Theme Store"
menu entry. Running the same

## Use

inside the Omarchy menu: `Super + Space` → `Install` → `Omarchy Theme Store`.
- Browse every community theme as thumbnail cards.
- Filter for specific theme names by typing.
- Press ctrl + r to refresh gallery.
- Press `Enter` on a theme to see a full-size preview with 'Back' and 'Install' buttons. 

## Updating
Run: omarchy plugin update community.theme-store

## Uninstall
 ```sh

omarchy plugin remove community.theme-store
 ```

That removes the plugin itself to remove menu entry run:

```sh
./scripts/uninstall.sh          # remove the leftover menu entry
./scripts/uninstall.sh --purge-cache   # also delete the cached catalog/thumbnails
```

## Development

`manifest.json` declares `keepLoaded: true`, so once the shell has loaded the
plugin it stays resident in memory — `omarchy-shell shell rescanPlugins` only
picks up newly added/removed plugins and manifest changes, it does not
re-read an already-loaded plugin's QML. To pick up edits to `ThemeStore.qml`
or `ThemeStoreModel.js` in a session where the plugin is already running:

```sh
omarchy restart shell
```

## Using only CLI instead of the Menu:

```sh
omarchy-shell shell summon community.theme-store '{}'
```
