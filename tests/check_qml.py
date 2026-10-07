"""Every QML Text must set textFormat explicitly.

Qt's default (AutoText) renders anything that looks like HTML, so theme
names, file names, icon theme names or error messages from an imported
theme could load remote images. Dynamic text must be PlainText; only the
canvas uses StyledText, and it escapes its input."""
import re
import sys
from pathlib import Path

root = Path(__file__).resolve().parent.parent
bad = []
for qml in sorted(list(root.glob("*.qml")) + list(root.glob("components/*.qml"))):
    lines = qml.read_text().split("\n")
    for i, line in enumerate(lines):
        if not re.search(r"\bText \{", line):
            continue
        depth, j, block = 0, i, []
        while j < len(lines):
            block.append(lines[j])
            depth += lines[j].count("{") - lines[j].count("}")
            j += 1
            if depth <= 0:
                break
        body = "\n".join(block)
        if "textFormat" not in body:
            bad.append(f"{qml.relative_to(root)}:{i + 1}")
        elif "StyledText" in body and qml.name != "DesktopCanvas.qml":
            bad.append(f"{qml.relative_to(root)}:{i + 1} (StyledText outside the canvas)")
if bad:
    print("Text items without an explicit safe textFormat:")
    print("\n".join("  " + b for b in bad))
    sys.exit(1)
print("qml: every Text sets textFormat")
