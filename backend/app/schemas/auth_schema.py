from typing import Optional

from pydantic import BaseModel, ConfigDict


class LoginRequest(BaseModel):
    email: str
    password: str


class CurrentUserPublic(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    nombres: str
    apellidos: str
    email: str
    rol: str
    grado_scope: Optional[int] = None
    activo: bool


class LoginResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_in_minutes: int

    user: CurrentUserPublic

    # Campos duplicados para mantener compatibilidad con Flutter actual.
    id: int
    nombres: str
    apellidos: str
    email: str
    rol: str
    grado_scope: Optional[int] = None
    activo: bool

