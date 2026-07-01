from pathlib import Path

path = Path(r"C:\Users\Greic\tesis-dislexia-app\backend\app\main.py")
text = path.read_text(encoding="utf-8")

snippet = '''
@app.middleware("http")
async def add_utf8_charset_for_json(request, call_next):
    response = await call_next(request)
    content_type = response.headers.get("content-type", "")
    if content_type.startswith("application/json") and "charset" not in content_type.lower():
        response.headers["content-type"] = "application/json; charset=utf-8"
    return response
'''

if "add_utf8_charset_for_json" in text:
    print("Middleware UTF-8 ya existe.")
else:
    lines = text.splitlines()
    start = None

    for i, line in enumerate(lines):
        if "app" in line and "FastAPI(" in line:
            start = i
            break

    if start is None:
        raise RuntimeError("No se encontró app = FastAPI(...) en backend/app/main.py")

    balance = 0
    end = start

    for j in range(start, len(lines)):
        balance += lines[j].count("(")
        balance -= lines[j].count(")")
        if balance <= 0:
            end = j
            break

    insert_lines = [""] + snippet.strip().splitlines() + [""]
    lines[end + 1:end + 1] = insert_lines

    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("Middleware UTF-8 agregado en backend/app/main.py")
