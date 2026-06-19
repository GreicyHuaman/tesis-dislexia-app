from pydantic import BaseModel, ConfigDict


class TeacherSectionCreate(BaseModel):
    usuario_id: int
    seccion_id: int


class TeacherSectionPublic(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    usuario_id: int
    seccion_id: int
