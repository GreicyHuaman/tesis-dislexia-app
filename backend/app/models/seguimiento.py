from datetime import date, datetime
from typing import Optional

from sqlmodel import Field, SQLModel


class SeguimientoEstudiante(SQLModel, table=True):
    __tablename__ = "seguimientos_estudiante"

    id: Optional[int] = Field(default=None, primary_key=True)

    estudiante_id: int = Field(foreign_key="estudiantes.id", index=True)
    evaluacion_id: Optional[int] = Field(
        default=None,
        foreign_key="evaluaciones.id",
        index=True,
    )

    fecha_seguimiento: datetime = Field(default_factory=datetime.utcnow)
    semana_iso: Optional[str] = Field(default=None, index=True)

    porcentaje_riesgo: Optional[float] = Field(default=None)
    semaforo: Optional[str] = Field(default=None, index=True)

    prioridad: Optional[str] = Field(default=None, index=True)
    tendencia: Optional[str] = Field(default=None, index=True)
    accion_sugerida: Optional[str] = Field(default=None)
    proxima_evaluacion: Optional[date] = Field(default=None, index=True)

    observacion_docente: Optional[str] = Field(default=None)
    categorias_json: Optional[str] = Field(default=None)

    estado: str = Field(default="ABIERTO", index=True)

    responsable_id: Optional[int] = Field(
        default=None,
        foreign_key="usuarios.id",
        index=True,
    )
    responsable_nombre: Optional[str] = Field(default=None)
    responsable_cargo: Optional[str] = Field(default=None)

    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)
