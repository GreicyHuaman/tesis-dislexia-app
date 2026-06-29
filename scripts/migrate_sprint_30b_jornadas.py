from sqlalchemy import text

from app.db.session import engine


STATEMENTS = [
    """
    CREATE TABLE IF NOT EXISTS jornadas_evaluacion (
        id SERIAL PRIMARY KEY,
        seccion_id INTEGER NOT NULL REFERENCES secciones(id),
        responsable_id INTEGER NOT NULL REFERENCES usuarios(id),
        fecha_inicio TIMESTAMP NOT NULL,
        fecha_cierre TIMESTAMP NULL,
        fecha_expiracion TIMESTAMP NULL,
        estado VARCHAR NOT NULL DEFAULT 'ACTIVA',
        prueba_lectura_activa BOOLEAN NOT NULL DEFAULT TRUE,
        prueba_fonologia_activa BOOLEAN NOT NULL DEFAULT TRUE,
        created_at TIMESTAMP NOT NULL,
        updated_at TIMESTAMP NOT NULL
    )
    """,
    "CREATE INDEX IF NOT EXISTS ix_jornadas_evaluacion_seccion_id ON jornadas_evaluacion (seccion_id)",
    "CREATE INDEX IF NOT EXISTS ix_jornadas_evaluacion_responsable_id ON jornadas_evaluacion (responsable_id)",
    "CREATE INDEX IF NOT EXISTS ix_jornadas_evaluacion_estado ON jornadas_evaluacion (estado)",
]


def main() -> None:
    with engine.begin() as connection:
        for statement in STATEMENTS:
            connection.execute(text(statement))

    print("OK: migración Sprint 30B aplicada sobre jornadas_evaluacion.")


if __name__ == "__main__":
    main()
