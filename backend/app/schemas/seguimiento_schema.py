from datetime import date, datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field


class SeguimientoPublic(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    estudiante_id: int
    evaluacion_id: Optional[int] = None
    fecha_seguimiento: datetime
    semana_iso: Optional[str] = None
    porcentaje_riesgo: Optional[float] = None
    semaforo: Optional[str] = None
    prioridad: Optional[str] = None
    tendencia: Optional[str] = None
    accion_sugerida: Optional[str] = None
    proxima_evaluacion: Optional[date] = None
    observacion_docente: Optional[str] = None
    categorias_json: Optional[str] = None
    estado: str
    responsable_id: Optional[int] = None
    responsable_nombre: Optional[str] = None
    responsable_cargo: Optional[str] = None
    created_at: datetime
    updated_at: datetime


class SeguimientoItem(BaseModel):
    estudiante_id: int
    estudiante_nombre: str
    seccion_id: Optional[int] = None

    seguimiento_id: Optional[int] = None
    evaluacion_id: Optional[int] = None
    ultima_fecha_evaluacion: Optional[datetime] = None
    dias_desde_ultima_evaluacion: Optional[int] = None

    porcentaje_riesgo: Optional[float] = None
    semaforo: Optional[str] = None

    estado_semanal: str
    prioridad: str
    tendencia: str
    accion_sugerida: str
    proxima_evaluacion: Optional[date] = None

    observacion_docente: Optional[str] = None
    categorias: list[str] = Field(default_factory=list)
    estado: Optional[str] = None
    responsable_nombre: Optional[str] = None


class SeguimientoResumenResponse(BaseModel):
    total_estudiantes: int
    sin_evaluacion: int
    al_dia: int
    vence_hoy: int
    vencida: int
    prioridad_alta: int
    prioridad_media: int
    prioridad_baja: int


class SeguimientoObservacionCreate(BaseModel):
    estudiante_id: int
    evaluacion_id: Optional[int] = None
    observacion_docente: Optional[str] = None
    categorias: list[str] = Field(default_factory=list)
    estado: str = "ABIERTO"


class SeguimientoUpdate(BaseModel):
    observacion_docente: Optional[str] = None
    categorias: Optional[list[str]] = None
    estado: Optional[str] = None
    prioridad: Optional[str] = None
    accion_sugerida: Optional[str] = None


class SeguimientoHistorialResponse(BaseModel):
    estudiante_id: int
    estudiante_nombre: str
    seccion_id: Optional[int] = None
    actual: SeguimientoItem
    observaciones: list[SeguimientoPublic]
