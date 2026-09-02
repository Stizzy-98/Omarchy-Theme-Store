// Bounds mirrored from bin/omarchy-theme-store-fetch's own limits. The fetch
// helper already caps these at the source, but the catalog reaches this
// long-lived shell process over IPC-like stdout, so every value is
// re-validated here rather than trusted just because the producer promised
// to behave.
var MAX_RAW_CHARS = 8 * 1024 * 1024
var MAX_ITEMS = 300
var MAX_FIELD_LEN = 300

var REPO_URL_RE = /^https:\/\/github\.com\/[A-Za-z0-9](?:[A-Za-z0-9-]{0,38})\/[A-Za-z0-9._-]{1,100}(?:\.git)?$/
var SLUG_RE = /^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$/

function isNonEmptyBoundedString(value, maxLen) {
  return typeof value === "string" && value.length > 0 && value.length <= (maxLen || MAX_FIELD_LEN)
}

// Strict allowlist: only a canonical https://github.com/<owner>/<repo>(.git)?
// URL is considered installable. This is the authoritative gate — the
// catalog is scraped from a page we don't control, so nothing from it may
// reach the theme installer without passing this check first.
function isInstallableRepo(repoUrl) {
  return typeof repoUrl === "string" && repoUrl.length <= MAX_FIELD_LEN && REPO_URL_RE.test(repoUrl)
}

// A cached thumbnail path is only ever safe to hand to the Image element if
// it resolves inside the verified per-user thumbs cache directory, with no
// traversal segments.
function isSafeThumbnailPath(path, thumbsDirPrefix) {
  if (typeof path !== "string" || path.length === 0 || path.length > MAX_FIELD_LEN) return false
  if (typeof thumbsDirPrefix !== "string" || thumbsDirPrefix.length === 0) return false
  if (path.indexOf("..") !== -1) return false
  return path.indexOf(thumbsDirPrefix) === 0
}

function isValidThemeEntry(entry) {
  if (!entry || typeof entry !== "object") return false
  if (!isNonEmptyBoundedString(entry.slug, 64) || !SLUG_RE.test(entry.slug)) return false
  if (!isNonEmptyBoundedString(entry.name)) return false
  if (!isNonEmptyBoundedString(entry.repoUrl)) return false
  if (entry.thumbnailPath !== "" && !isNonEmptyBoundedString(entry.thumbnailPath)) return false
  return true
}

// Parses and validates the fetch helper's stdout. Anything that isn't a
// bounded array of well-formed entries is dropped rather than partially
// trusted: a malformed or truncated catalog degrades to an empty list, not
// to whatever shape happened to survive JSON.parse.
function parseCatalogJson(raw) {
  var text = String(raw || "")
  if (text.length > MAX_RAW_CHARS) return []

  var parsed
  try {
    parsed = JSON.parse(text)
  } catch (e) {
    return []
  }
  if (!Array.isArray(parsed)) return []

  var out = []
  for (var i = 0; i < parsed.length && out.length < MAX_ITEMS; i++) {
    if (isValidThemeEntry(parsed[i])) out.push(parsed[i])
  }
  return out
}

function filterCatalog(catalog, filterText) {
  var items = Array.isArray(catalog) ? catalog : []
  var needle = String(filterText || "").slice(0, MAX_FIELD_LEN).toLowerCase()
  if (!needle) return items

  return items.filter(function(theme) {
    return String(theme.name || "").toLowerCase().indexOf(needle) !== -1
  })
}

// "https://github.com/owner/repo(.git)" -> "owner". Falls back to the bare
// repo URL for non-GitHub remotes so the detail view always has something
// to show under the theme name.
function repoOwner(repoUrl) {
  var match = String(repoUrl || "").match(/^https?:\/\/github\.com\/([^\/]+)\/?/)
  return match ? match[1] : ""
}

function clampIndex(index, length) {
  if (length <= 0) return 0
  return Math.max(0, Math.min(index, length - 1))
}

if (typeof module !== "undefined") {
  module.exports = {
    parseCatalogJson: parseCatalogJson,
    filterCatalog: filterCatalog,
    repoOwner: repoOwner,
    clampIndex: clampIndex,
    isInstallableRepo: isInstallableRepo,
    isSafeThumbnailPath: isSafeThumbnailPath,
    isValidThemeEntry: isValidThemeEntry
  }
}
