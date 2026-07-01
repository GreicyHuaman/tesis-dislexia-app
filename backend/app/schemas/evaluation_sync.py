from datetime import datetime
from typing import List, Optional

from pydantic import BaseModel, Field


class SyncSessionIn(BaseModel):
    local_session_id: str
    estudiante_id: Optional[int] = None
    tipo_prueba: str
    fecha_inicio: Optional[datetime] = None
    fecha_fin: Optional[datetime] = None
    total_items: int
    aciertos_primer_intento: int = 0
    taps_erroneos_totales: int = 0
    tiempo_promedio_ms: int = 0
    sync_status: Optional[str] = None
    nivel_dificultad_aplicado: Optional[int] = None
    total_baja: int = 0
    total_media: int = 0
    total_alta: int = 0
    version_banco_palabras: Optional[str] = None


class SyncDetailIn(BaseModel):
    local_detail_id: str
    local_session_id: str

    stimulus_id: Optional[str] = None
    texto: Optional[str] = None
    tipo_prueba: str

    tiempo_respuesta_ms: int
    duracion_drag_drop_ms: Optional[int] = None
    taps_erroneos: int = 0
    tipo_error: Optional[str] = None
    complejidad_estimulo: Optional[str] = None
    acierto: bool


class EvaluationSyncRequest(BaseModel):
    sessions: List[SyncSessionIn] = Field(default_factory=list)
    details: List[SyncDetailIn] = Field(default_factory=list)


class SyncedEvaluationOut(BaseModel):
    local_session_id: str
    evaluacion_id: int
    details_inserted: int
    porcentaje_riesgo: Optional[float] = None
    semaforo: Optional[str] = None
    fuente_prediccion: Optional[str] = None
    modelo_nombre: Optional[str] = None
    nivel_actualizado: Optional[int] = None
    nivel_lectura: Optional[int] = None
    nivel_fonologia: Optional[int] = None
    cambio_nivel: Optional[str] = None


class EvaluationSyncResponse(BaseModel):
    status: str
    sessions_received: int
    details_received: int
    evaluations_inserted: int
    details_inserted: int
    synced: List[SyncedEvaluationOut]

