from sqlalchemy import inspect, text

from app.db.session import engine


STATEMENTS = (
    "ALTER TABLE evaluaciones ADD COLUMN IF NOT EXISTS local_session_id VARCHAR(128)",
    "ALTER TABLE evaluaciones ADD COLUMN IF NOT EXISTS sync_payload_hash VARCHAR(64)",
    "CREATE UNIQUE INDEX IF NOT EXISTS ix_evaluaciones_local_session_id "
    "ON evaluaciones (local_session_id)",
)


def main() -> None:
    if engine.dialect.name != "postgresql":
        raise RuntimeError("Esta migración requiere PostgreSQL.")
    with engine.begin() as connection:
        if not inspect(connection).has_table("evaluaciones"):
            print("Base nueva: el arranque creará evaluaciones con el esquema actualizado.")
            return
        for statement in STATEMENTS:
            connection.execute(text(statement))
    print("Migración de sincronización aplicada; se conservan las evaluaciones anteriores.")


if __name__ == "__main__":
    main()
