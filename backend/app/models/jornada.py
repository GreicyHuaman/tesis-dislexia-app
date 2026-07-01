from datetime import datetime
from typing import Optional

from sqlmodel import Field, SQLModel


class JornadaEvaluacion(SQLModel, table=True):
    __tablename__ = "jornadas_evaluacion"

    id: Optional[int] = Field(default=None, primary_key=True)

    seccion_id: int = Field(foreign_key="secciones.id", index=True)
    responsable_id: int = Field(foreign_key="usuarios.id", index=True)

    fecha_inicio: datetime = Field(default_factory=datetime.utcnow)
    fecha_cierre: Optional[datetime] = Field(default=None)
    fecha_expiracion: Optional[datetime] = Field(default=None)

    estado: str = Field(default="ACTIVA", index=True)

    prueba_lectura_activa: bool = Field(default=True)
    prueba_fonologia_activa: bool = Field(default=True)

    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)

