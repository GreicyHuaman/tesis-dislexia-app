from typing import Optional

from pydantic import BaseModel, ConfigDict


class SectionCreate(BaseModel):
    grado: int
    nombre: str
    turno: Optional[str] = None
    activo: bool = True


class SectionUpdate(BaseModel):
    grado: Optional[int] = None
    nombre: Optional[str] = None
    turno: Optional[str] = None
    activo: Optional[bool] = None


class SectionPublic(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    grado: int
    nombre: str
    turno: Optional[str] = None
    activo: bool
