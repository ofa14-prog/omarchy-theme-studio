import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Commons // qmllint disable import
import "components"
import "Palette.js" as P
import "I18n.js" as I18n

// Theme Studio overlay: `omarchy-shell shell toggle <plugin-id> '{}'`.
// Payload (optional): {"theme": "<name>"} opens that theme,
// {"import": "<path or git url>"} opens the import dialog prefilled.
Item {
  id: root

  property var shell: null
  property var manifest: null
  readonly property string pluginDir: decodeURIComponent(String(Qt.resolvedUrl(".")).replace(/^file:\/\//, "")).replace(/\/$/, "")
  // Installed plugins live in ~/.config/omarchy/plugins/<id>/, so the folder name is the id.
  readonly property string pluginId: String((root.manifest && root.manifest.id) || pluginDir.substring(pluginDir.lastIndexOf("/") + 1))
  readonly property string helper: pluginDir + "/bin/theme-studio"
  readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR") || ""
  readonly property string lang: I18n.pick(Quickshell.env("THEME_STUDIO_LANG") || Quickshell.env("LC_ALL")
    || Quickshell.env("LC_MESSAGES") || Quickshell.env("LANG") || Qt.locale().name)
  property var targetScreen: null

  function tr(text) {
    return I18n.tr(lang, text, Array.prototype.slice.call(arguments, 1))
  }

  property bool opened: false
  property bool checkedDeps: false

  function focusedScreen() {
    var monitor = Hyprland.focusedMonitor
    var name = monitor ? String(monitor.name || "") : ""
    var screens = Quickshell.screens
    for (var i = 0; i < screens.length; i++) if (screens[i].name === name) return screens[i]
    return screens.length ? screens[0] : null
  }

  // ------------------------------------------------------------ editor state
  property var pal: ({})
  property var extras: ({})
  property string icons: ""
  property var wallpapers: []
  property int wallIndex: 0
  property string editTitle: ""
  property var source: ({ name: "", user: false, builtin: false, git: false, staticFiles: [] })
  property string selectedKey: "accent"
  property string hoverKey: ""
  property var undoStack: []
  property var redoStack: []
  property string lastHistoryKey: ""
  property double lastHistoryAt: 0
  property bool dirty: false
  property bool loadedOnce: false
  property bool capturing: false

  property bool livePreview: false
  property bool previewPushed: false
  property bool previewRunning: false
  property bool previewAgain: false

  property string tab: "desktop"
  property string vibe: "balanced"
  property real lean: 0.15

  property var themes: []
  property string activeTheme: ""
  property string filter: ""
  property var iconList: []

  property string modal: ""          // "" | import | browser | confirm
  property string confirmText: ""
  property var confirmAction: null
  property string browserMode: ""
  property string browserPurpose: ""
  property string importSource: ""
  property bool importTrust: false

  property string busy: ""
  property string toastText: ""
  property string toastKind: "info"
  property string toastActionLabel: ""
  property var toastAction: null

  readonly property string slug: P.slug(editTitle)
  readonly property string currentWallpaper: wallpapers.length ? wallpapers[Math.min(wallIndex, wallpapers.length - 1)] : ""
  readonly property var activeBorder: P.borderColors(pal, "hyprland_active_border")
  readonly property bool customBorder: !!(pal.hyprland_active_border || pal.hyprland_inactive_border)
  readonly property bool gradientBorder: activeBorder.colors.length > 1
  readonly property color fg: Color.foreground
  readonly property color accent: Color.accent
  // Small/laptop screens: drop secondary header labels so nothing overlaps.
  readonly property bool compact: targetScreen ? targetScreen.width < 1600 : false

  readonly property var filteredThemes: {
    var q = filter.toLowerCase()
    var out = []
    for (var i = 0; i < themes.length; i++)
      if (!q || themes[i].title.toLowerCase().indexOf(q) !== -1) out.push(themes[i])
    return out
  }

  readonly property string saveTargetInfo: {
    if (!slug) return root.tr("A theme name is required")
    var t = themeByName(slug)
    if (t && t.user && slug === source.name) return root.tr("~/.config/omarchy/themes/%1 will be updated", slug)
    if (t && t.user) return root.tr("⚠ Will overwrite your existing '%1' theme", slug)
    if (t && t.builtin) return root.tr("⚠ Will override the built-in '%1' theme", t.title)
    return root.tr("New theme: ~/.config/omarchy/themes/%1", slug)
  }

  function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

  // ------------------------------------------------------------ helper runner
  Component {
    id: jobComponent
    Process {
      id: job
      property var callback: null
      property bool finished: false
      function finish(t) {
        if (finished) return
        finished = true
        var r
        try { r = JSON.parse(t) } catch (e) { r = { ok: false, error: root.tr("The helper script did not answer. Is python3 installed?") + (t ? " " + String(t).substring(0, 160) : "") } }
        if (callback) {
          try { callback(r) } catch (e2) { console.warn("theme-studio:", e2) }
        }
        Qt.callLater(function() { job.destroy() })
      }
      stdout: StdioCollector {
        onStreamFinished: job.finish(text)
      }
    }
  }

  function run(args, cb) {
    // Run through python3 so a lost executable bit (zip downloads, some copies) does not matter.
    var job = jobComponent.createObject(root, {
      command: ["python3", root.helper].concat(args),
      environment: ({ THEME_STUDIO_LANG: root.lang }),
      callback: cb || null
    })
    job.running = true
  }

  // ------------------------------------------------------------ lifecycle
  function open(payloadJson) {
    var payload = {}
    try { payload = JSON.parse(payloadJson || "{}") || {} } catch (e) {}
    root.targetScreen = focusedScreen()
    root.opened = true
    refreshThemes(payload.theme || "")
    if (!checkedDeps) {
      checkedDeps = true
      run(["doctor"], function(r) {
        if (r.ok && r.missing.length)
          root.toast(root.tr("Missing Omarchy commands: %1. Some features will not work.", r.missing.join(", ")), "error")
      })
    }
    if (!iconList.length) run(["icons"], function(r) { if (r.ok) root.iconList = r.icons })
    if (payload["import"]) {
      importSource = String(payload["import"])
      modal = "import"
    }
    Qt.callLater(function() { keys.forceActiveFocus() })
  }

  function close() {
    root.opened = false
    root.modal = ""
    if (root.previewPushed) {
      root.previewPushed = false
      root.livePreview = false
      Quickshell.execDetached([root.helper, "revert"])
    }
  }

  function dismiss(force) {
    if (root.dirty && !force) {
      confirm(root.tr("You have unsaved changes. Close without saving?"), function() { root.dismiss(true) })
      return
    }
    root.close()
    if (root.shell && typeof root.shell.hide === "function") root.shell.hide(root.pluginId)
  }

  function toast(text, kind, actionLabel, action) {
    toastText = text
    toastKind = kind || "info"
    toastActionLabel = actionLabel || ""
    toastAction = action || null
    toastTimer.interval = kind === "error" ? 7000 : 4500
    toastTimer.restart()
  }

  Timer { id: toastTimer; onTriggered: root.toastText = "" }

  function confirm(text, action) {
    confirmText = text
    confirmAction = action
    modal = "confirm"
  }

  function themeByName(name) {
    for (var i = 0; i < themes.length; i++) if (themes[i].name === name) return themes[i]
    return null
  }

  function uniqueTitle(base) {
    var t = base, n = 2
    while (themeByName(P.slug(t))) t = base + " " + (n++)
    return t
  }

  // ------------------------------------------------------------ themes
  function refreshThemes(openName) {
    run(["list"], function(r) {
      if (!r.ok) { toast(r.error, "error"); return }
      root.themes = r.themes
      root.activeTheme = r.current
      if (openName) loadTheme(openName, false)
      else if (!root.loadedOnce) loadTheme(r.current, true)
    })
  }

  function loadTheme(name, force) {
    if (!name) return
    if (dirty && !force) {
      confirm(root.tr("Unsaved changes will be lost. Open '%1'?", P.title(name)), function() { loadTheme(name, true) })
      return
    }
    busy = root.tr("Loading…")
    run(["load", name], function(r) {
      busy = ""
      if (!r.ok) { toast(r.error, "error"); return }
      root.source = r
      root.editTitle = r.user ? r.title : root.tr("%1 Custom", r.title)
      root.pal = P.complete(r.colors)
      root.extras = r.extras || {}
      root.icons = r.icons || ""
      root.wallpapers = r.wallpapers || []
      root.wallIndex = 0
      root.undoStack = []
      root.redoStack = []
      root.dirty = false
      root.loadedOnce = true
      if (root.selectedKey.indexOf("border:") === 0 && !root.customBorder) root.selectedKey = "accent"
      schedulePreview()
    })
  }

  function newTheme(force) {
    if (dirty && !force) {
      confirm(root.tr("Unsaved changes will be lost. Start a new theme?"), function() { newTheme(true) })
      return
    }
    var p = P.generate({ mode: pal.mode || "dark", accent: P.isHex(pal.accent) ? pal.accent : "#7aa2f7", vibe: vibe, lean: lean })
    source = { name: "", user: false, builtin: false, git: false, staticFiles: [] }
    editTitle = uniqueTitle(root.tr("New Theme"))
    pal = p
    extras = {}
    undoStack = []
    redoStack = []
    dirty = true
    loadedOnce = true
    schedulePreview()
    toast(root.tr("New theme created. Click colours to edit them."), "ok")
  }

  // ------------------------------------------------------------ editing
  // Also reachable over IPC: omarchy-shell shell call <plugin-id> setTab palette
  function setTab(name) {
    tab = name
  }

  function setModal(name) {
    if (name === "browser") openBrowser("wallpaper", "images")
    else modal = name === "none" ? "" : name
  }

  function selectKey(key) {
    selectedKey = key
  }

  function keyColor(key) {
    if (key.indexOf("border:") === 0) {
      var parts = key.split(":")
      var spec = P.borderColors(pal, parts[1] === "active" ? "hyprland_active_border" : "hyprland_inactive_border")
      return spec.colors[Math.min(Number(parts[2]), spec.colors.length - 1)]
    }
    return P.isHex(pal[key]) ? pal[key] : "#888888"
  }

  function keyInfo(key) {
    if (key === "border:active:0") return { label: gradientBorder ? root.tr("Active border · colour 1") : root.tr("Active window border"), hint: "hyprland_active_border", code: "hyprland_active_border" }
    if (key === "border:active:1") return { label: root.tr("Active border · colour 2"), hint: root.tr("Second gradient colour"), code: "hyprland_active_border" }
    if (key === "border:inactive:0") return { label: root.tr("Inactive window border"), hint: root.tr("Unfocused windows"), code: "hyprland_inactive_border" }
    var i = P.info(key)
    return { label: root.tr(i.label), hint: root.tr(i.hint), code: key }
  }

  function pushHistory(coalesce) {
    var now = Date.now()
    if (coalesce && coalesce === lastHistoryKey && now - lastHistoryAt < 900) { lastHistoryAt = now; return }
    lastHistoryKey = coalesce || ""
    lastHistoryAt = now
    var u = undoStack.slice()
    u.push(P.copy(pal))
    if (u.length > 200) u.shift()
    undoStack = u
    redoStack = []
  }

  function setPal(p) {
    pal = p
    dirty = true
    schedulePreview()
  }

  function setColor(key, hex) {
    if (!P.isHex(hex)) return
    pushHistory("color:" + key)
    var p = P.copy(pal)
    if (key.indexOf("border:") === 0) {
      var parts = key.split(":")
      var active = parts[1] === "active"
      var bkey = active ? "hyprland_active_border" : "hyprland_inactive_border"
      var spec = P.borderColors(pal, bkey)
      var cols = spec.colors.slice()
      var i = Number(parts[2])
      while (cols.length <= i) cols.push(cols[cols.length - 1])
      cols[i] = hex
      p[bkey] = P.borderSpec(cols, spec.angle, active ? "ee" : "aa")
    } else {
      p[key] = hex
    }
    setPal(p)
  }

  function replacePalette(p, message) {
    pushHistory("")
    lastHistoryKey = ""
    var next = P.complete(p)
    if (pal.hyprland_active_border) next.hyprland_active_border = pal.hyprland_active_border
    if (pal.hyprland_inactive_border) next.hyprland_inactive_border = pal.hyprland_inactive_border
    setPal(next)
    if (message) toast(message, "ok")
  }

  function undo() {
    if (!undoStack.length) return
    var u = undoStack.slice()
    var prev = u.pop()
    redoStack = redoStack.concat([P.copy(pal)])
    undoStack = u
    lastHistoryKey = ""
    pal = prev
    dirty = true
    schedulePreview()
  }

  function redo() {
    if (!redoStack.length) return
    var r = redoStack.slice()
    var next = r.pop()
    undoStack = undoStack.concat([P.copy(pal)])
    redoStack = r
    lastHistoryKey = ""
    pal = next
    dirty = true
    schedulePreview()
  }

  function adjustSelected(dl, ds) {
    setColor(selectedKey, P.adjust(keyColor(selectedKey), dl, ds))
    lastHistoryKey = ""
  }

  function setCustomBorder(on) {
    pushHistory("")
    var p = P.copy(pal)
    if (on) {
      p.hyprland_active_border = P.borderSpec([pal.accent], 0, "ee")
      p.hyprland_inactive_border = P.borderSpec([P.mix(pal.background, pal.foreground, 0.3)], 0, "aa")
      selectedKey = "border:active:0"
    } else {
      delete p.hyprland_active_border
      delete p.hyprland_inactive_border
      if (selectedKey.indexOf("border:") === 0) selectedKey = "accent"
    }
    setPal(p)
  }

  function setGradient(on) {
    pushHistory("")
    var spec = P.borderColors(pal, "hyprland_active_border")
    var cols = [spec.colors[0]]
    if (on) cols.push(P.isHex(pal.magenta) ? pal.magenta : pal.accent)
    var p = P.copy(pal)
    p.hyprland_active_border = P.borderSpec(cols, on ? (spec.angle || 45) : 0, "ee")
    if (!on && selectedKey === "border:active:1") selectedKey = "border:active:0"
    setPal(p)
  }

  function setAngle(a) {
    pushHistory("")
    var spec = P.borderColors(pal, "hyprland_active_border")
    var p = P.copy(pal)
    p.hyprland_active_border = P.borderSpec(spec.colors, a, "ee")
    setPal(p)
  }

  function fixContrast(fgKey, bgKey, target) {
    var bg = keyColor(bgKey), c = keyColor(fgKey)
    var hsl = P.toHsl(c)
    var dir = P.luminance(bg) > P.luminance(c) ? -1 : 1
    for (var i = 0; i < 100 && P.contrast(c, bg) < target; i++) {
      hsl.l = P.clamp(hsl.l + dir * 0.01, 0, 1)
      c = P.fromHsl(hsl.h, hsl.s, hsl.l)
    }
    lastHistoryKey = ""
    setColor(fgKey, c)
    lastHistoryKey = ""
  }

  // ------------------------------------------------------------ live preview
  Timer { id: previewTimer; interval: 350; onTriggered: root.pushPreview() }

  function schedulePreview() {
    if (livePreview) previewTimer.restart()
  }

  function pushPreview() {
    if (!livePreview) return
    if (previewRunning) { previewAgain = true; return }
    previewRunning = true
    run(["preview", JSON.stringify({ colors: pal, extras: extras })], function(r) {
      root.previewRunning = false
      if (!r.ok) { root.toast(r.error, "error"); root.livePreview = false; return }
      root.previewPushed = true
      if (root.previewAgain) { root.previewAgain = false; root.pushPreview() }
    })
  }

  onLivePreviewChanged: {
    if (livePreview) pushPreview()
    else if (previewPushed) {
      previewPushed = false
      run(["revert"], function(r) {})
    }
  }

  // ------------------------------------------------------------ save / apply / export
  function save(after) {
    if (!slug) { toast(root.tr("Give the theme a name first"), "error"); nameInput.forceActiveFocus(); return }
    var t = themeByName(slug)
    if (t && t.user && slug !== source.name) {
      confirm(root.tr("Overwrite your theme '%1'?", t.title), function() { doSave(after) })
      return
    }
    doSave(after)
  }

  function doSave(after) {
    busy = root.tr("Saving…")
    capturing = true
    if (!runtimeDir) { writeTheme("", after); return }
    var shot = runtimeDir + "/theme-studio-preview.png"
    Qt.callLater(function() {
      var ok = canvasView.grabToImage(function(result) {
        var saved = result.saveToFile(shot)
        root.writeTheme(saved ? shot : "", after)
      }, Qt.size(1800, 1125))
      if (!ok) root.writeTheme("", after)
    })
  }

  function writeTheme(shot, after) {
    capturing = false
    var payload = {
      name: slug,
      base: source.name || "",
      colors: pal,
      extras: extras,
      icons: icons,
      wallpapers: wallpapers,
      previewImage: shot
    }
    run(["save", JSON.stringify(payload)], function(r) {
      root.busy = ""
      if (!r.ok) { root.toast(r.error, "error"); return }
      root.dirty = false
      var src = P.copy(root.source)
      src.name = r.name
      src.user = true
      root.source = src
      root.refreshThemes("")
      if (typeof after === "function") after(r.name)
      else root.toast(root.tr("Saved → ~/.config/omarchy/themes/%1", r.name), "ok", root.tr("Apply"), function() { root.applyTheme(r.name) })
    })
  }

  function applyTheme(name) {
    busy = root.tr("Applying…")
    run(["apply", name], function(r) {
      root.busy = ""
      if (!r.ok) { root.toast(r.error, "error"); return }
      root.previewPushed = false
      root.activeTheme = name
      root.refreshThemes("")
      root.toast(root.tr("'%1' applied", P.title(name)) + (r.log ? " · " + r.log : ""), "ok")
    })
  }

  function saveAndApply() {
    save(function(name) { root.applyTheme(name) })
  }

  function exportTheme() {
    var go = function(name) {
      root.busy = root.tr("Exporting…")
      root.run(["export", name], function(r) {
        root.busy = ""
        if (!r.ok) { root.toast(r.error, "error"); return }
        Quickshell.execDetached(["wl-copy", r.path])
        var dir = r.path.substring(0, r.path.lastIndexOf("/"))
        root.toast(root.tr("Exported: %1 (path copied to clipboard)", r.path), "ok", root.tr("Open folder"), function() { Quickshell.execDetached(["xdg-open", dir]) })
      })
    }
    if (dirty || !source.user || slug !== source.name) {
      confirm(root.tr("The theme will be saved as '%1' before exporting. Continue?", slug), function() { root.save(go) })
      return
    }
    go(source.name)
  }

  function importTheme() {
    var src = importSource.trim()
    if (!src) { toast(root.tr("Enter a file, folder or git URL"), "error"); return }
    modal = ""
    busy = root.tr("Importing…")
    var args = ["import", src]
    if (importTrust) args.push("--trust")
    run(args, function(r) {
      root.busy = ""
      if (!r.ok) { root.toast(r.error, "error"); root.modal = "import"; return }
      root.importSource = ""
      var note = r.skipped && r.skipped.length ? root.tr(" · skipped for safety: %1", r.skipped.join(", ")) : ""
      root.toast(root.tr("Imported: %1", r.name) + note, "ok")
      root.refreshThemes(r.name)
      root.dirty = false
    })
  }

  function deleteTheme() {
    var name = source.name
    var t = themeByName(name)
    if (!t || !t.user) { toast(root.tr("You can only delete your own themes"), "error"); return }
    confirm(root.tr("Delete '%1' permanently?", t.title) + (t.builtin ? root.tr(" (the built-in version stays)") : ""), function() {
      root.run(["delete", name], function(r) {
        if (!r.ok) { root.toast(r.error, "error"); return }
        root.toast(root.tr("Deleted: %1", name), "ok")
        root.dirty = false
        root.refreshThemes(r.builtinRemains ? name : root.activeTheme)
      })
    })
  }

  function copyToml() {
    Quickshell.execDetached(["wl-copy", P.toToml(pal, extras)])
    toast(root.tr("colors.toml copied to clipboard"), "ok")
  }

  // ------------------------------------------------------------ wallpapers
  function openBrowser(purpose, mode) {
    browserPurpose = purpose
    browserMode = mode
    modal = "browser"
    var start = purpose === "wallpaper" ? "~/Pictures" : "~/Downloads"
    Qt.callLater(function() { fileBrowser.go(start) })
  }

  function browserChosen(path) {
    if (browserPurpose === "wallpaper") {
      modal = ""
      var w = wallpapers.slice()
      if (w.indexOf(path) === -1) w.push(path)
      wallpapers = w
      wallIndex = w.indexOf(path)
      dirty = true
    } else {
      importSource = path
      modal = "import"
    }
  }

  function removeWallpaper() {
    if (!wallpapers.length) return
    var w = wallpapers.slice()
    w.splice(wallIndex, 1)
    wallpapers = w
    wallIndex = Math.max(0, Math.min(wallIndex, w.length - 1))
    dirty = true
  }

  function paletteFromWallpaper() {
    if (!currentWallpaper) { toast(root.tr("Add a wallpaper first"), "error"); return }
    busy = root.tr("Analysing image…")
    run(["image-palette", currentWallpaper], function(r) {
      root.busy = ""
      if (!r.ok) { root.toast(r.error, "error"); return }
      root.replacePalette(P.fromImage(r.colors, root.pal.mode || "dark"), root.tr("Palette generated from the wallpaper"))
    })
  }

  function cycleIcons(step) {
    if (!iconList.length) return
    var i = iconList.indexOf(icons)
    i = (i + step + iconList.length) % iconList.length
    icons = iconList[i]
    dirty = true
  }

  readonly property var contrastPairs: [
    ["foreground", "background", root.tr("Body text"), 4.5],
    ["light_foreground", "background", root.tr("Secondary text"), 4.5],
    ["bright_foreground", "background", root.tr("Headings"), 4.5],
    ["dark_foreground", "background", root.tr("Line numbers"), 3],
    ["muted", "background", root.tr("Comments / muted"), 3],
    ["accent", "background", root.tr("Accent"), 3],
    ["background", "accent", root.tr("Text on accent"), 4.5],
    ["foreground", "selection", root.tr("Selected text"), 4.5],
    ["foreground", "lighter_background", root.tr("Current line"), 4.5],
    ["foreground", "dark_background", root.tr("Status line"), 4.5],
    ["red", "background", root.tr("Error"), 3],
    ["orange", "background", root.tr("Number"), 3],
    ["yellow", "background", root.tr("Warning"), 3],
    ["green", "background", root.tr("Success / string"), 3],
    ["cyan", "background", root.tr("Info"), 3],
    ["blue", "background", root.tr("Function"), 3],
    ["magenta", "background", root.tr("Keyword"), 3]
  ]

  // ============================================================ window
  PanelWindow { // qmllint disable uncreatable-type
    id: win
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    screen: root.targetScreen
    WlrLayershell.namespace: "theme-studio"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.5) }
    MouseArea { anchors.fill: parent; onClicked: keys.forceActiveFocus() }

    Rectangle {
      id: card
      anchors.centerIn: parent
      width: Math.min(parent.width - 40, 1880)
      height: Math.min(parent.height - 40, 1120)
      radius: Math.max(8, Style.cornerRadius)
      color: Color.background
      border.width: 1
      border.color: root.alpha(root.fg, 0.16)
      clip: true

      MouseArea { anchors.fill: parent; onClicked: keys.forceActiveFocus() }

      Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onPressed: function(event) {
          var ctrl = event.modifiers & Qt.ControlModifier
          var shift = event.modifiers & Qt.ShiftModifier
          if (event.key === Qt.Key_Escape) {
            if (root.modal) root.modal = ""
            else root.dismiss()
          } else if (ctrl && event.key === Qt.Key_Z && !shift) root.undo()
          else if (ctrl && (event.key === Qt.Key_Y || (event.key === Qt.Key_Z && shift))) root.redo()
          else if (ctrl && event.key === Qt.Key_S && shift) root.saveAndApply()
          else if (ctrl && event.key === Qt.Key_S) root.save(null)
          else if (ctrl && event.key === Qt.Key_N) root.newTheme(false)
          else if (ctrl && event.key === Qt.Key_I) root.modal = "import"
          else if (ctrl && event.key === Qt.Key_E) root.exportTheme()
          else if (ctrl && event.key === Qt.Key_P) root.livePreview = !root.livePreview
          else if (!ctrl && event.key === Qt.Key_1) root.tab = "desktop"
          else if (!ctrl && event.key === Qt.Key_2) root.tab = "palette"
          else if (!ctrl && event.key === Qt.Key_3) root.tab = "contrast"
          else return
          event.accepted = true
        }
      }

      // -------------------------------------------------------- header
      Rectangle {
        id: header
        width: parent.width
        height: Math.round(Style.font.body * 4.2)
        color: root.alpha(root.fg, 0.03)

        Row {
          anchors.left: parent.left
          anchors.leftMargin: Style.space(18)
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(14)

          Text {
            text: "󰏘"
            color: root.accent
            font.family: Style.font.family
            font.pixelSize: Style.font.heading * 1.5
            anchors.verticalCenter: parent.verticalCenter
          }
          Column {
            visible: !root.compact
            anchors.verticalCenter: parent.verticalCenter
            Text { text: "Theme Studio"; color: root.fg; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true }
            Text { text: root.tr("Omarchy theme designer"); color: Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.caption }
          }

          Rectangle { visible: !root.compact; width: 1; height: header.height * 0.55; color: root.alpha(root.fg, 0.15); anchors.verticalCenter: parent.verticalCenter }

          Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3
            Rectangle {
              width: root.compact ? Style.space(220) : Style.space(300)
              height: Math.round(Style.font.body * 2.3)
              radius: 6
              color: root.alpha(root.fg, 0.06)
              border.width: 1
              border.color: nameInput.activeFocus ? root.accent : root.alpha(root.fg, 0.15)
              TextInput {
                id: nameInput
                anchors.fill: parent
                anchors.leftMargin: 10; anchors.rightMargin: 30
                verticalAlignment: TextInput.AlignVCenter
                text: root.editTitle
                color: root.fg
                font.family: Style.font.family
                font.pixelSize: Style.font.subtitle
                font.bold: true
                selectByMouse: true
                clip: true
                onTextEdited: { root.editTitle = text; root.dirty = true }
                onAccepted: keys.forceActiveFocus()
                Keys.onEscapePressed: function(e) { keys.forceActiveFocus(); e.accepted = true }
              }
              Text {
                anchors.right: parent.right; anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: root.dirty ? "●" : "󰄬"
                color: root.dirty ? "#e5a50a" : Color.muted
                font.family: Style.font.family
                font.pixelSize: Style.font.body
              }
            }
            Text {
              text: root.saveTargetInfo
              color: root.saveTargetInfo.charAt(0) === "⚠" ? "#e5a50a" : Color.muted
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
            }
          }
        }

        Row {
          anchors.right: parent.right
          anchors.rightMargin: Style.space(14)
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(8)

          Text {
            visible: root.busy !== ""
            text: "󰔟 " + root.busy
            color: root.accent
            font.family: Style.font.family
            font.pixelSize: Style.font.body
            anchors.verticalCenter: parent.verticalCenter
          }
          Btn { icon: "󰕌"; tip: root.tr("Undo (Ctrl+Z)"); enabledState: root.undoStack.length > 0; onClicked: root.undo() }
          Btn { icon: "󰑎"; tip: root.tr("Redo (Ctrl+Y)"); enabledState: root.redoStack.length > 0; onClicked: root.redo() }
          Btn {
            icon: root.livePreview ? "󰈈" : "󰈉"
            text: root.compact ? "" : root.tr("Live preview")
            active: root.livePreview
            tip: root.tr("Apply colours to the desktop instantly (Ctrl+P)")
            onClicked: root.livePreview = !root.livePreview
          }
          Btn { icon: "󰆓"; text: root.compact ? "" : root.tr("Save"); tip: root.compact ? root.tr("Save") + " (Ctrl+S)" : "Ctrl+S"; onClicked: root.save(null) }
          Btn { icon: "󰄬"; text: root.tr("Save & apply"); kind: "primary"; tip: "Ctrl+Shift+S"; onClicked: root.saveAndApply() }
          Btn { icon: "󰅖"; kind: "subtle"; tip: root.tr("Close (Esc)"); onClicked: root.dismiss() }
        }
      }

      // -------------------------------------------------------- library (left)
      Rectangle {
        id: library
        anchors.top: header.bottom
        anchors.bottom: parent.bottom
        width: Math.max(Style.space(230), Math.min(Style.space(280), card.width * 0.17))
        color: root.alpha(root.fg, 0.02)

        Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: root.alpha(root.fg, 0.1) }

        Column {
          id: libTop
          x: Style.space(14); y: Style.space(14)
          width: parent.width - Style.space(28)
          spacing: Style.space(10)

          Row {
            spacing: 8
            Text { text: root.tr("Themes"); color: root.fg; font.family: Style.font.family; font.pixelSize: Style.font.subtitle; font.bold: true }
            Text { text: String(root.themes.length); color: Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.subtitle }
          }

          Rectangle {
            width: parent.width
            height: Math.round(Style.font.body * 2.3)
            radius: 6
            color: root.alpha(root.fg, 0.06)
            border.width: 1
            border.color: searchInput.activeFocus ? root.accent : root.alpha(root.fg, 0.12)
            Text {
              x: 10; anchors.verticalCenter: parent.verticalCenter
              text: root.tr("  Search…")
              visible: searchInput.text === ""
              color: Color.muted
              font.family: Style.font.family; font.pixelSize: Style.font.body
            }
            TextInput {
              id: searchInput
              anchors.fill: parent
              anchors.leftMargin: 10; anchors.rightMargin: 10
              verticalAlignment: TextInput.AlignVCenter
              color: root.fg
              font.family: Style.font.family; font.pixelSize: Style.font.body
              selectByMouse: true
              clip: true
              onTextChanged: root.filter = text
              Keys.onEscapePressed: function(e) { text = ""; keys.forceActiveFocus(); e.accepted = true }
            }
          }
        }

        ListView {
          id: themeList
          anchors.top: libTop.bottom
          anchors.topMargin: Style.space(10)
          anchors.bottom: libFooter.top
          anchors.bottomMargin: Style.space(10)
          x: Style.space(8)
          width: parent.width - Style.space(16)
          clip: true
          spacing: 2
          model: root.filteredThemes
          boundsBehavior: Flickable.StopAtBounds

          delegate: Rectangle {
            id: themeRow
            width: themeList.width
            height: Math.round(Style.font.body * 4.2)
            radius: 6
            readonly property bool isSel: modelData.name === root.source.name
            color: isSel ? root.alpha(root.accent, 0.18) : (rowHover.hovered ? root.alpha(root.fg, 0.07) : "transparent")
            border.width: isSel ? 1 : 0
            border.color: root.alpha(root.accent, 0.6)

            HoverHandler { id: rowHover }
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.loadTheme(modelData.name, false)
            }

            Column {
              x: 10
              anchors.verticalCenter: parent.verticalCenter
              width: parent.width - 20
              spacing: 6
              Row {
                spacing: 6
                width: parent.width
                Text {
                  text: modelData.title
                  color: root.fg
                  font.family: Style.font.family
                  font.pixelSize: Style.font.body
                  font.bold: themeRow.isSel
                  elide: Text.ElideRight
                  width: Math.min(implicitWidth, parent.width - 90)
                }
                Text {
                  visible: modelData.current
                  text: root.tr("● active")
                  color: root.accent
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                  text: modelData.user ? (modelData.builtin ? root.tr("modified") : (modelData.git ? "git" : "senin")) : ""
                  color: Color.muted
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  anchors.verticalCenter: parent.verticalCenter
                }
              }
              Row {
                spacing: 2
                Repeater {
                  model: ["background", "foreground", "accent", "red", "yellow", "green", "blue", "magenta"]
                  Rectangle {
                    width: Math.round(Style.font.body * 1.5); height: Math.round(Style.font.body * 0.9)
                    radius: 2
                    color: modelData in themeRow.swatches ? themeRow.swatches[modelData] : "transparent"
                    border.width: 1
                    border.color: root.alpha(root.fg, 0.12)
                  }
                }
              }
            }
            readonly property var swatches: modelData.swatches || ({})

            Btn {
              anchors.right: parent.right
              anchors.rightMargin: 6
              anchors.verticalCenter: parent.verticalCenter
              visible: rowHover.hovered && !modelData.current
              icon: "󰄬"
              tip: root.tr("Apply now")
              fontSize: Style.font.caption
              onClicked: root.applyTheme(modelData.name)
            }
          }
        }

        Grid {
          id: libFooter
          anchors.bottom: parent.bottom
          anchors.bottomMargin: Style.space(14)
          x: Style.space(14)
          columns: 2
          spacing: Style.space(6)
          readonly property real cell: (library.width - Style.space(28) - spacing) / 2
          Btn { width: libFooter.cell; icon: "󰐕"; text: root.tr("New"); tip: "Ctrl+N"; onClicked: root.newTheme(false) }
          Btn { width: libFooter.cell; icon: "󰋺"; text: root.tr("Import"); tip: "Ctrl+I"; onClicked: root.modal = "import" }
          Btn { width: libFooter.cell; icon: "󰈇"; text: root.tr("Export"); tip: "Ctrl+E · .tar.gz"; onClicked: root.exportTheme() }
          Btn { width: libFooter.cell; icon: "󰆴"; text: root.tr("Delete"); kind: "danger"; enabledState: !!root.themeByName(root.source.name) && root.themeByName(root.source.name).user; onClicked: root.deleteTheme() }
        }
      }

      // -------------------------------------------------------- inspector (right)
      Rectangle {
        id: inspector
        anchors.top: header.bottom
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        width: Math.max(Style.space(320), Math.min(Style.space(370), card.width * 0.22))
        color: root.alpha(root.fg, 0.02)

        Rectangle { width: 1; height: parent.height; color: root.alpha(root.fg, 0.1) }

        Flickable {
          id: inspFlick
          anchors.fill: parent
          anchors.margins: Style.space(16)
          contentHeight: insp.implicitHeight
          clip: true
          boundsBehavior: Flickable.StopAtBounds

          Column {
            id: insp
            width: inspFlick.width
            spacing: Style.space(14)

            // selected colour header
            Row {
              width: parent.width
              spacing: Style.space(12)
              Rectangle {
                width: Style.space(52); height: width; radius: 8
                color: root.keyColor(root.selectedKey)
                border.width: 1
                border.color: root.alpha(root.fg, 0.25)
              }
              Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - Style.space(64)
                spacing: 2
                Text { text: root.keyInfo(root.selectedKey).label; color: root.fg; font.family: Style.font.family; font.pixelSize: Style.font.subtitle; font.bold: true; elide: Text.ElideRight; width: parent.width }
                Text { text: root.keyInfo(root.selectedKey).code; color: root.accent; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                Text { text: root.keyInfo(root.selectedKey).hint; color: Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; elide: Text.ElideRight; width: parent.width }
              }
            }

            ColorPicker {
              id: picker
              width: parent.width
              hex: root.keyColor(root.selectedKey)
              onEdited: function(hex, commit) {
                root.setColor(root.selectedKey, hex)
                if (commit) root.lastHistoryKey = ""
              }
            }

            Flow {
              width: parent.width
              spacing: Style.space(6)
              Btn { text: root.tr("Lighten"); icon: "󰖨"; fontSize: Style.font.bodySmall; onClicked: root.adjustSelected(0.05, 0) }
              Btn { text: root.tr("Darken"); icon: "󰖔"; fontSize: Style.font.bodySmall; onClicked: root.adjustSelected(-0.05, 0) }
              Btn { text: root.tr("Saturate"); icon: "󰏘"; fontSize: Style.font.bodySmall; onClicked: root.adjustSelected(0, 0.08) }
              Btn { text: root.tr("Desaturate"); icon: "󰸱"; fontSize: Style.font.bodySmall; onClicked: root.adjustSelected(0, -0.08) }
              Btn {
                text: root.tr("Copy"); icon: "󰆏"; fontSize: Style.font.bodySmall
                onClicked: { Quickshell.execDetached(["wl-copy", root.keyColor(root.selectedKey)]); root.toast(root.tr("%1 copied", root.keyColor(root.selectedKey)), "ok") }
              }
            }

            // ---------------- generate
            SectionTitle { text: root.tr("Generate palette") }
            Flow {
              width: parent.width
              spacing: Style.space(6)
              Repeater {
                model: P.VIBES
                Btn { text: modelData.label; fontSize: Style.font.bodySmall; active: root.vibe === modelData.id; onClicked: root.vibe = modelData.id }
              }
            }
            Flow {
              width: parent.width
              spacing: Style.space(6)
              Repeater {
                model: [{ v: 0, l: root.tr("Independent hues") }, { v: 0.15, l: root.tr("Harmonious") }, { v: 0.35, l: root.tr("Close to accent") }]
                Btn { text: modelData.l; fontSize: Style.font.bodySmall; active: Math.abs(root.lean - modelData.v) < 0.01; onClicked: root.lean = modelData.v }
              }
            }
            Flow {
              width: parent.width
              spacing: Style.space(6)
              Btn {
                icon: "󰁨"; text: root.tr("Generate from accent"); kind: "primary"; fontSize: Style.font.bodySmall
                onClicked: root.replacePalette(P.generate({ mode: root.pal.mode, accent: root.pal.accent, background: root.pal.background, foreground: root.pal.foreground, vibe: root.vibe, lean: root.lean }), root.tr("Colours generated from the accent"))
              }
              Btn { icon: "󰝤"; text: root.tr("Derive shades"); fontSize: Style.font.bodySmall; tip: root.tr("Recalculate background/foreground shades"); onClicked: root.replacePalette(P.deriveShades(root.pal), root.tr("Shades derived")) }
              Btn { icon: "󰌵"; text: root.tr("Derive brights"); fontSize: Style.font.bodySmall; onClicked: root.replacePalette(P.deriveBrights(root.pal), root.tr("Bright colours derived")) }
              Btn { icon: "󰒝"; text: root.tr("Random"); fontSize: Style.font.bodySmall; onClicked: root.replacePalette(P.randomPalette(root.pal.mode), "") }
              Btn { icon: "󰔎"; text: root.pal.mode === "light" ? root.tr("Make dark") : root.tr("Make light"); fontSize: Style.font.bodySmall; onClicked: root.replacePalette(P.flipMode(root.pal), root.tr("Mode switched")) }
            }

            // ---------------- borders
            SectionTitle { text: root.tr("Window border") }
            Flow {
              width: parent.width
              spacing: Style.space(6)
              Btn { text: root.customBorder ? root.tr("Custom colour") : root.tr("Use accent colour"); icon: root.customBorder ? "󰄬" : "󰄱"; active: root.customBorder; fontSize: Style.font.bodySmall; onClicked: root.setCustomBorder(!root.customBorder) }
              Btn { visible: root.customBorder; text: root.tr("Gradient"); icon: "󰕡"; active: root.gradientBorder; fontSize: Style.font.bodySmall; onClicked: root.setGradient(!root.gradientBorder) }
            }
            Row {
              visible: root.customBorder
              spacing: Style.space(8)
              Repeater {
                model: root.gradientBorder ? ["border:active:0", "border:active:1", "border:inactive:0"] : ["border:active:0", "border:inactive:0"]
                Column {
                  spacing: 3
                  Rectangle {
                    width: Style.space(54); height: Style.space(30); radius: 5
                    color: root.keyColor(modelData)
                    border.width: root.selectedKey === modelData ? 2 : 1
                    border.color: root.selectedKey === modelData ? root.fg : root.alpha(root.fg, 0.2)
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.selectKey(modelData) }
                  }
                  Text {
                    text: modelData === "border:inactive:0" ? "pasif" : (modelData === "border:active:1" ? "aktif 2" : "aktif")
                    color: Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.caption
                  }
                }
              }
            }
            Flow {
              visible: root.customBorder && root.gradientBorder
              width: parent.width
              spacing: Style.space(6)
              Repeater {
                model: [0, 45, 90, 135, 180]
                Btn { text: modelData + "°"; fontSize: Style.font.caption; active: root.activeBorder.angle === modelData; onClicked: root.setAngle(modelData) }
              }
            }

            // ---------------- wallpapers
            SectionTitle { text: root.tr("Wallpaper") + (root.wallpapers.length ? "  " + (root.wallIndex + 1) + "/" + root.wallpapers.length : "") }
            Rectangle {
              width: parent.width
              height: Math.round(width * 9 / 16)
              radius: 8
              color: root.alpha(root.fg, 0.05)
              clip: true
              Image {
                anchors.fill: parent
                source: root.currentWallpaper ? "file://" + root.currentWallpaper : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: 640
              }
              Text {
                anchors.centerIn: parent
                visible: !root.currentWallpaper
                text: root.tr("No wallpaper")
                color: Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.body
              }
              Btn {
                visible: root.wallpapers.length > 1
                anchors.left: parent.left; anchors.leftMargin: 6; anchors.verticalCenter: parent.verticalCenter
                icon: "󰅁"; kind: "primary"
                onClicked: root.wallIndex = (root.wallIndex - 1 + root.wallpapers.length) % root.wallpapers.length
              }
              Btn {
                visible: root.wallpapers.length > 1
                anchors.right: parent.right; anchors.rightMargin: 6; anchors.verticalCenter: parent.verticalCenter
                icon: "󰅂"; kind: "primary"
                onClicked: root.wallIndex = (root.wallIndex + 1) % root.wallpapers.length
              }
            }
            Flow {
              width: parent.width
              spacing: Style.space(6)
              Btn { icon: "󰐕"; text: root.tr("Add"); fontSize: Style.font.bodySmall; onClicked: root.openBrowser("wallpaper", "images") }
              Btn { icon: "󰆴"; text: root.tr("Remove"); fontSize: Style.font.bodySmall; enabledState: root.wallpapers.length > 0; onClicked: root.removeWallpaper() }
              Btn { icon: "󰸉"; text: root.tr("Palette from image"); fontSize: Style.font.bodySmall; enabledState: root.wallpapers.length > 0; onClicked: root.paletteFromWallpaper() }
            }

            // ---------------- icons
            SectionTitle { text: root.tr("Icon theme") }
            Row {
              width: parent.width
              spacing: Style.space(6)
              Btn { icon: "󰅁"; onClicked: root.cycleIcons(-1) }
              Rectangle {
                width: parent.width - Style.space(6) * 2 - 2 * Math.round(Style.font.body * 2.4)
                height: Math.round(Style.font.body * 2.4)
                radius: 6
                color: root.alpha(root.fg, 0.06)
                Text {
                  anchors.centerIn: parent
                  text: root.icons || root.tr("(default)")
                  color: root.fg; font.family: Style.font.family; font.pixelSize: Style.font.body
                }
              }
              Btn { icon: "󰅂"; onClicked: root.cycleIcons(1) }
            }

            // ---------------- notes
            SectionTitle { text: root.tr("File") }
            Text {
              width: parent.width
              wrapMode: Text.WordWrap
              visible: root.source.staticFiles && root.source.staticFiles.length > 0
              text: root.tr("⚠ This theme ships fixed config files (%1). Those apps will not pick up colour changes.", (root.source.staticFiles || []).join(", "))
              color: "#e5a50a"; font.family: Style.font.family; font.pixelSize: Style.font.caption
            }
            Text {
              width: parent.width
              wrapMode: Text.WordWrap
              visible: !!root.source.git
              text: root.tr("This theme was installed with git. Saving changes the checkout and 'omarchy theme update' may conflict. Consider saving under a new name.")
              color: Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.caption
            }
            Flow {
              width: parent.width
              spacing: Style.space(6)
              Btn { icon: "󰆏"; text: "colors.toml kopyala"; fontSize: Style.font.bodySmall; onClicked: root.copyToml() }
              Btn {
                icon: "󰉋"; text: root.tr("Open folder"); fontSize: Style.font.bodySmall
                enabledState: !!root.source.user
                onClicked: Quickshell.execDetached(["xdg-open", Quickshell.env("HOME") + "/.config/omarchy/themes/" + root.source.name])
              }
            }
            Item { width: 1; height: Style.space(10) }
          }
        }
      }

      // -------------------------------------------------------- stage (center)
      Item {
        id: stageArea
        anchors.top: header.bottom
        anchors.bottom: parent.bottom
        anchors.left: library.right
        anchors.right: inspector.left
        anchors.margins: Style.space(16)

        Row {
          id: tabs
          spacing: Style.space(6)
          Btn { icon: "󰍹"; text: root.tr("Desktop"); active: root.tab === "desktop"; tip: "1"; onClicked: root.tab = "desktop" }
          Btn { icon: "󰏘"; text: root.tr("Palette"); active: root.tab === "palette"; tip: "2"; onClicked: root.tab = "palette" }
          Btn { icon: "󰆧"; text: root.tr("Contrast"); active: root.tab === "contrast"; tip: "3"; onClicked: root.tab = "contrast" }
        }
        Row {
          anchors.right: parent.right
          anchors.verticalCenter: tabs.verticalCenter
          spacing: Style.space(10)
          Btn {
            text: root.pal.mode === "light" ? root.tr("Light mode") : root.tr("Dark mode")
            icon: root.pal.mode === "light" ? "󰖨" : "󰖔"
            fontSize: Style.font.bodySmall
            tip: root.tr("colors.toml 'mode' value")
            onClicked: { root.pushHistory(""); var p = P.copy(root.pal); p.mode = p.mode === "light" ? "dark" : "light"; root.setPal(p) }
          }
        }

        Rectangle {
          id: stage
          anchors.top: tabs.bottom
          anchors.topMargin: Style.space(12)
          anchors.bottom: strip.top
          anchors.bottomMargin: Style.space(12)
          width: parent.width
          radius: 8
          color: root.alpha(root.fg, 0.04)
          clip: true

          DesktopCanvas {
            id: canvasView
            pal: root.pal
            studio: root
            wallpaper: root.currentWallpaper
            anchors.centerIn: parent
            scale: Math.min((stage.width - 24) / width, (stage.height - 24) / height)
          }

          Rectangle {
            visible: root.tab === "desktop"
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.margins: Style.space(8)
            width: hintText.implicitWidth + Style.space(16)
            height: hintText.implicitHeight + Style.space(8)
            radius: height / 2
            color: root.alpha(Color.background, 0.85)
            Text {
              id: hintText
              anchors.centerIn: parent
              text: root.hoverKey ? root.tr("Click → %1  (%2)", root.keyInfo(root.hoverKey).label, root.keyInfo(root.hoverKey).code) : root.tr("Click an element to pick its colour")
              color: root.hoverKey ? root.fg : Color.muted
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
            }
          }

          // palette page
          Rectangle {
            anchors.fill: parent
            visible: root.tab === "palette"
            color: Color.background
            MouseArea { anchors.fill: parent; hoverEnabled: true }
            Flickable {
              anchors.fill: parent
              anchors.margins: Style.space(18)
              contentHeight: palCol.implicitHeight
              clip: true
              boundsBehavior: Flickable.StopAtBounds
              Column {
                id: palCol
                width: parent.width
                spacing: Style.space(18)
                Repeater {
                  model: P.GROUPS
                  Column {
                    width: palCol.width
                    spacing: Style.space(8)
                    Text { text: modelData.label; color: root.fg; font.family: Style.font.family; font.pixelSize: Style.font.subtitle; font.bold: true }
                    Flow {
                      width: parent.width
                      spacing: Style.space(10)
                      Repeater {
                        model: modelData.keys
                        Rectangle {
                          width: Style.space(156); height: Style.space(92)
                          radius: 8
                          color: root.keyColor(modelData.key)
                          border.width: root.selectedKey === modelData.key ? 3 : 1
                          border.color: root.selectedKey === modelData.key ? root.fg : root.alpha(root.fg, 0.15)
                          Column {
                            anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.margins: 10
                            Text { text: modelData.label; color: P.readableOn(root.keyColor(modelData.key)); font.family: Style.font.family; font.pixelSize: Style.font.body; font.bold: true }
                            Text { text: root.keyColor(modelData.key) + "  " + modelData.key; color: P.readableOn(root.keyColor(modelData.key)); opacity: 0.75; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                          }
                          MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.selectKey(modelData.key) }
                        }
                      }
                    }
                  }
                }
              }
            }
          }

          // contrast page
          Rectangle {
            anchors.fill: parent
            visible: root.tab === "contrast"
            color: Color.background
            MouseArea { anchors.fill: parent; hoverEnabled: true }
            ListView {
              anchors.fill: parent
              anchors.margins: Style.space(18)
              clip: true
              spacing: Style.space(6)
              model: root.contrastPairs
              boundsBehavior: Flickable.StopAtBounds
              header: Text {
                text: root.tr("WCAG contrast ratios · at least 4.5 for text, 3 for large text/icons")
                color: Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.caption
                bottomPadding: Style.space(10)
              }
              delegate: Rectangle {
                id: crow
                width: ListView.view.width
                height: Math.round(Style.font.body * 3.4)
                radius: 6
                color: root.alpha(root.fg, 0.04)
                readonly property real ratio: P.contrast(root.keyColor(modelData[0]), root.keyColor(modelData[1]))
                readonly property real target: modelData[3]
                readonly property string grade: ratio >= 7 ? "AAA" : (ratio >= 4.5 ? "AA" : (ratio >= 3 ? root.tr("AA large") : root.tr("Poor")))
                Row {
                  anchors.verticalCenter: parent.verticalCenter
                  x: 10
                  spacing: Style.space(14)
                  Rectangle {
                    width: Style.space(170); height: crow.height - 12; radius: 4
                    color: root.keyColor(modelData[1])
                    Text {
                      anchors.centerIn: parent
                      text: root.tr("Aa Sample text")
                      color: root.keyColor(modelData[0])
                      font.family: Style.font.family; font.pixelSize: Style.font.body; font.bold: true
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.selectKey(modelData[0]) }
                  }
                  Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(Style.space(140), crow.width - Style.space(170 + 70 + 84 + 110) - Style.space(14) * 4)
                    Text { text: modelData[2]; color: root.fg; font.family: Style.font.family; font.pixelSize: Style.font.body }
                    Text { text: modelData[0] + " / " + modelData[1]; color: Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                  }
                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Style.space(70)
                    text: crow.ratio.toFixed(2)
                    color: root.fg; font.family: Style.font.family; font.pixelSize: Style.font.subtitle; font.bold: true
                  }
                  Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Style.space(84); height: Math.round(Style.font.body * 1.8); radius: height / 2
                    color: crow.ratio >= crow.target ? Qt.rgba(0.3, 0.75, 0.4, 0.25) : Qt.rgba(0.9, 0.3, 0.3, 0.25)
                    Text { anchors.centerIn: parent; text: crow.grade; color: root.fg; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                  }
                  Btn {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: crow.ratio < crow.target
                    text: root.tr("Fix"); icon: "󰁨"; fontSize: Style.font.caption
                    tip: root.tr("Adjust the lightness of %1", modelData[0])
                    onClicked: root.fixContrast(modelData[0], modelData[1], crow.target + 0.05)
                  }
                }
              }
            }
          }
        }

        // swatch strip
        Flow {
          id: strip
          anchors.bottom: parent.bottom
          width: parent.width
          spacing: Style.space(4)
          Repeater {
            id: stripRepeater
            model: P.allKeys().concat(root.customBorder ? (root.gradientBorder ? ["border:active:0", "border:active:1", "border:inactive:0"] : ["border:active:0", "border:inactive:0"]) : [])
            Rectangle {
              width: Math.floor((strip.width - strip.spacing * (stripRepeater.count - 1)) / Math.max(1, stripRepeater.count))
              height: Style.space(30)
              radius: 4
              color: root.keyColor(modelData)
              border.width: root.selectedKey === modelData ? 2 : 1
              border.color: root.selectedKey === modelData ? root.fg : root.alpha(root.fg, 0.15)
              Rectangle {
                visible: root.selectedKey === modelData
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom; anchors.bottomMargin: 3
                width: 6; height: 6; radius: 3
                color: P.readableOn(root.keyColor(modelData))
              }
              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.selectKey(modelData)
                onContainsMouseChanged: root.hoverKey = containsMouse ? modelData : (root.hoverKey === modelData ? "" : root.hoverKey)
              }
            }
          }
        }
      }

      // -------------------------------------------------------- toast
      Rectangle {
        visible: root.toastText !== ""
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Style.space(22)
        width: Math.min(toastRow.implicitWidth + Style.space(32), card.width - 80)
        height: toastRow.implicitHeight + Style.space(20)
        radius: 8
        z: 50
        color: Qt.tint(Color.background, root.toastKind === "error" ? Qt.rgba(0.85, 0.2, 0.25, 0.3) : (root.toastKind === "ok" ? Qt.rgba(0.25, 0.7, 0.4, 0.22) : root.alpha(root.accent, 0.2)))
        border.width: 1
        border.color: root.toastKind === "error" ? "#d0404f" : (root.toastKind === "ok" ? "#4caf6a" : root.accent)
        Row {
          id: toastRow
          anchors.centerIn: parent
          spacing: Style.space(12)
          Text {
            text: (root.toastKind === "error" ? "󰅚  " : (root.toastKind === "ok" ? "󰄬  " : "󰋽  ")) + root.toastText
            color: root.fg
            font.family: Style.font.family
            font.pixelSize: Style.font.body
            wrapMode: Text.WordWrap
            width: Math.min(toastMetrics.width + 4, card.width - 260)
            anchors.verticalCenter: parent.verticalCenter
            TextMetrics { id: toastMetrics; font.family: Style.font.family; font.pixelSize: Style.font.body; text: "󰄬  " + root.toastText }
          }
          Btn {
            visible: root.toastActionLabel !== ""
            text: root.toastActionLabel
            kind: "primary"
            fontSize: Style.font.bodySmall
            onClicked: { var a = root.toastAction; root.toastText = ""; if (a) a() }
          }
        }
      }

      // -------------------------------------------------------- modals
      Rectangle {
        anchors.fill: parent
        visible: root.modal !== ""
        color: Qt.rgba(0, 0, 0, 0.45)
        z: 60
        MouseArea { anchors.fill: parent; onClicked: root.modal = "" }

        // confirm
        Rectangle {
          visible: root.modal === "confirm"
          anchors.centerIn: parent
          width: Style.space(460)
          height: confirmCol.implicitHeight + Style.space(40)
          radius: 10
          color: Color.background
          border.width: 1
          border.color: root.alpha(root.fg, 0.2)
          MouseArea { anchors.fill: parent }
          Column {
            id: confirmCol
            anchors.centerIn: parent
            width: parent.width - Style.space(40)
            spacing: Style.space(18)
            Text {
              width: parent.width
              text: root.confirmText
              wrapMode: Text.WordWrap
              color: root.fg; font.family: Style.font.family; font.pixelSize: Style.font.body
            }
            Row {
              anchors.right: parent.right
              spacing: Style.space(8)
              Btn { text: root.tr("Cancel"); onClicked: root.modal = "" }
              Btn {
                text: root.tr("Yes"); kind: "primary"
                onClicked: { var a = root.confirmAction; root.modal = ""; root.confirmAction = null; if (a) a() }
              }
            }
          }
        }

        // import
        Rectangle {
          visible: root.modal === "import"
          anchors.centerIn: parent
          width: Style.space(640)
          height: importCol.implicitHeight + Style.space(44)
          radius: 10
          color: Color.background
          border.width: 1
          border.color: root.alpha(root.fg, 0.2)
          MouseArea { anchors.fill: parent }
          Column {
            id: importCol
            anchors.centerIn: parent
            width: parent.width - Style.space(44)
            spacing: Style.space(14)
            Text { text: root.tr("󰋺  Import theme"); color: root.fg; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true }
            Text {
              width: parent.width
              wrapMode: Text.WordWrap
              text: root.tr("Supported: .tar.gz / .zip archive, theme folder, colors.toml, alacritty.toml or a git URL (https://github.com/…/omarchy-x-theme). The theme is copied into ~/.config/omarchy/themes and opened in the editor.")
              color: Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.caption
            }
            Row {
              width: parent.width
              spacing: Style.space(8)
              Rectangle {
                width: parent.width - browseBtn.width - Style.space(8)
                height: Math.round(Style.font.body * 2.5)
                radius: 6
                color: root.alpha(root.fg, 0.06)
                border.width: 1
                border.color: importInput.activeFocus ? root.accent : root.alpha(root.fg, 0.15)
                Text {
                  x: 10; anchors.verticalCenter: parent.verticalCenter
                  visible: importInput.text === ""
                  text: root.tr("~/Downloads/my-theme.tar.gz or a git URL")
                  color: Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.body
                }
                TextInput {
                  id: importInput
                  anchors.fill: parent
                  anchors.leftMargin: 10; anchors.rightMargin: 10
                  verticalAlignment: TextInput.AlignVCenter
                  text: root.importSource
                  color: root.fg; font.family: Style.font.family; font.pixelSize: Style.font.body
                  selectByMouse: true
                  clip: true
                  onTextEdited: root.importSource = text
                  onAccepted: root.importTheme()
                }
              }
              Btn { id: browseBtn; icon: "󰉋"; text: root.tr("Browse…"); onClicked: root.openBrowser("import", "themes") }
            }
            Row {
              spacing: Style.space(10)
              Rectangle {
                width: Style.space(18); height: width; radius: 4
                anchors.verticalCenter: parent.verticalCenter
                color: root.importTrust ? root.accent : "transparent"
                border.width: 1
                border.color: root.importTrust ? root.accent : root.alpha(root.fg, 0.4)
                Text { anchors.centerIn: parent; visible: root.importTrust; text: "󰄬"; color: Color.background; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.importTrust = !root.importTrust }
              }
              Text {
                anchors.verticalCenter: parent.verticalCenter
                width: importCol.width - Style.space(30)
                wrapMode: Text.WordWrap
                text: root.tr("I trust this source: also copy .lua files, terminal configs and vscode.json (these can run code)")
                color: root.fg; font.family: Style.font.family; font.pixelSize: Style.font.caption
              }
            }
            Row {
              anchors.right: parent.right
              spacing: Style.space(8)
              Btn { text: root.tr("Cancel"); onClicked: root.modal = "" }
              Btn { icon: "󰋺"; text: root.tr("Import"); kind: "primary"; onClicked: root.importTheme() }
            }
          }
        }

        // file browser
        FileBrowser {
          id: fileBrowser
          visible: root.modal === "browser"
          anchors.centerIn: parent
          width: Math.min(card.width - 120, Style.space(760))
          height: Math.min(card.height - 120, Style.space(620))
          studio: root
          mode: root.browserMode
          allowFolder: root.browserPurpose === "import"
          title: root.browserPurpose === "wallpaper" ? root.tr("Choose wallpaper") : root.tr("Choose a theme to import")
          onChosen: function(path) { root.browserChosen(path) }
          onCancelled: root.modal = root.browserPurpose === "import" ? "import" : ""
        }
      }
    }
  }
}
