import os

from sqlalchemy import inspect

from sqlmodel import Session, SQLModel, create_engine

DEFAULT_DATABASE_URL = (
    "postgresql+psycopg://dyslexia_user:dyslexia_pass_dev"
    "@localhost:5432/dyslexia_db"
)

DATABASE_URL = os.getenv("DATABASE_URL", DEFAULT_DATABASE_URL)

if DATABASE_URL.startswith("postgres://"):
    DATABASE_URL = DATABASE_URL.replace("postgres://", "postgresql://", 1)

if DATABASE_URL.startswith("postgresql://"):
    DATABASE_URL = DATABASE_URL.replace("postgresql://", "postgresql+psycopg://", 1)

engine = create_engine(
    DATABASE_URL,
    echo=False,
)


def create_db_and_tables() -> None:
    SQLModel.metadata.create_all(engine)
    inspector = inspect(engine)
    columns = {column["name"] for column in inspector.get_columns("evaluaciones")}
    unique_session_id = any(
        index.get("unique") and index["column_names"] == ["local_session_id"]
        for index in inspector.get_indexes("evaluaciones")
    ) or any(
        constraint["column_names"] == ["local_session_id"]
        for constraint in inspector.get_unique_constraints("evaluaciones")
    )
    if not {"local_session_id", "sync_payload_hash"}.issubset(columns) or not unique_session_id:
        raise RuntimeError(
            "Falta la migración de sincronización. "
            "Ejecute python -m app.db.migrate_sync_sessions antes del arranque."
        )


def get_session():
    with Session(engine) as session:
        yield session
