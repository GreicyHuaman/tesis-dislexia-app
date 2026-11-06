from typing import Optional

from pydantic import BaseModel, ConfigDict, EmailStr, field_validator


def _validate_institutional_email(value: EmailStr) -> EmailStr:
    email = str(value).lower()
    domain = email.rsplit("@", maxsplit=1)[1]

    if domain != "edu.com" and not domain.endswith(".edu.com"):
        raise ValueError(
            "El correo debe ser institucional y terminar en .edu.com."
        )

    return value


class AdminUserCreate(BaseModel):
    nombres: str
    apellidos: str
    email: EmailStr
    rol: str
    password: str
    grado_scope: Optional[int] = None
    activo: bool = True

    @field_validator("email")
    @classmethod
    def validate_institutional_email(cls, value: EmailStr) -> EmailStr:
        return _validate_institutional_email(value)


class AdminUserUpdate(BaseModel):
    nombres: Optional[str] = None
    apellidos: Optional[str] = None
    email: Optional[EmailStr] = None
    rol: Optional[str] = None
    password: Optional[str] = None
    grado_scope: Optional[int] = None
    activo: Optional[bool] = None

    @field_validator("email")
    @classmethod
    def validate_institutional_email(
        cls,
        value: Optional[EmailStr],
    ) -> Optional[EmailStr]:
        if value is None:
            return None

        return _validate_institutional_email(value)


class AdminUserPublic(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    nombres: str
    apellidos: str
    email: str
    rol: str
    grado_scope: Optional[int] = None
    activo: bool
