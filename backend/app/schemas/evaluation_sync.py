from datetime import datetime, timezone
from typing import List, Literal, Optional

from pydantic import BaseModel, Field, StrictBool, field_validator, model_validator


class SyncSessionIn(BaseModel):
    local_session_id: str = Field(min_length=1, max_length=128)
    estudiante_id: int = Field(strict=True, gt=0)
    tipo_prueba: Literal["LECTURA", "FONOLOGIA"]
    fecha_inicio: datetime
    fecha_fin: datetime
    total_items: int = Field(strict=True, ge=10, le=10)
    aciertos_primer_intento: int = Field(strict=True, ge=0, le=10)
    taps_erroneos_totales: int = Field(strict=True, ge=0)
    tiempo_promedio_ms: int = Field(strict=True, ge=0)
    sync_status: Literal["COMPLETED_PENDING_SYNC"]
    nivel_dificultad_aplicado: Optional[int] = Field(default=None, ge=1, le=3)
    total_baja: int = Field(default=0, strict=True, ge=0)
    total_media: int = Field(default=0, strict=True, ge=0)
    total_alta: int = Field(default=0, strict=True, ge=0)
    version_banco_palabras: Optional[str] = None

    @field_validator("fecha_inicio", "fecha_fin")
    @classmethod
    def normalize_dates(cls, value: datetime) -> datetime:
        if value.tzinfo is None:
            return value.replace(tzinfo=timezone.utc)
        return value.astimezone(timezone.utc)

    @model_validator(mode="after")
    def validate_dates(self) -> "SyncSessionIn":
        if self.fecha_fin < self.fecha_inicio:
            raise ValueError("La fecha final no puede preceder al inicio.")
        return self


class SyncDetailIn(BaseModel):
    local_detail_id: str = Field(min_length=1, max_length=160)
    local_session_id: str = Field(min_length=1, max_length=128)

    stimulus_id: str = Field(min_length=1)
    texto: Optional[str] = None
    tipo_prueba: Literal["LECTURA", "FONOLOGIA"]

    tiempo_respuesta_ms: int = Field(strict=True, ge=0)
    duracion_drag_drop_ms: Optional[int] = Field(default=None, strict=True, ge=0)
    taps_erroneos: int = Field(default=0, strict=True, ge=0)
    tipo_error: Optional[str] = None
    complejidad_estimulo: Literal["BAJA", "MEDIA", "ALTA"]
    acierto: StrictBool

    @model_validator(mode="after")
    def validate_first_attempt(self) -> "SyncDetailIn":
        if self.acierto != (self.taps_erroneos == 0):
            raise ValueError("El acierto al primer intento no coincide con los errores.")
        return self


class EvaluationSyncRequest(BaseModel):
    sessions: List[SyncSessionIn] = Field(default_factory=list)
    details: List[SyncDetailIn] = Field(default_factory=list)

    @model_validator(mode="after")
    def validate_complete_sessions(self) -> "EvaluationSyncRequest":
        sessions = {item.local_session_id: item for item in self.sessions}
        if len(sessions) != len(self.sessions):
            raise ValueError("El lote contiene sesiones repetidas.")
        details_by_session: dict[str, list[SyncDetailIn]] = {
            session_id: [] for session_id in sessions
        }
        detail_ids: set[str] = set()
        for detail in self.details:
            if detail.local_session_id not in sessions:
                raise ValueError("Hay respuestas sin una sesión correspondiente.")
            if detail.local_detail_id in detail_ids:
                raise ValueError("El lote contiene respuestas repetidas.")
            detail_ids.add(detail.local_detail_id)
            details_by_session[detail.local_session_id].append(detail)
        for session_id, session in sessions.items():
            details = details_by_session[session_id]
            if len(details) != session.total_items:
                raise ValueError("Solo se pueden enviar evaluaciones completas de diez ítems.")
            if len({detail.stimulus_id for detail in details}) != len(details):
                raise ValueError("La evaluación contiene estímulos repetidos.")
            if any(detail.tipo_prueba != session.tipo_prueba for detail in details):
                raise ValueError("Las respuestas no corresponden al tipo de prueba.")
            if (
                sum(detail.acierto for detail in details) != session.aciertos_primer_intento
                or sum(detail.taps_erroneos for detail in details) != session.taps_erroneos_totales
                or (sum(detail.tiempo_respuesta_ms for detail in details) + len(details) // 2)
                // len(details) != session.tiempo_promedio_ms
            ):
                raise ValueError("Los totales no coinciden con las respuestas.")
            supplied = (session.total_baja, session.total_media, session.total_alta)
            counted = tuple(
                sum(detail.complejidad_estimulo == level for detail in details)
                for level in ("BAJA", "MEDIA", "ALTA")
            )
            if sum(supplied) > 0 and supplied != counted:
                raise ValueError("La distribución no coincide con los estímulos.")
        return self


class SyncedEvaluationOut(BaseModel):
    local_session_id: str
    evaluacion_id: int
    details_inserted: int
    details_confirmed: int
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
