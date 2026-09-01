function parseCatalogJson(raw) {
  try {
    var parsed = JSON.parse(String(raw || "[]"))
    return Array.isArray(parsed) ? parsed : []
  } catch (e) {
    return []
  }
}

function filterCatalog(catalog, filterText) {
  var items = Array.isArray(catalog) ? catalog : []
  var needle = String(filterText || "").toLowerCase()
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
    clampIndex: clampIndex
  }
}
