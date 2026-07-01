from datetime import datetime
from typing import Optional

from sqlmodel import Field, SQLModel


class Evaluacion(SQLModel, table=True):
    __tablename__ = "evaluaciones"

    id: Optional[int] = Field(default=None, primary_key=True)

    estudiante_id: Optional[int] = Field(default=None, foreign_key="estudiantes.id")

    fecha_evaluacion: datetime = Field(default_factory=datetime.utcnow)

    porcentaje_riesgo: Optional[float] = Field(default=None)
    semaforo: Optional[str] = Field(default=None)

    # Campo temporal de apoyo para Sprint 1.
    # Luego lo conectaremos con estudiante_id real mediante PIN.
    tipo_prueba: Optional[str] = Field(default=None)

    total_items: Optional[int] = Field(default=None)
    aciertos_primer_intento: Optional[int] = Field(default=None)
    taps_erroneos_totales: Optional[int] = Field(default=None)
    tiempo_promedio_ms: Optional[int] = Field(default=None)

    nivel_dificultad_aplicado: Optional[int] = Field(default=None)
    total_baja: int = Field(default=0)
    total_media: int = Field(default=0)
    total_alta: int = Field(default=0)
    version_banco_palabras: Optional[str] = Field(default=None)


class DetalleEvaluacion(SQLModel, table=True):
    __tablename__ = "detalles_evaluacion"

    id: Optional[int] = Field(default=None, primary_key=True)

    evaluacion_id: int = Field(foreign_key="evaluaciones.id")

    tipo_prueba: str
    tiempo_respuesta_ms: int
    duracion_drag_drop_ms: Optional[int] = Field(default=None)
    taps_erroneos: int = Field(default=0)
    tipo_error: Optional[str] = Field(default=None)
    complejidad_estimulo: Optional[str] = Field(default=None)
    acierto: bool

    # Campo útil para trazabilidad técnica del estímulo.
    # No reemplaza las columnas principales del diseño.
    stimulus_id: Optional[str] = Field(default=None)
    texto: Optional[str] = Field(default=None)
