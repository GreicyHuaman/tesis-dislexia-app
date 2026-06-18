from typing import Optional

from pydantic import BaseModel


class LoginRequest(BaseModel):
    email: str
    password: str


class LoginResponse(BaseModel):
    id: int
    nombres: str
    apellidos: str
    email: str
    rol: str
    grado_scope: Optional[int] = None


class CurrentUserPublic(BaseModel):
    id: int
    nombres: str
    apellidos: str
    email: str
    rol: str
    grado_scope: Optional[int] = None
