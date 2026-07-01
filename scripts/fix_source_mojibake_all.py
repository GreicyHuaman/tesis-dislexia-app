from pathlib import Path
import re

ROOT = Path(r"C:\Users\Greic\tesis-dislexia-app")

SOURCE_ROOTS = [
    ROOT / "mobile" / "lib",
    ROOT / "backend" / "app",
]

EXTENSIONS = {".dart", ".py"}
BAD_RE = re.compile(r"\S*[\u00c3\u00c2\u00e2\ufffd]\S*")

EXACT = {
    "Â¿": "¿",
    "Â¡": "¡",
    "Â°": "°",
    "Â": "",
    "â€œ": "“",
    "â€": "”",
    "â€˜": "‘",
    "â€™": "’",
    "â€“": "–",
    "â€”": "—",
    "â€¦": "…",
    "â€¢": "•",
    "�": "",
}

def repair_token(match):
    token = match.group(0)

    for enc in ("cp1252", "latin1"):
        try:
            fixed = token.encode(enc).decode("utf-8")
            if not any(marker in fixed for marker in ("Ã", "Â", "â", "�")):
                return fixed
        except Exception:
            pass

    fixed = token
    for bad, good in EXACT.items():
        fixed = fixed.replace(bad, good)

    return fixed

def fix_text(text):
    for bad, good in EXACT.items():
        text = text.replace(bad, good)

    for _ in range(3):
        before = text
        text = BAD_RE.sub(repair_token, text)

        for bad, good in EXACT.items():
            text = text.replace(bad, good)

        if text == before:
            break

    return text

changed = []

for root in SOURCE_ROOTS:
    if not root.exists():
        continue

    for path in root.rglob("*"):
        if not path.is_file():
            continue

        if path.suffix not in EXTENSIONS:
            continue

        original = path.read_text(encoding="utf-8")
        fixed = fix_text(original)

        if fixed != original:
            path.write_text(fixed, encoding="utf-8")
            changed.append(path)

print("Archivos modificados:")
for path in changed:
    print(path.relative_to(ROOT))

if not changed:
    print("No se hicieron cambios.")
