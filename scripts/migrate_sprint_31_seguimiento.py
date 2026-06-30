from sqlalchemy import text

from app.db.session import engine


SQL_STATEMENTS = [
    """
    CREATE TABLE IF NOT EXISTS seguimientos_estudiante (
        id SERIAL PRIMARY KEY,
        estudiante_id INTEGER NOT NULL REFERENCES estudiantes(id),
        evaluacion_id INTEGER NULL REFERENCES evaluaciones(id),
        fecha_seguimiento TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        semana_iso VARCHAR NULL,
        porcentaje_riesgo DOUBLE PRECISION NULL,
        semaforo VARCHAR NULL,
        prioridad VARCHAR NULL,
        tendencia VARCHAR NULL,
        accion_sugerida TEXT NULL,
        proxima_evaluacion DATE NULL,
        observacion_docente TEXT NULL,
        categorias_json TEXT NULL,
        estado VARCHAR NOT NULL DEFAULT 'ABIERTO',
        responsable_id INTEGER NULL REFERENCES usuarios(id),
        responsable_nombre VARCHAR NULL,
        responsable_cargo VARCHAR NULL,
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
    )
    """,
    "CREATE INDEX IF NOT EXISTS ix_seguimiento_estudiante_id ON seguimientos_estudiante(estudiante_id)",
    "CREATE INDEX IF NOT EXISTS ix_seguimiento_evaluacion_id ON seguimientos_estudiante(evaluacion_id)",
    "CREATE INDEX IF NOT EXISTS ix_seguimiento_prioridad ON seguimientos_estudiante(prioridad)",
    "CREATE INDEX IF NOT EXISTS ix_seguimiento_estado ON seguimientos_estudiante(estado)",
    "CREATE INDEX IF NOT EXISTS ix_seguimiento_semana_iso ON seguimientos_estudiante(semana_iso)",
]


def main() -> None:
    with engine.begin() as connection:
        for statement in SQL_STATEMENTS:
            connection.execute(text(statement))

    print("Migración Sprint 31 aplicada: seguimientos_estudiante.")


if __name__ == "__main__":
    main()
