from pathlib import Path
import re

ROOT = Path(r"C:\Users\Greic\tesis-dislexia-app")
mobile_lib = ROOT / "mobile" / "lib"

patterns = [
    (
        re.compile(r"jsonDecode\(\s*([A-Za-z_][A-Za-z0-9_]*)\.body\s*\)"),
        lambda m: f"jsonDecode(utf8.decode({m.group(1)}.bodyBytes))",
    ),
    (
        re.compile(r"json\.decode\(\s*([A-Za-z_][A-Za-z0-9_]*)\.body\s*\)"),
        lambda m: f"json.decode(utf8.decode({m.group(1)}.bodyBytes))",
    ),
]

changed = []

for path in mobile_lib.rglob("*.dart"):
    text = path.read_text(encoding="utf-8")
    original = text

    for pattern, replacement in patterns:
        text = pattern.sub(replacement, text)

    if "utf8.decode(" in text and "dart:convert" not in text:
        text = "import 'dart:convert';\n" + text

    if text != original:
        path.write_text(text, encoding="utf-8")
        changed.append(path)

print("Archivos Flutter modificados:")
for path in changed:
    print(path.relative_to(ROOT))

if not changed:
    print("No se encontraron jsonDecode(response.body) pendientes.")
