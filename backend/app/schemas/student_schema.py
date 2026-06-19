from datetime import date
from typing import Optional

from pydantic import BaseModel, ConfigDict


class StudentCreate(BaseModel):
    nombres: str
    apellidos: str
    fecha_nacimiento: Optional[date] = None
    pin_corto: str
    seccion_id: Optional[int] = None
    activo: bool = True


class StudentUpdate(BaseModel):
    nombres: Optional[str] = None
    apellidos: Optional[str] = None
    fecha_nacimiento: Optional[date] = None
    pin_corto: Optional[str] = None
    seccion_id: Optional[int] = None
    activo: Optional[bool] = None


class StudentPublic(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    nombres: str
    apellidos: str
    fecha_nacimiento: Optional[date] = None
    seccion_id: Optional[int] = None
    activo: bool


class StudentAdminPublic(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    nombres: str
    apellidos: str
    fecha_nacimiento: Optional[date] = None
    pin_corto: Optional[str] = None
    seccion_id: Optional[int] = None
    activo: bool


class StudentOfflineCacheItem(BaseModel):
    id: int
    nombres: str
    apellidos: str
    fecha_nacimiento: Optional[date] = None
    pin_corto: str
    seccion_id: Optional[int] = None
    activo: bool
