from datetime import date
from typing import Optional

from pydantic import BaseModel, ConfigDict


class StudentCreate(BaseModel):
    codigo_estudiante: Optional[str] = None
    nombres: str
    apellidos: str
    fecha_nacimiento: Optional[date] = None
    seccion_id: int
    consentimiento_firmado: bool = False
    fecha_consentimiento: Optional[date] = None
    pin_corto: Optional[str] = None
    activo: bool = True


class StudentUpdate(BaseModel):
    codigo_estudiante: Optional[str] = None
    nombres: Optional[str] = None
    apellidos: Optional[str] = None
    fecha_nacimiento: Optional[date] = None
    seccion_id: Optional[int] = None
    consentimiento_firmado: Optional[bool] = None
    fecha_consentimiento: Optional[date] = None
    pin_corto: Optional[str] = None
    nivel_lectura: Optional[int] = None
    nivel_fonologia: Optional[int] = None
    activo: Optional[bool] = None


class StudentPublic(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    codigo_estudiante: Optional[str] = None
    nombres: str
    apellidos: str
    fecha_nacimiento: Optional[date] = None
    seccion_id: Optional[int] = None
    consentimiento_firmado: bool = False
    nivel_lectura: int = 1
    nivel_fonologia: int = 1
    activo: bool


class StudentAdminPublic(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    codigo_estudiante: Optional[str] = None
    nombres: str
    apellidos: str
    fecha_nacimiento: Optional[date] = None
    pin_corto: Optional[str] = None
    seccion_id: Optional[int] = None
    consentimiento_firmado: bool = False
    fecha_consentimiento: Optional[date] = None
    nivel_lectura: int = 1
    nivel_fonologia: int = 1
    activo: bool


class StudentOfflineCacheItem(BaseModel):
    id: int
    codigo_estudiante: Optional[str] = None
    nombres: str
    apellidos: str
    fecha_nacimiento: Optional[date] = None
    pin_corto: str
    seccion_id: Optional[int] = None
    consentimiento_firmado: bool = False
    nivel_lectura: int = 1
    nivel_fonologia: int = 1
    activo: bool

