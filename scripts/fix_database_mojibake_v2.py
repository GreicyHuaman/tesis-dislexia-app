from __future__ import annotations

from copy import deepcopy
from typing import Any

from sqlalchemy import MetaData, Table, inspect, select

from app.db.session import engine


BAD_MARKERS = ("Ã", "Â", "â", "�")


def has_bad_text(value: str) -> bool:
    return any(marker in value for marker in BAD_MARKERS)


def fix_string(value: str) -> str:
    fixed = value

    for _ in range(5):
        before = fixed

        for encoding in ("cp1252", "latin1"):
            try:
                candidate = fixed.encode(encoding).decode("utf-8")
                if candidate != fixed:
                    fixed = candidate
            except Exception:
                pass

        replacements = {
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
            "DÃaz": "Díaz",
            "DÃ­az": "Díaz",
        }

        for bad, good in replacements.items():
            fixed = fixed.replace(bad, good)

        if fixed == before:
            break

    return fixed


def fix_value(value: Any) -> Any:
    if isinstance(value, str):
        return fix_string(value)

    if isinstance(value, list):
        return [fix_value(item) for item in value]

    if isinstance(value, dict):
        return {
            key: fix_value(item)
            for key, item in value.items()
        }

    return value


def value_has_bad(value: Any) -> bool:
    if isinstance(value, str):
        return has_bad_text(value)

    if isinstance(value, list):
        return any(value_has_bad(item) for item in value)

    if isinstance(value, dict):
        return any(value_has_bad(item) for item in value.values())

    return False


def main() -> None:
    metadata = MetaData()
    metadata.reflect(bind=engine)

    total_rows = 0

    with engine.begin() as connection:
        for table_name, table in metadata.tables.items():
            primary_keys = list(table.primary_key.columns)

            if not primary_keys:
                continue

            rows = connection.execute(select(table)).mappings().all()
            table_updates = 0

            for row in rows:
                updates = {}

                for column in table.columns:
                    column_name = column.name
                    original = row[column_name]

                    if not value_has_bad(original):
                        continue

                    fixed = fix_value(deepcopy(original))

                    if fixed != original:
                        updates[column_name] = fixed

                if not updates:
                    continue

                where_clause = None
                for pk in primary_keys:
                    condition = pk == row[pk.name]
                    where_clause = condition if where_clause is None else where_clause & condition

                connection.execute(
                    table.update().where(where_clause).values(**updates)
                )

                table_updates += 1
                total_rows += 1

            if table_updates:
                print(f"{table_name}: {table_updates} fila(s) corregida(s)")

    print(f"Total filas corregidas: {total_rows}")


if __name__ == "__main__":
    main()
