from typing import Literal, Optional

from pydantic import BaseModel, ConfigDict, field_validator


class _SectionInputValidation(BaseModel):
    @field_validator("grado", mode="before", check_fields=False)
    @classmethod
    def validate_grado(cls, value: object) -> int:
        if type(value) is not int or value != 3:
            raise ValueError("El grado debe ser 3, correspondiente a tercero de primaria.")
        return value

    @field_validator("turno", mode="before", check_fields=False)
    @classmethod
    def validate_turno(cls, value: object) -> str:
        if not isinstance(value, str):
            raise ValueError("Selecciona un turno: Mañana o Tarde.")

        turno = value.strip().upper()
        if turno == "MANANA":
            turno = "MAÑANA"

        if turno not in {"MAÑANA", "TARDE"}:
            raise ValueError("Selecciona un turno: Mañana o Tarde.")
        return turno

    @field_validator("nombre", mode="before", check_fields=False)
    @classmethod
    def validate_nombre(cls, value: object) -> str:
        if not isinstance(value, str) or not value.strip():
            raise ValueError("Ingresa el nombre de la sección.")
        return value.strip().upper()


class SectionCreate(_SectionInputValidation):
    grado: Literal[3] = 3
    nombre: str
    turno: Literal["MAÑANA", "TARDE"]
    activo: bool = True


class SectionUpdate(_SectionInputValidation):
    grado: Optional[Literal[3]] = None
    nombre: Optional[str] = None
    turno: Optional[Literal["MAÑANA", "TARDE"]] = None
    activo: Optional[bool] = None


class SectionPublic(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    grado: int
    nombre: str
    turno: Optional[str] = None
    activo: bool
