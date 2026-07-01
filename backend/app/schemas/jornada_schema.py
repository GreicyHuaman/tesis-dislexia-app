from datetime import datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field


class JornadaActivateRequest(BaseModel):
    seccion_id: int
    prueba_lectura_activa: bool = True
    prueba_fonologia_activa: bool = True
    duracion_horas: int = Field(default=8, ge=1, le=12)


class JornadaPublic(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    seccion_id: int
    responsable_id: int
    fecha_inicio: datetime
    fecha_cierre: Optional[datetime] = None
    fecha_expiracion: Optional[datetime] = None
    estado: str
    prueba_lectura_activa: bool
    prueba_fonologia_activa: bool
    created_at: datetime
    updated_at: datetime

