"""Every tr("...") string in the QML must have a Turkish entry in I18n.js."""
import json
import re
import sys
from pathlib import Path

root = Path(__file__).resolve().parent.parent
table_src = (root / "I18n.js").read_text()
table = json.loads(re.search(r"tr: (\{.*?\n  \})", table_src, re.S).group(1))
used = set()
for qml in list(root.glob("*.qml")) + list(root.glob("components/*.qml")):
    used |= set(m.encode().decode("unicode_escape").encode("latin-1").decode("utf-8")
                for m in re.findall(r'\btr\("((?:[^"\\]|\\.)*)"', qml.read_text()))
palette = (root / "Palette.js").read_text()
used |= set(re.findall(r'(?:label|hint): "([^"]+)"', palette))
missing = sorted(s for s in used if s and s not in table)
if missing:
    print("Missing Turkish translations:")
    for s in missing:
        print("  ", s)
    sys.exit(1)
print(f"i18n: {len(used)} strings translated")
