from sqlalchemy import text

from app.db.session import engine


SQL_STATEMENTS = [
    "ALTER TABLE evaluaciones ADD COLUMN IF NOT EXISTS nivel_dificultad_aplicado INTEGER",
    "ALTER TABLE evaluaciones ADD COLUMN IF NOT EXISTS total_baja INTEGER NOT NULL DEFAULT 0",
    "ALTER TABLE evaluaciones ADD COLUMN IF NOT EXISTS total_media INTEGER NOT NULL DEFAULT 0",
    "ALTER TABLE evaluaciones ADD COLUMN IF NOT EXISTS total_alta INTEGER NOT NULL DEFAULT 0",
    "ALTER TABLE evaluaciones ADD COLUMN IF NOT EXISTS version_banco_palabras VARCHAR",
    "CREATE INDEX IF NOT EXISTS ix_evaluaciones_estudiante_tipo_fecha ON evaluaciones (estudiante_id, tipo_prueba, fecha_evaluacion)",
]


def main() -> None:
    with engine.begin() as connection:
        for statement in SQL_STATEMENTS:
            connection.execute(text(statement))

    print("OK: migracion Sprint 32 aplicada sobre evaluaciones.")


if __name__ == "__main__":
    main()
