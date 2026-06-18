from typing import Optional

from pydantic import BaseModel


class MlDatasetItem(BaseModel):
    evaluacion_id: int
    estudiante_id: Optional[int] = None
    seccion_id: Optional[int] = None

    tipo_prueba: Optional[str] = None
    tipo_prueba_lectura: int
    tipo_prueba_fonologia: int
    tipo_prueba_otro: int

    total_items: int
    aciertos_primer_intento: int
    errores_primer_intento: int
    error_rate: float

    taps_erroneos_totales: int
    taps_rate: float

    tiempo_promedio_ms: int
    tiempo_min_ms: Optional[int] = None
    tiempo_max_ms: Optional[int] = None
    tiempo_std_ms: Optional[float] = None

    items_drag_drop: int
    drag_drop_rate: float
    tiempo_promedio_drag_drop_ms: int
    errores_drag_drop: int

    items_palabra_real: int
    items_pseudopalabra: int
    pseudopalabra_rate: float
    errores_palabra_real: int
    errores_pseudopalabra: int
    tiempo_promedio_palabra_real_ms: int
    tiempo_promedio_pseudopalabra_ms: int

    total_baja: int
    total_media: int
    total_alta: int
    total_sin_complejidad: int

    errores_baja: int
    errores_media: int
    errores_alta: int
    errores_sin_complejidad: int

    porcentaje_riesgo: Optional[float] = None
    semaforo: Optional[str] = None
