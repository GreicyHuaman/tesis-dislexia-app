from datetime import date
from typing import Optional

from sqlmodel import Field, SQLModel


class Estudiante(SQLModel, table=True):
    __tablename__ = "estudiantes"

    id: Optional[int] = Field(default=None, primary_key=True)

    nombres: str
    apellidos: str
    fecha_nacimiento: Optional[date] = Field(default=None)
    pin_corto: Optional[str] = Field(default=None)
    seccion_id: Optional[int] = Field(default=None)
    activo: bool = Field(default=True)
