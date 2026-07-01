from pathlib import Path

ROOT = Path(r"C:\Users\Greic\tesis-dislexia-app")

FILES = [
    ROOT / "backend/app/api/seguimiento.py",
    ROOT / "backend/app/schemas/seguimiento_schema.py",
    ROOT / "mobile/lib/features/seguimiento/screens/seguimiento_screen.dart",
    ROOT / "mobile/lib/features/reportes/screens/reportes_screen.dart",
    ROOT / "mobile/lib/features/admin/screens/admin_panel_screen.dart",
]

def fix_text(text: str) -> str:
    for _ in range(3):
        changed = False

        for enc in ("latin1", "cp1252"):
            try:
                fixed = text.encode(enc).decode("utf-8")
                if fixed != text:
                    text = fixed
                    changed = True
            except Exception:
                pass

        replacements = {
            "Â¿": "¿",
            "Â¡": "¡",
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

        for bad, good in replacements.items():
            if bad in text:
                text = text.replace(bad, good)
                changed = True

        if not changed:
            break

    return text

changed_files = []

for path in FILES:
    if not path.exists():
        continue

    original = path.read_text(encoding="utf-8")
    fixed = fix_text(original)

    if fixed != original:
        path.write_text(fixed, encoding="utf-8")
        changed_files.append(path)

print("Archivos corregidos:")
for path in changed_files:
    print(path.relative_to(ROOT))
