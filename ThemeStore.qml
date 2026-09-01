import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.Commons
import qs.Ui
import "ThemeStoreModel.js" as ThemeStoreModel

// Fullscreen theme gallery: browse omarchy.org/themes and install straight
// into a terminal. Summoned via `omarchy-shell shell summon
// community.theme-store '{}'` (wired up by scripts/install.sh into the
// user's Install menu). Lifecycle mirrors the other first-party overlays
// (image-picker, reminders): open(payload)/close() are called by the shell
// host, dismiss() is how we voluntarily close ourselves.
Item {
  id: root

  property var shell: null
  property var manifest: null

  readonly property string pluginDir: Quickshell.env("HOME") + "/.config/omarchy/plugins/community.theme-store"
  function scriptPath(name) { return root.pluginDir + "/bin/" + name }

  property bool opened: false
  property string view: "gallery" // "gallery" | "detail"
  property var catalog: []
  property bool catalogLoaded: false
  property bool loading: false
  property string errorText: ""
  property string filterText: ""
  property int selectedIndex: 0
  property var selectedTheme: null
  property string detailFocus: "back" // "back" | "install" — which detail-view button is current

  property var filteredCatalog: ThemeStoreModel.filterCatalog(root.catalog, root.filterText)

  property color background: Color.menu.background
  property color foreground: Color.menu.text
  property color border: Color.menu.border
  property color accent: Color.accent
  property color scrim: Color.menu.scrim
  property var borderSpec: Border.surfaceSpec("menu", "border", border, Math.max(1, Style.space(2)))
  readonly property int cornerRadius: Style.cornerRadius

  function open(payloadJson) {
    root.opened = true
    root.view = "gallery"
    root.filterText = ""
    root.errorText = ""
    if (!root.catalogLoaded) root.loadCatalog(false)
    Qt.callLater(function() { root.focusCurrentView() })
  }

  function close() {
    root.opened = false
  }

  function dismiss() {
    root.opened = false
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide((root.manifest && root.manifest.id) || "community.theme-store")
  }

  function toggle() {
    if (root.opened) root.dismiss()
    else root.open("{}")
  }

  function focusCurrentView() {
    if (!root.opened) return
    if (root.view === "gallery") grid.forceActiveFocus()
    else detailView.forceActiveFocus()
  }

  function loadCatalog(force) {
    if (fetchProc.running) return
    root.loading = true
    root.errorText = ""
    var args = [root.scriptPath("omarchy-theme-store-fetch")]
    if (force) args.push("--force")
    fetchProc.command = args
    fetchProc.running = true
  }

  function openDetail(index) {
    var items = root.filteredCatalog
    if (index < 0 || index >= items.length) return
    root.selectedTheme = items[index]
    root.view = "detail"
    root.detailFocus = "back"
    Qt.callLater(function() { root.focusCurrentView() })
  }

  function backToGallery() {
    root.view = "gallery"
    Qt.callLater(function() { root.focusCurrentView() })
  }

  function installSelected() {
    if (!root.selectedTheme || !root.selectedTheme.repoUrl) return
    Util.execArgv([
      "omarchy-launch-floating-terminal-with-presentation",
      "omarchy-theme-install",
      Util.shellQuote(root.selectedTheme.repoUrl)
    ])
    root.dismiss()
  }

  Process {
    id: fetchProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var parsed = ThemeStoreModel.parseCatalogJson(text)
        root.loading = false
        if (parsed.length > 0) {
          root.catalog = parsed
          root.catalogLoaded = true
          root.selectedIndex = ThemeStoreModel.clampIndex(root.selectedIndex, root.filteredCatalog.length)
        } else if (!root.catalogLoaded) {
          root.errorText = "Couldn't load themes from omarchy.org — check your network connection."
        }
      }
    }
  }

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omarchy-theme-store"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
      anchors.fill: parent
      color: root.scrim
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.dismiss()
    }

    BorderSurface {
      id: card
      width: Math.min(parent.width - Style.space(120), Style.space(1040))
      height: Math.min(parent.height - Style.space(100), Style.space(720))
      anchors.centerIn: parent
      radius: root.cornerRadius
      color: root.background
      borderSpec: root.borderSpec
      padding: Style.spacing.panelPadding

      MouseArea { anchors.fill: parent; onClicked: {} }

      Item {
        id: content
        anchors.fill: parent
        anchors.topMargin: card.contentTopInset
        anchors.rightMargin: card.contentRightInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset

        // ---- header ---------------------------------------------------
        Item {
          id: header
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          height: Style.font.title + Style.spacing.controlPaddingY * 2

          Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: root.view === "gallery" ? "Omarchy Theme Store" : (root.selectedTheme ? root.selectedTheme.name : "")
            color: root.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.title
            font.weight: Font.DemiBold
            elide: Text.ElideRight
          }

          Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: root.view === "gallery"
            text: root.loading ? "Loading…" : (root.filterText ? ("Search: " + root.filterText) : "Type to search · Enter to view · Esc to close")
            color: Util.alpha(root.foreground, 0.65)
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            elide: Text.ElideRight
          }
        }

        // ---- gallery view ----------------------------------------------
        Item {
          id: galleryView
          visible: root.view === "gallery"
          anchors.top: header.bottom
          anchors.topMargin: Style.spacing.controlGap
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom

          Text {
            anchors.centerIn: parent
            visible: root.errorText !== "" && root.filteredCatalog.length === 0
            text: root.errorText
            color: Color.urgent
            font.family: Style.font.family
            font.pixelSize: Style.font.body
            width: parent.width * 0.7
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
          }

          Text {
            anchors.centerIn: parent
            visible: root.errorText === "" && !root.loading && root.filteredCatalog.length === 0 && root.catalogLoaded
            text: "No themes match “" + root.filterText + "”"
            color: Util.alpha(root.foreground, 0.6)
            font.family: Style.font.family
            font.pixelSize: Style.font.body
          }

          GridView {
            id: grid
            anchors.fill: parent
            clip: true
            focus: root.view === "gallery"
            cellWidth: Style.space(232)
            cellHeight: Style.space(178)
            model: root.filteredCatalog
            currentIndex: root.selectedIndex
            onCurrentIndexChanged: root.selectedIndex = currentIndex

            Keys.priority: Keys.BeforeItem
            Keys.onPressed: function(event) {
              if (event.key === Qt.Key_Escape) {
                if (root.filterText) root.filterText = ""
                else root.dismiss()
                event.accepted = true
              } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.openDetail(grid.currentIndex)
                event.accepted = true
              } else if (event.key === Qt.Key_R && (event.modifiers & Qt.ControlModifier)) {
                root.loadCatalog(true)
                event.accepted = true
              } else if (Util.editsFilter(event, root.filterText)) {
                root.filterText = Util.editedFilter(event, root.filterText)
                event.accepted = true
              } else if (event.text && event.text.length === 1 && event.text.charCodeAt(0) >= 32 && event.text.charCodeAt(0) !== 127 && (event.modifiers === Qt.NoModifier || event.modifiers === Qt.ShiftModifier)) {
                root.filterText = root.filterText + event.text
                event.accepted = true
              }
            }

            delegate: Item {
              id: cell
              required property var modelData
              required property int index
              width: grid.cellWidth
              height: grid.cellHeight

              readonly property bool current: index === grid.currentIndex

              Rectangle {
                anchors.fill: parent
                anchors.margins: Style.space(8)
                radius: root.cornerRadius
                color: current ? Util.alpha(root.accent, 0.12) : Util.alpha(root.foreground, 0.04)
                border.color: current ? root.accent : Util.alpha(root.foreground, 0.18)
                border.width: current ? 2 : 1

                Column {
                  anchors.fill: parent
                  anchors.margins: Style.space(10)
                  spacing: Style.space(6)

                  Rectangle {
                    width: parent.width
                    height: parent.height - nameLabel.implicitHeight - Style.space(6)
                    radius: Style.space(4)
                    color: Util.alpha(root.foreground, 0.06)
                    clip: true

                    Image {
                      anchors.fill: parent
                      source: cell.modelData.thumbnailPath ? Util.fileUrl(cell.modelData.thumbnailPath) : ""
                      fillMode: Image.PreserveAspectCrop
                      asynchronous: true
                      cache: true
                      smooth: true
                    }
                  }

                  Text {
                    id: nameLabel
                    width: parent.width
                    text: cell.modelData.name || ""
                    color: root.foreground
                    font.family: Style.font.family
                    font.pixelSize: Style.font.body
                    elide: Text.ElideRight
                  }
                }
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: cell.current ? root.openDetail(cell.index) : (grid.currentIndex = cell.index)
                onDoubleClicked: root.openDetail(cell.index)
              }
            }
          }
        }

        // ---- detail view -------------------------------------------------
        Item {
          id: detailView
          visible: root.view === "detail"
          anchors.top: header.bottom
          anchors.topMargin: Style.spacing.controlGap
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom

          focus: root.view === "detail"
          Keys.priority: Keys.BeforeItem
          Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
              root.backToGallery()
              event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
              if (root.detailFocus === "install") root.installSelected()
              else root.backToGallery()
              event.accepted = true
            } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Right || event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
              root.detailFocus = root.detailFocus === "back" ? "install" : "back"
              event.accepted = true
            }
          }

          Rectangle {
            id: previewFrame
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: parent.height - buttonRow.height - Style.spacing.controlGap * 2 - subtitle.implicitHeight
            radius: root.cornerRadius
            color: Util.alpha(root.foreground, 0.06)
            clip: true

            Image {
              anchors.fill: parent
              source: root.selectedTheme && root.selectedTheme.thumbnailPath ? Util.fileUrl(root.selectedTheme.thumbnailPath) : ""
              fillMode: Image.PreserveAspectFit
              asynchronous: true
              cache: true
              smooth: true
            }
          }

          Text {
            id: subtitle
            anchors.top: previewFrame.bottom
            anchors.topMargin: Style.spacing.controlGap
            anchors.left: parent.left
            anchors.right: parent.right
            text: {
              var owner = root.selectedTheme ? ThemeStoreModel.repoOwner(root.selectedTheme.repoUrl) : ""
              if (owner) return "by " + owner
              return root.selectedTheme ? root.selectedTheme.repoUrl : ""
            }
            color: Util.alpha(root.foreground, 0.7)
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            elide: Text.ElideRight
          }

          Row {
            id: buttonRow
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            spacing: Style.spacing.controlGap + Style.space(4)

            // Explicit accent ring driven by root.detailFocus, rather than
            // Button's own activeFocus styling: focusFillFor() is themed per
            // color scheme and can render too subtly to read as "selected"
            // against some palettes, so this stays visible everywhere.
            Item {
              width: backButton.implicitWidth + Style.space(8)
              height: backButton.implicitHeight + Style.space(8)

              Rectangle {
                anchors.fill: parent
                radius: root.cornerRadius + Style.space(4)
                color: "transparent"
                border.color: root.detailFocus === "back" ? root.accent : "transparent"
                border.width: 2
              }

              Button {
                id: backButton
                anchors.centerIn: parent
                text: "Back"
                iconText: "←"
                bordered: true
                onClicked: root.backToGallery()
              }
            }

            Item {
              width: installButton.implicitWidth + Style.space(8)
              height: installButton.implicitHeight + Style.space(8)

              Rectangle {
                anchors.fill: parent
                radius: root.cornerRadius + Style.space(4)
                color: "transparent"
                border.color: root.detailFocus === "install" ? root.accent : "transparent"
                border.width: 2
              }

              Button {
                id: installButton
                anchors.centerIn: parent
                text: "Install"
                bordered: true
                onClicked: root.installSelected()
              }
            }
          }
        }
      }
    }
  }
}
