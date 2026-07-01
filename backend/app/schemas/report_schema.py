from datetime import datetime
from typing import Optional

from pydantic import BaseModel


class EvaluationReportItem(BaseModel):
    id: int
    estudiante_id: Optional[int] = None
    estudiante_nombre: Optional[str] = None
    seccion_id: Optional[int] = None

    fecha_evaluacion: datetime
    tipo_prueba: Optional[str] = None

    total_items: Optional[int] = None
    aciertos_primer_intento: Optional[int] = None
    taps_erroneos_totales: Optional[int] = None
    tiempo_promedio_ms: Optional[int] = None

    porcentaje_riesgo: Optional[float] = None
    semaforo: Optional[str] = None

    fuente_prediccion: Optional[str] = None
    modelo_nombre: Optional[str] = None
    modelo_version: Optional[str] = None
    probabilidad_verde: Optional[float] = None
    probabilidad_amarillo: Optional[float] = None
    probabilidad_rojo: Optional[float] = None


class SemaforoSummaryItem(BaseModel):
    semaforo: str
    total: int


class ReportSummaryResponse(BaseModel):
    total_evaluaciones: int
    porcentaje_promedio_riesgo: Optional[float] = None
    semaforos: list[SemaforoSummaryItem]


class StudentTestProfile(BaseModel):
    tipo_prueba: str
    total_evaluaciones: int

    porcentaje_promedio_riesgo: Optional[float] = None
    ultimo_porcentaje_riesgo: Optional[float] = None
    ultimo_semaforo: Optional[str] = None
    ultima_fecha: Optional[datetime] = None

    promedio_tiempo_ms: Optional[float] = None
    promedio_errores: Optional[float] = None

    total_verde: int = 0
    total_amarillo: int = 0
    total_rojo: int = 0
    total_sin_resultado: int = 0


class StudentRiskProfileResponse(BaseModel):
    estudiante_id: int
    estudiante_nombre: Optional[str] = None
    seccion_id: Optional[int] = None

    total_evaluaciones: int
    porcentaje_promedio_general: Optional[float] = None
    ultimo_porcentaje_riesgo_general: Optional[float] = None
    ultimo_semaforo_general: Optional[str] = None
    ultima_fecha_general: Optional[datetime] = None

    pruebas: list[StudentTestProfile]

