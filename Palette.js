.pragma library

// Colour math and palette rules for Theme Studio. Pure functions only: the
// overlay keeps the palette as a plain {key: "#rrggbb"} object.

var GROUPS = [
  { id: "core", label: "Core", keys: [
    { key: "accent", label: "Accent", hint: "Active workspace, focus, borders" },
    { key: "selection", label: "Selection", hint: "Background of selected text" },
    { key: "muted", label: "Muted", hint: "Comments, inactive items" }
  ]},
  { id: "bg", label: "Backgrounds", keys: [
    { key: "background", label: "Background", hint: "Terminal, bar, windows" },
    { key: "dark_background", label: "Dark background", hint: "Status line, notifications" },
    { key: "darker_background", label: "Darker background", hint: "Sidebars, tab strip" },
    { key: "lighter_background", label: "Lighter background", hint: "Current line, input fields" }
  ]},
  { id: "fg", label: "Foregrounds", keys: [
    { key: "foreground", label: "Text", hint: "Main text colour" },
    { key: "dark_foreground", label: "Dim text", hint: "Line numbers, hints" },
    { key: "light_foreground", label: "Light text", hint: "Secondary text" },
    { key: "bright_foreground", label: "Bright text", hint: "Headings, emphasis" }
  ]},
  { id: "ansi", label: "Colours", keys: [
    { key: "red", label: "Red", hint: "Errors, removed lines" },
    { key: "orange", label: "Orange", hint: "Numbers, constants" },
    { key: "yellow", label: "Yellow", hint: "Warnings, types" },
    { key: "green", label: "Green", hint: "Strings, success" },
    { key: "cyan", label: "Cyan", hint: "Links, info" },
    { key: "blue", label: "Blue", hint: "Functions, folders" },
    { key: "magenta", label: "Magenta", hint: "Keywords" },
    { key: "brown", label: "Brown", hint: "Extra accent" }
  ]},
  { id: "bright", label: "Bright colours", keys: [
    { key: "bright_red", label: "Bright red", hint: "" },
    { key: "bright_yellow", label: "Bright yellow", hint: "" },
    { key: "bright_green", label: "Bright green", hint: "" },
    { key: "bright_cyan", label: "Bright cyan", hint: "" },
    { key: "bright_blue", label: "Bright blue", hint: "" },
    { key: "bright_magenta", label: "Bright magenta", hint: "" }
  ]}
]

var BORDER_KEYS = ["hyprland_active_border", "hyprland_inactive_border"]

function allKeys() {
  var out = []
  for (var g = 0; g < GROUPS.length; g++)
    for (var k = 0; k < GROUPS[g].keys.length; k++) out.push(GROUPS[g].keys[k].key)
  return out
}

function info(key) {
  for (var g = 0; g < GROUPS.length; g++)
    for (var k = 0; k < GROUPS[g].keys.length; k++)
      if (GROUPS[g].keys[k].key === key) return GROUPS[g].keys[k]
  if (key === "hyprland_active_border") return { key: key, label: "Active window border", hint: "Border of the focused window" }
  if (key === "hyprland_inactive_border") return { key: key, label: "Inactive window border", hint: "Border of other windows" }
  return { key: key, label: key, hint: "" }
}

// ------------------------------------------------------------- colour math

function clamp(x, a, b) { return Math.max(a, Math.min(b, x)) }

function isHex(s) { return /^#[0-9a-fA-F]{6}$/.test(String(s || "")) }

function normHex(s) {
  var h = String(s || "").trim().replace(/^#/, "")
  if (/^[0-9a-fA-F]{3}$/.test(h)) h = h.split("").map(function(c) { return c + c }).join("")
  if (/^[0-9a-fA-F]{8}$/.test(h)) h = h.substring(0, 6)
  return /^[0-9a-fA-F]{6}$/.test(h) ? "#" + h.toLowerCase() : ""
}

function toRgb(hex) {
  var h = normHex(hex) || "#000000"
  return { r: parseInt(h.substr(1, 2), 16) / 255, g: parseInt(h.substr(3, 2), 16) / 255, b: parseInt(h.substr(5, 2), 16) / 255 }
}

function toHex(r, g, b) {
  function p(x) { var s = Math.round(clamp(x, 0, 1) * 255).toString(16); return s.length < 2 ? "0" + s : s }
  return "#" + p(r) + p(g) + p(b)
}

function toHsl(hex) {
  var c = toRgb(hex), max = Math.max(c.r, c.g, c.b), min = Math.min(c.r, c.g, c.b)
  var h = 0, s = 0, l = (max + min) / 2, d = max - min
  if (d > 0) {
    s = l > 0.5 ? d / (2 - max - min) : d / (max + min)
    if (max === c.r) h = (c.g - c.b) / d + (c.g < c.b ? 6 : 0)
    else if (max === c.g) h = (c.b - c.r) / d + 2
    else h = (c.r - c.g) / d + 4
    h /= 6
  }
  return { h: h, s: s, l: l }
}

function fromHsl(h, s, l) {
  h = ((h % 1) + 1) % 1; s = clamp(s, 0, 1); l = clamp(l, 0, 1)
  if (s === 0) return toHex(l, l, l)
  function f(p, q, t) {
    if (t < 0) t += 1; if (t > 1) t -= 1
    if (t < 1 / 6) return p + (q - p) * 6 * t
    if (t < 1 / 2) return q
    if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6
    return p
  }
  var q = l < 0.5 ? l * (1 + s) : l + s - l * s, p = 2 * l - q
  return toHex(f(p, q, h + 1 / 3), f(p, q, h), f(p, q, h - 1 / 3))
}

function toHsv(hex) {
  var c = toRgb(hex), max = Math.max(c.r, c.g, c.b), min = Math.min(c.r, c.g, c.b), d = max - min
  var h = 0
  if (d > 0) {
    if (max === c.r) h = (c.g - c.b) / d + (c.g < c.b ? 6 : 0)
    else if (max === c.g) h = (c.b - c.r) / d + 2
    else h = (c.r - c.g) / d + 4
    h /= 6
  }
  return { h: h, s: max > 0 ? d / max : 0, v: max }
}

function fromHsv(h, s, v) {
  h = ((h % 1) + 1) % 1
  var i = Math.floor(h * 6), f = h * 6 - i, p = v * (1 - s), q = v * (1 - f * s), t = v * (1 - (1 - f) * s)
  switch (i % 6) {
    case 0: return toHex(v, t, p)
    case 1: return toHex(q, v, p)
    case 2: return toHex(p, v, t)
    case 3: return toHex(p, q, v)
    case 4: return toHex(t, p, v)
    default: return toHex(v, p, q)
  }
}

function mix(a, b, t) {
  var x = toRgb(a), y = toRgb(b)
  return toHex(x.r + (y.r - x.r) * t, x.g + (y.g - x.g) * t, x.b + (y.b - x.b) * t)
}

function luminance(hex) {
  var c = toRgb(hex)
  function lin(v) { return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4) }
  return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b)
}

function contrast(a, b) {
  var la = luminance(a), lb = luminance(b)
  return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05)
}

function isLight(hex) { return luminance(hex) > 0.4 }

function readableOn(hex) { return isLight(hex) ? "#111111" : "#f5f5f5" }

function adjust(hex, dl, ds, dh) {
  var c = toHsl(hex)
  return fromHsl(c.h + (dh || 0), c.s + (ds || 0), c.l + (dl || 0))
}

// ------------------------------------------------------------- borders

// "rgba(8a8588ee) rgba(e2dddcee) 45deg" -> { colors: ["#8a8588", "#e2dddc"], angle: 45 }
function parseBorder(spec) {
  var res = { colors: [], angle: 0 }
  var parts = String(spec || "").trim().split(/\s+/)
  for (var i = 0; i < parts.length; i++) {
    var p = parts[i]
    var m = p.match(/^(-?\d+(?:\.\d+)?)deg$/)
    if (m) { res.angle = Number(m[1]); continue }
    m = p.match(/^rgba?\(([0-9a-fA-F]{6})([0-9a-fA-F]{2})?\)$/)
    if (m) { res.colors.push("#" + m[1].toLowerCase()); continue }
    var h = normHex(p)
    if (h) res.colors.push(h)
  }
  return res
}

function borderSpec(colors, angle, alpha) {
  var a = alpha || "ee"
  var list = []
  for (var i = 0; i < colors.length; i++) if (isHex(colors[i])) list.push("rgba(" + colors[i].substring(1) + a + ")")
  if (list.length > 1 && angle) list.push(Math.round(angle) + "deg")
  return list.join(" ")
}

// Concrete colours for the canvas, falling back the way Omarchy does.
function borderColors(pal, key) {
  var spec = pal[key]
  var parsed = parseBorder(spec)
  if (parsed.colors.length) return parsed
  if (key === "hyprland_active_border") return { colors: [pal.accent || "#888888"], angle: 0 }
  return { colors: ["#595959"], angle: 0 }
}

// ------------------------------------------------------------- generation

function deriveShades(pal) {
  var p = copy(pal)
  var bg = p.background, fg = p.foreground
  var light = p.mode === "light"
  p.dark_background = light ? mix(bg, "#000000", 0.04) : mix(bg, "#000000", 0.25)
  p.darker_background = light ? mix(bg, "#000000", 0.08) : mix(bg, "#000000", 0.45)
  p.lighter_background = mix(bg, fg, light ? 0.08 : 0.12)
  p.selection = mix(bg, p.accent || fg, light ? 0.22 : 0.3)
  p.muted = mix(bg, fg, 0.38)
  p.dark_foreground = mix(fg, bg, 0.5)
  p.light_foreground = mix(fg, bg, 0.12)
  p.bright_foreground = light ? mix(fg, "#000000", 0.3) : mix(fg, "#ffffff", 0.3)
  return p
}

function deriveBrights(pal) {
  var p = copy(pal), light = p.mode === "light"
  var base = ["red", "yellow", "green", "cyan", "blue", "magenta"]
  for (var i = 0; i < base.length; i++)
    if (isHex(p[base[i]])) p["bright_" + base[i]] = adjust(p[base[i]], light ? -0.08 : 0.08, 0.05)
  return p
}

var VIBES = [
  { id: "balanced", label: "Balanced", s: 0.62, l: 0.68, ll: 0.42 },
  { id: "pastel", label: "Pastel", s: 0.75, l: 0.80, ll: 0.55 },
  { id: "neon", label: "Neon", s: 1.0, l: 0.62, ll: 0.45 },
  { id: "muted", label: "Desaturate", s: 0.30, l: 0.64, ll: 0.40 },
  { id: "mono", label: "Mono", s: 0.0, l: 0.70, ll: 0.35 }
]

var HUES = { red: 355, orange: 24, yellow: 44, green: 110, cyan: 178, blue: 215, magenta: 290, brown: 18 }

// Build a whole palette from accent + background + vibe. `lean` (0..1) pulls
// every hue toward the accent hue so the palette feels related.
function generate(opts) {
  var mode = opts.mode || "dark", light = mode === "light"
  var accent = normHex(opts.accent) || "#7aa2f7"
  var vibe = VIBES[0]
  for (var v = 0; v < VIBES.length; v++) if (VIBES[v].id === opts.vibe) vibe = VIBES[v]
  var ah = toHsl(accent).h * 360
  var lean = clamp(opts.lean === undefined ? 0.15 : opts.lean, 0, 1)

  var bg = normHex(opts.background)
  if (!bg) bg = light ? fromHsl(ah / 360, 0.25, 0.95) : fromHsl(ah / 360, 0.25, 0.09)
  var fg = normHex(opts.foreground)
  if (!fg) fg = light ? fromHsl(ah / 360, 0.15, 0.2) : fromHsl(ah / 360, 0.2, 0.87)

  var p = { mode: mode, accent: accent, background: bg, foreground: fg }
  for (var name in HUES) {
    var h = HUES[name]
    var diff = ((ah - h + 540) % 360) - 180
    h = h + diff * lean
    var s = vibe.s, l = light ? vibe.ll : vibe.l
    if (name === "brown") { s = Math.min(s, 0.35); l = light ? 0.32 : 0.42 }
    if (vibe.id === "mono") {
      s = 0.08
      var tint = { red: 0.0, orange: 0.04, yellow: 0.1, green: 0.06, cyan: 0.03, blue: -0.03, magenta: -0.06, brown: -0.18 }[name]
      p[name] = fromHsl(ah / 360, s, (light ? 0.38 : 0.70) + tint)
    } else {
      p[name] = fromHsl(h / 360, s, l)
    }
  }
  p = deriveShades(p)
  p = deriveBrights(p)
  return p
}

// Map ImageMagick histogram colours ({hex,count}) onto a palette.
function fromImage(list, mode) {
  var light = mode === "light"
  var sorted = list.slice().sort(function(a, b) { return luminance(a.hex) - luminance(b.hex) })
  var bgSrc = light ? sorted[sorted.length - 1].hex : sorted[0].hex
  var bg = light ? mix(bgSrc, "#ffffff", 0.75) : mix(bgSrc, "#000000", 0.35)
  // Most vivid frequent colour becomes the accent.
  var best = null, bestScore = -1
  for (var i = 0; i < list.length; i++) {
    var c = toHsl(list[i].hex)
    var score = c.s * (1 - Math.abs(c.l - 0.55)) * Math.log(2 + list[i].count)
    if (score > bestScore) { bestScore = score; best = list[i].hex }
  }
  var acc = toHsl(best || "#7aa2f7")
  var accent = fromHsl(acc.h, Math.max(acc.s, 0.45), light ? 0.42 : 0.66)
  var vibe = acc.s < 0.15 ? "mono" : (acc.s < 0.4 ? "muted" : "balanced")
  return generate({ mode: mode, accent: accent, background: bg, vibe: vibe, lean: 0.25 })
}

function randomPalette(mode) {
  var vibes = ["balanced", "pastel", "neon", "muted"]
  return generate({
    mode: mode,
    accent: fromHsl(Math.random(), 0.55 + Math.random() * 0.4, mode === "light" ? 0.45 : 0.65),
    vibe: vibes[Math.floor(Math.random() * vibes.length)],
    lean: Math.random() * 0.35
  })
}

// Swap a dark palette to light (or back) while keeping its hues.
function flipMode(pal) {
  var p = copy(pal)
  var light = p.mode !== "light"
  p.mode = light ? "light" : "dark"
  var bh = toHsl(p.background), fh = toHsl(p.foreground)
  p.background = fromHsl(bh.h, Math.min(bh.s, 0.35), light ? 0.95 : 0.09)
  p.foreground = fromHsl(fh.h, Math.min(fh.s, 0.3), light ? 0.2 : 0.87)
  var keys = ["red", "orange", "yellow", "green", "cyan", "blue", "magenta", "brown", "accent"]
  for (var i = 0; i < keys.length; i++) {
    if (!isHex(p[keys[i]])) continue
    var c = toHsl(p[keys[i]])
    p[keys[i]] = fromHsl(c.h, c.s, light ? Math.min(c.l, 0.45) : Math.max(c.l, 0.62))
  }
  return deriveBrights(deriveShades(p))
}

// Make sure every palette key exists (imported themes may be partial).
function complete(pal) {
  var p = copy(pal)
  if (!p.mode) p.mode = isHex(p.background) && isLight(p.background) ? "light" : "dark"
  if (!isHex(p.background)) p.background = p.mode === "light" ? "#f4f4f4" : "#16161e"
  if (!isHex(p.foreground)) p.foreground = p.mode === "light" ? "#222222" : "#d8d8d8"
  if (!isHex(p.accent)) p.accent = isHex(p.blue) ? p.blue : "#7aa2f7"
  var shades = deriveShades(p)
  var gen = generate({ mode: p.mode, accent: p.accent, background: p.background, foreground: p.foreground })
  var keys = allKeys()
  for (var i = 0; i < keys.length; i++) {
    var k = keys[i]
    if (!isHex(p[k])) p[k] = isHex(shades[k]) ? shades[k] : gen[k]
  }
  return p
}

function copy(o) {
  var r = {}
  for (var k in o) r[k] = o[k]
  return r
}

function equal(a, b) {
  var k
  for (k in a) if (a[k] !== b[k]) return false
  for (k in b) if (a[k] !== b[k]) return false
  return true
}

function toToml(pal, extras) {
  var order = [["mode"], ["accent", "selection", "muted"],
    ["background", "dark_background", "darker_background", "lighter_background"],
    ["foreground", "dark_foreground", "light_foreground", "bright_foreground"],
    ["red", "yellow", "orange", "green", "cyan", "blue", "magenta", "brown"],
    ["bright_red", "bright_yellow", "bright_green", "bright_cyan", "bright_blue", "bright_magenta"],
    BORDER_KEYS]
  var lines = []
  for (var g = 0; g < order.length; g++) {
    var added = false
    for (var i = 0; i < order[g].length; i++) {
      var v = pal[order[g][i]]
      if (v === undefined || v === "") continue
      lines.push(order[g][i] + " = \"" + v + "\"")
      added = true
    }
    if (added) lines.push("")
  }
  for (var e in (extras || {})) lines.push(e + " = \"" + String(extras[e]).replace(/"/g, "\\\"") + "\"")
  return lines.join("\n").replace(/\n+$/, "") + "\n"
}

function slug(text) {
  var map = { "ç": "c", "ğ": "g", "ı": "i", "ö": "o", "ş": "s", "ü": "u", "â": "a", "î": "i", "û": "u" }
  var s = String(text || "").toLowerCase().replace(/[çğıöşüâîû]/g, function(c) { return map[c] })
  return s.replace(/[^a-z0-9._+-]+/g, "-").replace(/^[-.]+|[-.]+$/g, "")
}

function title(name) {
  return String(name || "").replace(/(^|-)([a-z])/g, function(m, a, b) { return a + b.toUpperCase() }).replace(/-/g, " ")
}
