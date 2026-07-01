from pathlib import Path
import re

ROOT = Path(r"C:\Users\Greic\tesis-dislexia-app")

FILES = [
    ROOT / "mobile/lib/features/seguimiento/screens/seguimiento_screen.dart",
    ROOT / "mobile/lib/features/reportes/screens/reportes_screen.dart",
    ROOT / "mobile/lib/features/admin/screens/admin_panel_screen.dart",
    ROOT / "mobile/lib/core/models/seguimiento_models.dart",
    ROOT / "mobile/lib/core/services/seguimiento_service.dart",
    ROOT / "backend/app/api/seguimiento.py",
    ROOT / "backend/app/schemas/seguimiento_schema.py",
]

EXACT = {
    "SesiÃ³n": "Sesión",
    "sesiÃ³n": "sesión",
    "evaluaciÃ³n": "evaluación",
    "EvaluaciÃ³n": "Evaluación",
    "observaciÃ³n": "observación",
    "ObservaciÃ³n": "Observación",
    "derivaciÃ³n": "derivación",
    "DerivaciÃ³n": "Derivación",
    "prÃ³xima": "próxima",
    "PrÃ³xima": "Próxima",
    "secciÃ³n": "sección",
    "SecciÃ³n": "Sección",
    "semÃ¡foro": "semáforo",
    "SemÃ¡foro": "Semáforo",
    "fonolÃ³gica": "fonológica",
    "FonolÃ³gica": "Fonológica",
    "clÃ­nico": "clínico",
    "ClÃ­nico": "Clínico",
    "diagnÃ³stico": "diagnóstico",
    "DiagnÃ³stico": "Diagnóstico",
    "dÃ­as": "días",
    "DÃ­as": "Días",
    "Al dÃ­a": "Al día",
    "al dÃ­a": "al día",
    "categorÃ­as": "categorías",
    "CategorÃ­as": "Categorías",
    "pedagÃ³gico": "pedagógico",
    "PedagÃ³gico": "Pedagógico",
    "contraseÃ±a": "contraseña",
    "ContraseÃ±a": "Contraseña",
    "aÃºn": "aún",
    "AÃºn": "Aún",
    "Ã¡": "á",
    "Ã©": "é",
    "Ã­": "í",
    "Ã³": "ó",
    "Ãº": "ú",
    "Ã±": "ñ",
    "Ã": "Á",
    "Ã‰": "É",
    "Ã": "Í",
    "Ã“": "Ó",
    "Ãš": "Ú",
    "Ã‘": "Ñ",
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

BAD_RE = re.compile(r"[\u00c3\u00c2\u00e2\ufffd]")

def repair_token(match: re.Match[str]) -> str:
    token = match.group(0)

    for enc in ("latin1", "cp1252"):
        try:
            fixed = token.encode(enc).decode("utf-8")
            if not BAD_RE.search(fixed):
                return fixed
        except Exception:
            pass

    fixed = token
    for bad, good in EXACT.items():
        fixed = fixed.replace(bad, good)

    return fixed

def fix_text(text: str) -> str:
    for bad, good in EXACT.items():
        text = text.replace(bad, good)

    text = re.sub(r"\S*[\u00c3\u00c2\u00e2\ufffd]\S*", repair_token, text)

    for bad, good in EXACT.items():
        text = text.replace(bad, good)

    return text

changed = []

for path in FILES:
    if not path.exists():
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
    print("No hubo cambios.")
