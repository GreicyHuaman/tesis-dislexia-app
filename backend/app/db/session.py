import os

from sqlmodel import Session, SQLModel, create_engine


DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql+psycopg://dyslexia_user:dyslexia_pass_dev@localhost:5432/dyslexia_db",
)

engine = create_engine(
    DATABASE_URL,
    echo=True,
)


def create_db_and_tables() -> None:
    SQLModel.metadata.create_all(engine)


def get_session():
    with Session(engine) as session:
        yield session
