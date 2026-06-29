from pydantic import BaseModel, Field


class StudentImportRowResult(BaseModel):
    row_number: int
    status: str
    message: str
    estudiante_id: int | None = None
    codigo_estudiante: str | None = None
    nombres: str | None = None
    apellidos: str | None = None
    seccion_id: int | None = None
    pin_corto: str | None = None


class StudentImportResponse(BaseModel):
    filename: str
    total_rows: int
    created_count: int
    updated_count: int
    skipped_count: int
    error_count: int
    results: list[StudentImportRowResult] = Field(default_factory=list)
