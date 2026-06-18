from typing import Optional

from sqlmodel import Field, SQLModel


class Usuario(SQLModel, table=True):
    __tablename__ = "usuarios"

    id: Optional[int] = Field(default=None, primary_key=True)

    nombres: str
    apellidos: str
    email: str = Field(index=True)
    rol: str = Field(index=True)

    password_hash: str

    # Para Psicóloga o Directora, puede limitarse por grado.
    grado_scope: Optional[int] = Field(default=None)

    activo: bool = Field(default=True)
