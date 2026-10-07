# Changelog

## 1.0.1

- Security: every QML `Text` now renders as plain text (only the canvas uses
  escaped StyledText), so names, file names or error messages from imported
  themes can no longer trigger HTML image loads.
- Security: `icons.theme` is validated when loading and importing; an invalid
  value is skipped instead of being shown.
- CI checks that every `Text` sets a safe `textFormat`.

## 1.0.0

First public release.

- Live desktop canvas painted from the palette; click any element to edit its colour.
- Palette and WCAG contrast views with one-click contrast fixes.
- HSV colour picker, undo/redo, palette generator (balanced, pastel, neon, muted, mono),
  palette from wallpaper, dark/light flip, gradient window borders.
- Live preview through Omarchy's own template engine, reverted on close.
- Save, apply, export (`.tar.gz`) and import (archive, folder, `colors.toml`,
  `alacritty.toml`, git URL) with Omarchy's untrusted-file rules.
- English and Turkish UI.
