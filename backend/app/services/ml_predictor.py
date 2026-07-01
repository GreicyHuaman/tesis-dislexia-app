from dataclasses import dataclass
from math import sqrt
from pathlib import Path
from typing import Any, Optional

import joblib


MODEL_PATH = (
    Path(__file__).resolve().parents[1]
    / "ml_artifacts"
    / "random_forest_model.joblib"
)

_model_bundle: Optional[dict[str, Any]] = None


@dataclass
class RiskPredictionResult:
    porcentaje_riesgo: float
    semaforo: str
    fuente_prediccion: str
    modelo_nombre: str
    modelo_version: str | None
    probabilidades: dict[str, float]
    features: dict[str, float | int]


def _safe_divide(numerator: int | float, denominator: int | float) -> float:
    if denominator == 0:
        return 0.0

    return round(numerator / denominator, 4)


def _std(values: list[int]) -> float:
    if not values:
        return 0.0

    mean = sum(values) / len(values)
    variance = sum((value - mean) ** 2 for value in values) / len(values)

    return round(sqrt(variance), 2)


def _average(values: list[int]) -> int:
    if not values:
        return 0

    return round(sum(values) / len(values))


def _load_model_bundle() -> Optional[dict[str, Any]]:
    global _model_bundle

    if _model_bundle is not None:
        return _model_bundle

    if not MODEL_PATH.exists():
        return None

    try:
        loaded = joblib.load(MODEL_PATH)

        if not isinstance(loaded, dict):
            return None

        model = loaded.get("model")
        feature_columns = loaded.get("feature_columns")
        label_mapping = loaded.get("label_mapping")
        inverse_label_mapping = loaded.get("inverse_label_mapping")

        if model is None or not feature_columns or not inverse_label_mapping:
            return None

        if isinstance(label_mapping, dict) and len(label_mapping) < 2:
            return None

        _model_bundle = loaded

        return _model_bundle
    except Exception:
        return None


def _normalize_inverse_mapping(
    inverse_label_mapping: dict[Any, Any],
) -> dict[int, str]:
    normalized: dict[int, str] = {}

    for key, value in inverse_label_mapping.items():
        try:
            normalized[int(key)] = str(value)
        except Exception:
            continue

    return normalized


def _tipo_prueba_flags(tipo_prueba: str | None) -> tuple[int, int, int]:
    normalized = (tipo_prueba or "").upper()

    tipo_prueba_lectura = 1 if normalized == "LECTURA" else 0
    tipo_prueba_fonologia = 1 if normalized == "FONOLOGIA" else 0
    tipo_prueba_otro = 1 if normalized not in {"LECTURA", "FONOLOGIA"} else 0

    return tipo_prueba_lectura, tipo_prueba_fonologia, tipo_prueba_otro


def _tipo_estimulo_fonologico(detail) -> str:
    tipo_prueba = (detail.tipo_prueba or "").upper()

    if tipo_prueba != "FONOLOGIA":
        return "NO_APLICA"

    texto = (detail.texto or "").strip()
    first_part = texto.split("|", 1)[0].strip().upper()

    if first_part == "PSEUDOPALABRA":
        return "PSEUDOPALABRA"

    if first_part == "PALABRA_REAL":
        return "PALABRA_REAL"

    return "PALABRA_REAL"


def build_features_from_sync(
    local_session,
    local_details: list,
) -> dict[str, float | int]:
    total_items = local_session.total_items or len(local_details)

    aciertos_primer_intento = local_session.aciertos_primer_intento or 0

    errores_primer_intento = max(
        total_items - aciertos_primer_intento,
        0,
    )

    taps_erroneos_totales = local_session.taps_erroneos_totales or 0

    tiempos = [
        int(detail.tiempo_respuesta_ms)
        for detail in local_details
        if detail.tiempo_respuesta_ms is not None
    ]

    tiempo_promedio_ms = local_session.tiempo_promedio_ms or (
        round(sum(tiempos) / len(tiempos)) if tiempos else 0
    )

    drag_durations = [
        int(detail.duracion_drag_drop_ms)
        for detail in local_details
        if detail.duracion_drag_drop_ms is not None
    ]

    items_drag_drop = len(drag_durations)

    tiempo_promedio_drag_drop_ms = _average(drag_durations)

    errores_drag_drop = sum(
        int(detail.taps_erroneos)
        for detail in local_details
        if detail.duracion_drag_drop_ms is not None
        or (detail.tipo_error or "").upper().startswith("DRAG")
    )

    palabra_real_times: list[int] = []
    pseudopalabra_times: list[int] = []

    items_palabra_real = 0
    items_pseudopalabra = 0
    errores_palabra_real = 0
    errores_pseudopalabra = 0

    for detail in local_details:
        tipo_estimulo = _tipo_estimulo_fonologico(detail)

        if tipo_estimulo == "PALABRA_REAL":
            items_palabra_real += 1
            palabra_real_times.append(int(detail.tiempo_respuesta_ms))

            if not detail.acierto:
                errores_palabra_real += 1

        elif tipo_estimulo == "PSEUDOPALABRA":
            items_pseudopalabra += 1
            pseudopalabra_times.append(int(detail.tiempo_respuesta_ms))

            if not detail.acierto:
                errores_pseudopalabra += 1

    complexity_totals = {
        "BAJA": 0,
        "MEDIA": 0,
        "ALTA": 0,
        "SIN_COMPLEJIDAD": 0,
    }

    complexity_errors = {
        "BAJA": 0,
        "MEDIA": 0,
        "ALTA": 0,
        "SIN_COMPLEJIDAD": 0,
    }

    for detail in local_details:
        complexity = (
            detail.complejidad_estimulo or "SIN_COMPLEJIDAD"
        ).upper()

        if complexity not in complexity_totals:
            complexity = "SIN_COMPLEJIDAD"

        complexity_totals[complexity] += 1

        if not detail.acierto:
            complexity_errors[complexity] += 1

    (
        tipo_prueba_lectura,
        tipo_prueba_fonologia,
        tipo_prueba_otro,
    ) = _tipo_prueba_flags(local_session.tipo_prueba)

    return {
        "tipo_prueba_lectura": tipo_prueba_lectura,
        "tipo_prueba_fonologia": tipo_prueba_fonologia,
        "tipo_prueba_otro": tipo_prueba_otro,
        "total_items": total_items,
        "aciertos_primer_intento": aciertos_primer_intento,
        "errores_primer_intento": errores_primer_intento,
        "error_rate": _safe_divide(
            errores_primer_intento,
            total_items,
        ),
        "taps_erroneos_totales": taps_erroneos_totales,
        "taps_rate": _safe_divide(
            taps_erroneos_totales,
            total_items,
        ),
        "tiempo_promedio_ms": tiempo_promedio_ms,
        "tiempo_min_ms": min(tiempos) if tiempos else 0,
        "tiempo_max_ms": max(tiempos) if tiempos else 0,
        "tiempo_std_ms": _std(tiempos),
        "items_drag_drop": items_drag_drop,
        "drag_drop_rate": _safe_divide(
            items_drag_drop,
            total_items,
        ),
        "tiempo_promedio_drag_drop_ms": tiempo_promedio_drag_drop_ms,
        "errores_drag_drop": errores_drag_drop,
        "items_palabra_real": items_palabra_real,
        "items_pseudopalabra": items_pseudopalabra,
        "pseudopalabra_rate": _safe_divide(
            items_pseudopalabra,
            total_items,
        ),
        "errores_palabra_real": errores_palabra_real,
        "errores_pseudopalabra": errores_pseudopalabra,
        "tiempo_promedio_palabra_real_ms": _average(palabra_real_times),
        "tiempo_promedio_pseudopalabra_ms": _average(pseudopalabra_times),
        "total_baja": complexity_totals["BAJA"],
        "total_media": complexity_totals["MEDIA"],
        "total_alta": complexity_totals["ALTA"],
        "total_sin_complejidad": complexity_totals["SIN_COMPLEJIDAD"],
        "errores_baja": complexity_errors["BAJA"],
        "errores_media": complexity_errors["MEDIA"],
        "errores_alta": complexity_errors["ALTA"],
        "errores_sin_complejidad": complexity_errors["SIN_COMPLEJIDAD"],
    }


def _risk_percentage_from_prediction(
    semaforo: str,
    probability_by_label: dict[str, float],
) -> float:
    if probability_by_label:
        verde = probability_by_label.get("VERDE", 0.0)
        amarillo = probability_by_label.get("AMARILLO", 0.0)
        rojo = probability_by_label.get("ROJO", 0.0)

        risk = (
            verde * 15.0
            + amarillo * 55.0
            + rojo * 90.0
        )

        return round(risk, 2)

    normalized = semaforo.upper()

    if normalized == "ROJO":
        return 85.0

    if normalized == "AMARILLO":
        return 55.0

    return 15.0


def predict_risk_from_sync(
    local_session,
    local_details: list,
) -> Optional[RiskPredictionResult]:
    bundle = _load_model_bundle()

    if bundle is None:
        return None

    model = bundle["model"]
    feature_columns = bundle["feature_columns"]
    inverse_label_mapping = _normalize_inverse_mapping(
        bundle["inverse_label_mapping"],
    )

    features = build_features_from_sync(
        local_session=local_session,
        local_details=local_details,
    )

    row = [
        features.get(column, 0)
        for column in feature_columns
    ]

    try:
        predicted_encoded = int(model.predict([row])[0])
        semaforo = inverse_label_mapping.get(predicted_encoded)

        if semaforo is None:
            return None

        probability_by_label: dict[str, float] = {}

        if hasattr(model, "predict_proba"):
            probabilities = model.predict_proba([row])[0]
            classes = getattr(
                model,
                "classes_",
                list(range(len(probabilities))),
            )

            for class_value, probability in zip(classes, probabilities):
                label = inverse_label_mapping.get(int(class_value))

                if label is not None:
                    probability_by_label[label] = round(float(probability), 4)

        porcentaje_riesgo = _risk_percentage_from_prediction(
            semaforo=semaforo,
            probability_by_label=probability_by_label,
        )

        model_version = bundle.get("model_version") or "v0.3-pseudopalabras"

        return RiskPredictionResult(
            porcentaje_riesgo=porcentaje_riesgo,
            semaforo=semaforo,
            fuente_prediccion="ML_RANDOM_FOREST",
            modelo_nombre="RandomForestClassifier",
            modelo_version=model_version,
            probabilidades=probability_by_label,
            features=features,
        )
    except Exception:
        return None


def get_model_status() -> dict[str, Any]:
    bundle = _load_model_bundle()

    if bundle is None:
        return {
            "available": False,
            "model_path": str(MODEL_PATH),
            "message": "Modelo no disponible o no utilizable.",
        }

    return {
        "available": True,
        "model_path": str(MODEL_PATH),
        "feature_columns": bundle.get("feature_columns", []),
        "label_mapping": bundle.get("label_mapping", {}),
        "model_version": bundle.get("model_version"),
    }

