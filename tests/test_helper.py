"""Tests for bin/theme-studio. They run against a fake HOME and a fake
OMARCHY_PATH, so they need neither Omarchy nor a running shell."""

import io
import json
import os
import subprocess
import sys
import tarfile
import tempfile
import unittest
import zipfile
from pathlib import Path

HELPER = Path(__file__).resolve().parent.parent / "bin" / "theme-studio"

CATPPUCCIN = """mode = "dark"
accent = "#89b4fa"
background = "#1e1e2e"
foreground = "#cdd6f4"
red = "#f38ba8"
active_border_color = "#d6d3de"
"""


class HelperTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        root = Path(self.tmp.name)
        self.home = root / "home"
        self.omarchy = root / "omarchy"
        theme = self.omarchy / "themes" / "catppuccin"
        (theme / "backgrounds").mkdir(parents=True)
        (theme / "colors.toml").write_text(CATPPUCCIN)
        (theme / "icons.theme").write_text("Yaru-purple\n")
        (theme / "neovim.lua").write_text("return {}\n")
        (theme / "backgrounds" / "1.png").write_bytes(b"\x89PNG fake")
        (self.home / ".config/omarchy/themes").mkdir(parents=True)
        state = self.home / ".local/state/omarchy/current"
        state.mkdir(parents=True)
        (state / "theme.name").write_text("catppuccin\n")
        self.env = dict(os.environ, HOME=str(self.home), OMARCHY_PATH=str(self.omarchy),
                        THEME_STUDIO_LANG="en", PATH="/usr/bin:/bin")

    def tearDown(self):
        self.tmp.cleanup()

    def run_helper(self, *args):
        res = subprocess.run([sys.executable, str(HELPER), *args], env=self.env,
                             capture_output=True, text=True, timeout=60)
        self.assertEqual(res.stderr, "")
        return json.loads(res.stdout)

    @property
    def user_themes(self):
        return self.home / ".config/omarchy/themes"

    def test_list_and_load(self):
        r = self.run_helper("list")
        self.assertTrue(r["ok"])
        self.assertEqual(r["current"], "catppuccin")
        self.assertEqual(r["themes"][0]["swatches"]["accent"], "#89b4fa")
        r = self.run_helper("load", "catppuccin")
        self.assertTrue(r["ok"])
        self.assertEqual(r["colors"]["background"], "#1e1e2e")
        self.assertEqual(r["extras"], {"active_border_color": "#d6d3de"})
        self.assertEqual(r["icons"], "Yaru-purple")
        self.assertEqual(len(r["wallpapers"]), 1)

    def test_rejects_bad_names(self):
        for name in ["../x", "", ".hidden", "a/b", "-rf"]:
            self.assertFalse(self.run_helper("load", name)["ok"], name)

    def test_save_derives_from_base_and_writes_files(self):
        payload = {"name": "My Theme", "base": "catppuccin", "icons": "Yaru-red",
                   "colors": {"mode": "dark", "accent": "#ff0000", "background": "#000000",
                              "hyprland_active_border": "rgba(ff0000ee) #00ff00 45deg"},
                   "extras": {"ok_key": "#ffffff", "evil": "x\"\nos.execute('id')"},
                   "wallpapers": [str(self.omarchy / "themes/catppuccin/backgrounds/1.png")],
                   "previewImage": "/etc/passwd"}
        r = self.run_helper("save", json.dumps(payload))
        self.assertTrue(r["ok"], r)
        dest = self.user_themes / "my-theme"
        text = (dest / "colors.toml").read_text()
        self.assertIn('accent = "#ff0000"', text)
        self.assertIn("ok_key", text)
        self.assertNotIn("evil", text)
        self.assertEqual((dest / "icons.theme").read_text().strip(), "Yaru-red")
        self.assertTrue((dest / "neovim.lua").is_file())
        self.assertTrue((dest / "backgrounds/1.png").is_file())
        self.assertFalse((dest / "preview.png").exists())

    def test_save_rejects_injection(self):
        bad = [{"accent": "#ff0000\"; x"}, {"mode": "neon"},
               {"hyprland_active_border": "rgba(ff0000ee) \") os.execute(\"id"}]
        for colors in bad:
            r = self.run_helper("save", json.dumps({"name": "x", "colors": colors}))
            self.assertFalse(r["ok"], colors)

    def test_export_import_roundtrip_skips_code_files(self):
        out = Path(self.tmp.name) / "out"
        r = self.run_helper("export", "catppuccin", str(out))
        self.assertTrue(r["ok"], r)
        r = self.run_helper("import", r["path"])
        self.assertTrue(r["ok"], r)
        self.assertEqual(r["name"], "catppuccin")
        self.assertIn("neovim.lua", r["skipped"])
        self.assertFalse((self.user_themes / "catppuccin/neovim.lua").exists())
        # Importing again never overwrites.
        r2 = self.run_helper("import", str(out / "omarchy-catppuccin-theme.tar.gz"), "--trust")
        self.assertEqual(r2["name"], "catppuccin-2")
        self.assertTrue((self.user_themes / "catppuccin-2/neovim.lua").exists())

    def test_import_rejects_path_traversal(self):
        evil = Path(self.tmp.name) / "evil.tar.gz"
        with tarfile.open(evil, "w:gz") as tar:
            data = b'background = "#000000"\n'
            info = tarfile.TarInfo("../../escaped/colors.toml")
            info.size = len(data)
            tar.addfile(info, io.BytesIO(data))
        r = self.run_helper("import", str(evil))
        self.assertFalse(r["ok"])
        self.assertFalse((Path(self.tmp.name) / "escaped").exists())

        evil_zip = Path(self.tmp.name) / "evil.zip"
        with zipfile.ZipFile(evil_zip, "w") as z:
            z.writestr("../escaped.toml", 'background = "#000000"\n')
        self.assertFalse(self.run_helper("import", str(evil_zip))["ok"])

    def test_import_single_colors_file(self):
        f = Path(self.tmp.name) / "sunset.toml"
        f.write_text(CATPPUCCIN)
        r = self.run_helper("import", str(f))
        self.assertTrue(r["ok"], r)
        self.assertEqual(r["name"], "sunset")

    def test_untrusted_icons_theme_never_reaches_the_ui(self):
        evil = '<img src="https://attacker.example/beacon.png">'
        src = Path(self.tmp.name) / "evil-theme"
        src.mkdir()
        (src / "colors.toml").write_text(CATPPUCCIN)
        (src / "icons.theme").write_text(evil)
        r = self.run_helper("import", str(src))
        self.assertTrue(r["ok"], r)
        self.assertIn("icons.theme", r["skipped"])
        self.assertFalse((self.user_themes / r["name"] / "icons.theme").exists())
        # Even if such a file is placed by hand, load() refuses to return it.
        (self.user_themes / r["name"] / "icons.theme").write_text(evil)
        self.assertEqual(self.run_helper("load", r["name"])["icons"], "")

    def test_delete_rules(self):
        self.assertFalse(self.run_helper("delete", "catppuccin")["ok"])  # built-in only
        (self.user_themes / "mine").mkdir()
        self.assertTrue(self.run_helper("delete", "mine")["ok"])
        self.assertFalse((self.user_themes / "mine").exists())

    def test_ls_and_doctor(self):
        r = self.run_helper("ls", str(self.omarchy / "themes/catppuccin"), "images")
        self.assertTrue(r["ok"])
        self.assertEqual([e["name"] for e in r["entries"]], ["backgrounds"])
        r = self.run_helper("doctor")
        self.assertTrue(r["ok"])
        self.assertIsInstance(r["missing"], list)
        self.assertEqual(r["omarchyPath"], str(self.omarchy))

    def test_turkish_messages(self):
        self.env["THEME_STUDIO_LANG"] = "tr_TR.UTF-8"
        self.assertEqual(self.run_helper("load", "nope")["error"], "Tema bulunamadı: nope")


if __name__ == "__main__":
    unittest.main()
