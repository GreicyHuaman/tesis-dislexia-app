from sqlalchemy import text

from app.db.session import engine


STATEMENTS = [
    "ALTER TABLE estudiantes ADD COLUMN IF NOT EXISTS codigo_estudiante VARCHAR",
    "ALTER TABLE estudiantes ADD COLUMN IF NOT EXISTS consentimiento_firmado BOOLEAN NOT NULL DEFAULT FALSE",
    "ALTER TABLE estudiantes ADD COLUMN IF NOT EXISTS fecha_consentimiento DATE",
    "ALTER TABLE estudiantes ADD COLUMN IF NOT EXISTS nivel_lectura INTEGER NOT NULL DEFAULT 1",
    "ALTER TABLE estudiantes ADD COLUMN IF NOT EXISTS nivel_fonologia INTEGER NOT NULL DEFAULT 1",
    "CREATE INDEX IF NOT EXISTS ix_estudiantes_codigo_estudiante ON estudiantes (codigo_estudiante)",
    "CREATE INDEX IF NOT EXISTS ix_estudiantes_seccion_id ON estudiantes (seccion_id)",
    "CREATE INDEX IF NOT EXISTS ix_estudiantes_pin_corto ON estudiantes (pin_corto)",
]


def main() -> None:
    with engine.begin() as connection:
        for statement in STATEMENTS:
            connection.execute(text(statement))

    print("OK: migración Sprint 30B aplicada sobre estudiantes.")


if __name__ == "__main__":
    main()
