from typing import Optional

from pydantic import BaseModel, ConfigDict


class AdminUserCreate(BaseModel):
    nombres: str
    apellidos: str
    email: str
    rol: str
    password: str
    grado_scope: Optional[int] = None
    activo: bool = True


class AdminUserUpdate(BaseModel):
    nombres: Optional[str] = None
    apellidos: Optional[str] = None
    email: Optional[str] = None
    rol: Optional[str] = None
    password: Optional[str] = None
    grado_scope: Optional[int] = None
    activo: Optional[bool] = None


class AdminUserPublic(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    nombres: str
    apellidos: str
    email: str
    rol: str
    grado_scope: Optional[int] = None
    activo: bool
