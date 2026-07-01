from datetime import datetime
from typing import Optional

from sqlmodel import Field, SQLModel


class PrediccionModelo(SQLModel, table=True):
    __tablename__ = "predicciones_modelo"

    id: Optional[int] = Field(default=None, primary_key=True)

    evaluacion_id: int = Field(foreign_key="evaluaciones.id", index=True)

    fuente_prediccion: str = Field(index=True)
    modelo_nombre: Optional[str] = Field(default=None)
    modelo_version: Optional[str] = Field(default=None)

    porcentaje_riesgo: float
    semaforo: str

    probabilidad_verde: Optional[float] = Field(default=None)
    probabilidad_amarillo: Optional[float] = Field(default=None)
    probabilidad_rojo: Optional[float] = Field(default=None)

    feature_vector_json: Optional[str] = Field(default=None)
    probabilidades_json: Optional[str] = Field(default=None)

    creado_en: datetime = Field(default_factory=datetime.utcnow)

