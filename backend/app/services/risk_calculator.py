def _clamp(value: float, minimum: float, maximum: float) -> float:
    return max(minimum, min(value, maximum))


def _calculate_time_factor(tiempo_promedio_ms: int) -> float:
    """
    Factor provisional:
    - <= 2000 ms: bajo riesgo por tiempo.
    - >= 6000 ms: alto riesgo por tiempo.
    - Entre ambos: escala gradual.
    """
    if tiempo_promedio_ms <= 2000:
        return 0.0

    if tiempo_promedio_ms >= 6000:
        return 1.0

    return (tiempo_promedio_ms - 2000) / 4000


def calculate_risk_from_session(
    total_items: int,
    aciertos_primer_intento: int,
    taps_erroneos_totales: int,
    tiempo_promedio_ms: int,
) -> tuple[float, str]:
    """
    Cálculo heurístico provisional.
    No representa diagnóstico clínico.
    Luego será reemplazado por Random Forest / XGBoost.
    """
    if total_items <= 0:
        return 0.0, "VERDE"

    errores_primer_intento = total_items - aciertos_primer_intento

    error_rate = errores_primer_intento / total_items
    taps_rate = taps_erroneos_totales / total_items
    time_factor = _calculate_time_factor(tiempo_promedio_ms)

    raw_score = (
        0.50 * error_rate +
        0.25 * _clamp(taps_rate, 0.0, 1.0) +
        0.25 * time_factor
    )

    porcentaje_riesgo = round(_clamp(raw_score * 100, 0.0, 100.0), 2)

    if porcentaje_riesgo < 35:
        semaforo = "VERDE"
    elif porcentaje_riesgo < 65:
        semaforo = "AMARILLO"
    else:
        semaforo = "ROJO"

    return porcentaje_riesgo, semaforo

