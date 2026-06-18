import argparse
import csv
import json
import re
import unicodedata
from datetime import datetime, timezone
from pathlib import Path


def normalize_text(value: str) -> str:
    value = value.strip().strip('"').strip("'")
    value = re.sub(r"\s+", " ", value)
    return value.lower()


def slugify(value: str) -> str:
    normalized = unicodedata.normalize("NFKD", value)
    ascii_value = normalized.encode("ascii", "ignore").decode("ascii")
    ascii_value = re.sub(r"[^a-zA-Z0-9]+", "_", ascii_value)
    ascii_value = ascii_value.strip("_").lower()
    return ascii_value or "stimulus"


def safe_float(value):
    try:
        return float(str(value).strip().replace(",", "."))
    except Exception:
        return None


def safe_int(value):
    try:
        return int(float(str(value).strip().replace(",", ".")))
    except Exception:
        return None


def infer_complexity(num_letters, sa_num_syll, frq):
    score = 0

    if num_letters is not None:
        if num_letters >= 8:
            score += 2
        elif num_letters >= 6:
            score += 1

    if sa_num_syll is not None:
        if sa_num_syll >= 4:
            score += 2
        elif sa_num_syll == 3:
            score += 1

    if frq is not None:
        if frq < 1:
            score += 2
        elif frq < 10:
            score += 1

    if score <= 1:
        return "BAJA"

    if score <= 3:
        return "MEDIA"

    return "ALTA"


def read_text_file(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8-sig")
    except UnicodeDecodeError:
        return path.read_text(encoding="latin-1")


def detect_delimiter(first_line: str):
    if "\t" in first_line:
        return "\t"
    if ";" in first_line:
        return ";"
    if "," in first_line:
        return ","
    return None


def read_rows(path: Path):
    content = read_text_file(path)
    lines = [line.strip() for line in content.splitlines() if line.strip()]

    if not lines:
        return []

    delimiter = detect_delimiter(lines[0])

    if delimiter is not None:
        reader = csv.DictReader(lines, delimiter=delimiter)
        rows = []

        for row in reader:
            rows.append({
                str(key).strip().lower(): value
                for key, value in row.items()
                if key is not None
            })

        return rows

    header = re.split(r"\s+", lines[0].strip())
    header = [column.strip().lower() for column in header]

    rows = []

    for line in lines[1:]:
        values = re.split(r"\s+", line.strip())
        row = {}

        for index, column in enumerate(header):
            row[column] = values[index] if index < len(values) else ""

        rows.append(row)

    return rows


def build_stimulus(row, source_file: Path, index: int, stimulus_type: str):
    word = normalize_text(row.get("word", ""))

    if not word:
        return None

    frq = safe_float(row.get("frq"))
    num_letters = safe_int(row.get("num_letters"))
    sa_num_syll = safe_int(row.get("sa_num_syll"))

    slug = slugify(word)

    return {
        "id": f"lectura_{stimulus_type.lower()}_{index:04d}_{slug}",
        "texto": word,
        "tipo_prueba": "LECTURA",
        "tipo_estimulo": stimulus_type,
        "frq": frq,
        "num_letters": num_letters,
        "sa_num_syll": sa_num_syll,
        "complejidad_estimulo": infer_complexity(
            num_letters=num_letters,
            sa_num_syll=sa_num_syll,
            frq=frq,
        ),
        "audio_asset": f"assets/audio/lectura/{slug}.mp3",
        "fuente": "EsPal",
        "fuente_archivo": source_file.name,
        "orden": index,
    }


def convert(input_folder: Path, output_file: Path, stimulus_type: str):
    txt_files = sorted(input_folder.glob("*.txt"))

    if not txt_files:
        raise FileNotFoundError(f"No se encontraron archivos .txt en: {input_folder}")

    stimuli = []
    seen_words = set()
    index = 1

    for txt_file in txt_files:
        rows = read_rows(txt_file)

        for row in rows:
            stimulus = build_stimulus(
                row=row,
                source_file=txt_file,
                index=index,
                stimulus_type=stimulus_type,
            )

            if stimulus is None:
                continue

            if stimulus["texto"] in seen_words:
                continue

            seen_words.add(stimulus["texto"])
            stimuli.append(stimulus)
            index += 1

    output = {
        "schema_version": "1.0.0",
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "tipo_prueba": "LECTURA",
        "source": "EsPal",
        "total_stimuli": len(stimuli),
        "stimuli": stimuli,
    }

    output_file.parent.mkdir(parents=True, exist_ok=True)
    output_file.write_text(
        json.dumps(output, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )

    print("JSON generado correctamente.")
    print(f"Archivo: {output_file}")
    print(f"Total de estimulos: {len(stimuli)}")


def main():
    parser = argparse.ArgumentParser()

    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument(
        "--stimulus-type",
        choices=["PALABRA", "PSEUDOPALABRA"],
        default="PALABRA",
    )

    args = parser.parse_args()

    convert(
        input_folder=Path(args.input),
        output_file=Path(args.output),
        stimulus_type=args.stimulus_type,
    )


if __name__ == "__main__":
    main()
