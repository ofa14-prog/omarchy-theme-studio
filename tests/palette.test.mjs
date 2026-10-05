// node tests/palette.test.mjs — Palette.js and I18n.js are QML ".pragma library"
// files; strip the pragma and evaluate them as plain scripts.
import { readFileSync } from "node:fs"
import assert from "node:assert/strict"
import vm from "node:vm"

function load(file) {
  const ctx = {}
  vm.createContext(ctx)
  vm.runInContext(readFileSync(new URL("../" + file, import.meta.url), "utf8").replace(".pragma library", ""), ctx)
  return ctx
}

const P = load("Palette.js")
const keys = P.allKeys()
assert.equal(keys.length, 25)

for (const mode of ["dark", "light"]) {
  for (const vibe of P.VIBES.map(v => v.id)) {
    const pal = P.generate({ mode, accent: "#e06c75", vibe })
    for (const k of keys) assert.match(pal[k], /^#[0-9a-f]{6}$/, `${mode}/${vibe}/${k}`)
    assert.ok(P.contrast(pal.foreground, pal.background) >= 4.5, `${mode}/${vibe} body contrast`)
  }
}
const partial = P.complete({ background: "#1e1e2e" })
for (const k of keys) assert.ok(P.isHex(partial[k]), k)
assert.equal(P.flipMode(P.generate({ mode: "dark", accent: "#89b4fa" })).mode, "light")
assert.deepEqual(JSON.parse(JSON.stringify(P.parseBorder("rgba(8a8588ee) rgba(e2dddcee) 45deg"))), { colors: ["#8a8588", "#e2dddc"], angle: 45 })
assert.equal(P.borderSpec(["#112233", "#445566"], 45), "rgba(112233ee) rgba(445566ee) 45deg")
assert.equal(P.slug("Benim Güzel Tema!"), "benim-guzel-tema")
assert.equal(P.normHex("#ABC"), "#aabbcc")
assert.equal(Math.round(P.contrast("#000000", "#ffffff")), 21)

const I = load("I18n.js")
assert.equal(I.pick("tr_TR.UTF-8"), "tr")
assert.equal(I.pick("de_DE"), "en")
assert.equal(I.tr("tr", "Imported: %1", ["x"]), "İçe aktarıldı: x")
assert.equal(I.tr("en", "Imported: %1", ["x"]), "Imported: x")
console.log("palette + i18n: ok")
