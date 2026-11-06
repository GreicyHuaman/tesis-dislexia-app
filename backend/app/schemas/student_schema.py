from datetime import date, datetime, timedelta, timezone
from typing import Optional

from pydantic import BaseModel, ConfigDict, ValidationInfo, field_validator


def validate_student_birth_date(value: date | None) -> date:
    if value is None:
        raise ValueError("Ingresa la fecha de nacimiento del estudiante.")

    today = datetime.now(timezone(timedelta(hours=-5))).date()
    if value > today:
        raise ValueError("La fecha de nacimiento no puede ser futura.")

    age = today.year - value.year - (
        (today.month, today.day) < (value.month, value.day)
    )
    if age not in (8, 9):
        raise ValueError(
            "El estudiante debe tener entre 8 y 9 años cumplidos."
        )
    return value


class _StudentInputValidation(BaseModel):
    @field_validator("nombres", "apellidos", mode="before", check_fields=False)
    @classmethod
    def validate_names(cls, value: object, info: ValidationInfo) -> str:
        if not isinstance(value, str) or not value.strip():
            raise ValueError(f"Ingresa los {info.field_name} del estudiante.")
        return value.strip()

    @field_validator("fecha_nacimiento", check_fields=False)
    @classmethod
    def validate_birth_date(cls, value: date | None) -> date:
        return validate_student_birth_date(value)


class StudentCreate(_StudentInputValidation):
    codigo_estudiante: Optional[str] = None
    nombres: str
    apellidos: str
    fecha_nacimiento: date
    seccion_id: int
    consentimiento_firmado: bool = False
    fecha_consentimiento: Optional[date] = None
    pin_corto: Optional[str] = None
    activo: bool = True


class StudentUpdate(_StudentInputValidation):
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
