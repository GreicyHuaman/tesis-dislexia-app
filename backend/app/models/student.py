from datetime import date
from typing import Optional

from sqlmodel import Field, SQLModel


class Estudiante(SQLModel, table=True):
    __tablename__ = "estudiantes"

    id: Optional[int] = Field(default=None, primary_key=True)

    nombres: str
    apellidos: str
    fecha_nacimiento: Optional[date] = Field(default=None)

    codigo_estudiante: Optional[str] = Field(default=None, index=True)

    pin_corto: Optional[str] = Field(default=None, index=True)

    seccion_id: Optional[int] = Field(
        default=None,
        foreign_key="secciones.id",
        index=True,
    )

    consentimiento_firmado: bool = Field(default=False)
    fecha_consentimiento: Optional[date] = Field(default=None)

    nivel_lectura: int = Field(default=1)
    nivel_fonologia: int = Field(default=1)

    activo: bool = Field(default=True)

