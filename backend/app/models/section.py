from typing import Optional

from sqlmodel import Field, SQLModel


class Seccion(SQLModel, table=True):
    __tablename__ = "secciones"

    id: Optional[int] = Field(default=None, primary_key=True)

    grado: int
    nombre: str
    turno: Optional[str] = Field(default=None)
    activo: bool = Field(default=True)


class DocenteSeccion(SQLModel, table=True):
    __tablename__ = "docente_seccion"

    id: Optional[int] = Field(default=None, primary_key=True)

    usuario_id: int = Field(foreign_key="usuarios.id")
    seccion_id: int = Field(foreign_key="secciones.id")

