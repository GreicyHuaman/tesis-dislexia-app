import json
import random
import re
from dataclasses import dataclass
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]

INPUT_FILES = [
    PROJECT_ROOT / "data" / "raw" / "lectura" / "Pruebalectora1.txt",
    PROJECT_ROOT / "data" / "raw" / "lectura" / "Pruebalectora2.txt",
]

OUTPUT_FILE = (
    PROJECT_ROOT
    / "mobile"
    / "assets"
    / "stimuli"
    / "fonologia_stimuli.json"
)

RANDOM_SEED = 42

MAX_REAL_ITEMS = 140
MAX_PSEUDO_ITEMS = 60

VOWELS = "aeiouáéíóúü"
LETTERS_PATTERN = re.compile(r"^[a-záéíóúüñ]+$", re.IGNORECASE)


@dataclass
class WordItem:
    word: str
    frequency: float
    num_letters: int
    num_syllables: int
    initial_syllable: str
    complexity: str


def read_text_file(path: Path) -> list[str]:
    encodings = ["utf-8-sig", "utf-8", "latin-1"]

    for encoding in encodings:
        try:
            return path.read_text(encoding=encoding).splitlines()
        except UnicodeDecodeError:
            continue

    raise UnicodeDecodeError(
        "unknown",
        b"",
        0,
        1,
        f"No se pudo leer {path}",
    )


def normalize_word(raw_word: str) -> str:
    return raw_word.strip().lower()


def is_valid_word(word: str) -> bool:
    if not word:
        return False

    if not LETTERS_PATTERN.match(word):
        return False

    if len(word) < 3 or len(word) > 11:
        return False

    return True


def extract_initial_syllable(word: str) -> str | None:
    word = word.lower()

    first_vowel_index = None

    for index, char in enumerate(word):
        if char in VOWELS:
            first_vowel_index = index
            break

    if first_vowel_index is None:
        return None

    onset = word[:first_vowel_index]
    vowel_group = word[first_vowel_index]

    next_index = first_vowel_index + 1

    while next_index < len(word) and word[next_index] in VOWELS:
        vowel_group += word[next_index]
        next_index += 1

    if len(onset) == 0:
        return None

    if len(onset) > 2:
        return None

    syllable = onset + vowel_group

    if len(syllable) < 2 or len(syllable) > 4:
        return None

    return syllable


def classify_complexity(
    frequency: float,
    num_letters: int,
    num_syllables: int,
) -> str:
    if num_syllables <= 2 and num_letters <= 5 and frequency >= 40:
        return "BAJA"

    if num_syllables <= 3 and num_letters <= 8:
        return "MEDIA"

    return "ALTA"


def classify_pseudo_complexity(num_letters: int, num_syllables: int) -> str:
    if num_syllables <= 2 and num_letters <= 5:
        return "MEDIA"

    return "ALTA"


def parse_corpus_file(path: Path) -> list[WordItem]:
    if not path.exists():
        print(f"ADVERTENCIA: no existe {path}")
        return []

    lines = read_text_file(path)
    items: list[WordItem] = []

    for line_number, line in enumerate(lines, start=1):
        line = line.strip()

        if not line:
            continue

        parts = line.split()

        if len(parts) < 4:
            continue

        if line_number == 1 and parts[0].lower() in {"word", "palabra"}:
            continue

        word = normalize_word(parts[0])

        if not is_valid_word(word):
            continue

        try:
            frequency = float(parts[1])
            num_letters = int(float(parts[2]))
            num_syllables = int(float(parts[3]))
        except ValueError:
            continue

        if num_syllables < 2 or num_syllables > 5:
            continue

        if frequency < 5:
            continue

        initial_syllable = extract_initial_syllable(word)

        if initial_syllable is None:
            continue

        complexity = classify_complexity(
            frequency=frequency,
            num_letters=num_letters,
            num_syllables=num_syllables,
        )

        items.append(
            WordItem(
                word=word,
                frequency=frequency,
                num_letters=num_letters,
                num_syllables=num_syllables,
                initial_syllable=initial_syllable,
                complexity=complexity,
            )
        )

    return items


def remove_duplicates(items: list[WordItem]) -> list[WordItem]:
    seen_words: set[str] = set()
    unique_items: list[WordItem] = []

    for item in sorted(
        items,
        key=lambda value: value.frequency,
        reverse=True,
    ):
        if item.word in seen_words:
            continue

        seen_words.add(item.word)
        unique_items.append(item)

    return unique_items


def build_syllable_pool(items: list[WordItem]) -> list[str]:
    pool = sorted(
        {
            item.initial_syllable
            for item in items
            if 2 <= len(item.initial_syllable) <= 4
        }
    )

    return pool


def build_options(
    target: str,
    syllable_pool: list[str],
    rng: random.Random,
) -> list[str]:
    distractors = [
        syllable for syllable in syllable_pool
        if syllable != target
    ]

    same_length = [
        syllable for syllable in distractors
        if len(syllable) == len(target)
    ]

    selected: list[str] = []

    rng.shuffle(same_length)
    rng.shuffle(distractors)

    for syllable in same_length + distractors:
        if syllable not in selected:
            selected.append(syllable)

        if len(selected) == 2:
            break

    options = [target] + selected
    rng.shuffle(options)

    return options


def select_real_items(items: list[WordItem]) -> list[WordItem]:
    by_complexity = {
        "BAJA": [],
        "MEDIA": [],
        "ALTA": [],
    }

    for item in items:
        by_complexity[item.complexity].append(item)

    for values in by_complexity.values():
        values.sort(
            key=lambda value: value.frequency,
            reverse=True,
        )

    target_counts = {
        "BAJA": 45,
        "MEDIA": 65,
        "ALTA": 30,
    }

    selected: list[WordItem] = []

    for complexity, target_count in target_counts.items():
        selected.extend(by_complexity[complexity][:target_count])

    selected.sort(
        key=lambda value: (
            {"BAJA": 0, "MEDIA": 1, "ALTA": 2}[value.complexity],
            -value.frequency,
        )
    )

    return selected[:MAX_REAL_ITEMS]


def generate_pseudowords(
    syllable_pool: list[str],
    real_words: set[str],
    rng: random.Random,
    max_items: int,
) -> list[dict]:
    pseudowords: list[dict] = []
    seen: set[str] = set()

    clean_pool = [
        syllable
        for syllable in syllable_pool
        if 2 <= len(syllable) <= 3
    ]

    if len(clean_pool) < 10:
        return pseudowords

    attempts = 0
    max_attempts = max_items * 100

    while len(pseudowords) < max_items and attempts < max_attempts:
        attempts += 1

        num_syllables = rng.choice([2, 2, 3, 3, 4])
        selected_syllables = rng.sample(clean_pool, k=num_syllables)

        pseudoword = "".join(selected_syllables)

        if pseudoword in real_words:
            continue

        if pseudoword in seen:
            continue

        if len(pseudoword) < 4 or len(pseudoword) > 10:
            continue

        if not LETTERS_PATTERN.match(pseudoword):
            continue

        initial_syllable = selected_syllables[0]
        complexity = classify_pseudo_complexity(
            num_letters=len(pseudoword),
            num_syllables=num_syllables,
        )

        seen.add(pseudoword)

        pseudowords.append(
            {
                "word": pseudoword,
                "initial_syllable": initial_syllable,
                "num_syllables": num_syllables,
                "num_letters": len(pseudoword),
                "complexity": complexity,
                "source_syllables": selected_syllables,
            }
        )

    return pseudowords


def main() -> None:
    rng = random.Random(RANDOM_SEED)

    all_items: list[WordItem] = []

    for input_file in INPUT_FILES:
        all_items.extend(parse_corpus_file(input_file))

    unique_items = remove_duplicates(all_items)
    selected_real_items = select_real_items(unique_items)

    syllable_pool = build_syllable_pool(selected_real_items)
    real_words = {item.word for item in unique_items}

    output: list[dict] = []

    for index, item in enumerate(selected_real_items, start=1):
        options = build_options(
            target=item.initial_syllable,
            syllable_pool=syllable_pool,
            rng=rng,
        )

        if len(options) < 3:
            continue

        output.append(
            {
                "id": f"fono_real_{index:03d}_{item.word}",
                "tipo_estimulo": "PALABRA_REAL",
                "fuente": "CORPUS_LECTURA",
                "palabra": item.word,
                "silaba_objetivo": item.initial_syllable,
                "opciones": options,
                "num_silabas": item.num_syllables,
                "num_letras": item.num_letters,
                "frecuencia": round(item.frequency, 4),
                "complejidad_estimulo": item.complexity,
                "tipo_prueba": "FONOLOGIA",
            }
        )

    pseudowords = generate_pseudowords(
        syllable_pool=syllable_pool,
        real_words=real_words,
        rng=rng,
        max_items=MAX_PSEUDO_ITEMS,
    )

    for index, item in enumerate(pseudowords, start=1):
        options = build_options(
            target=item["initial_syllable"],
            syllable_pool=syllable_pool,
            rng=rng,
        )

        if len(options) < 3:
            continue

        output.append(
            {
                "id": f"fono_pseudo_{index:03d}_{item['word']}",
                "tipo_estimulo": "PSEUDOPALABRA",
                "fuente": "GENERADOR_LOCAL_TIPO_WUGGY",
                "palabra": item["word"],
                "silaba_objetivo": item["initial_syllable"],
                "opciones": options,
                "num_silabas": item["num_syllables"],
                "num_letras": item["num_letters"],
                "frecuencia": None,
                "complejidad_estimulo": item["complexity"],
                "tipo_prueba": "FONOLOGIA",
            }
        )

    OUTPUT_FILE.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_FILE.write_text(
        json.dumps(output, indent=2, ensure_ascii=False),
        encoding="utf-8",
    )

    counts = {
        "PALABRA_REAL": 0,
        "PSEUDOPALABRA": 0,
        "BAJA": 0,
        "MEDIA": 0,
        "ALTA": 0,
    }

    for item in output:
        counts[item["tipo_estimulo"]] += 1
        counts[item["complejidad_estimulo"]] += 1

    print(f"Archivo generado: {OUTPUT_FILE}")
    print(f"Total de estímulos fonológicos: {len(output)}")
    print(f"Palabras reales: {counts['PALABRA_REAL']}")
    print(f"Pseudopalabras: {counts['PSEUDOPALABRA']}")
    print(f"BAJA: {counts['BAJA']}")
    print(f"MEDIA: {counts['MEDIA']}")
    print(f"ALTA: {counts['ALTA']}")

    print("\nPrimeros 5 estímulos:")
    print(json.dumps(output[:5], indent=2, ensure_ascii=False))

    print("\nPrimeras 5 pseudopalabras:")
    pseudo_preview = [
        item for item in output
        if item["tipo_estimulo"] == "PSEUDOPALABRA"
    ][:5]
    print(json.dumps(pseudo_preview, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
