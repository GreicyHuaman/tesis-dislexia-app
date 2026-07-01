from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import joblib
import numpy as np


ARTIFACT_DIR = Path(__file__).resolve().parents[1] / "ml" / "artifacts"

_classifier = None
_regressor = None
_feature_columns = None
_label_mapping = None


def _to_float(value: Any, default: float = 0.0) -> float:
    if value is None:
        return default
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def _load_artifacts() -> None:
    global _classifier, _regressor, _feature_columns, _label_mapping

    if _classifier is not None:
        return

    _classifier = joblib.load(ARTIFACT_DIR / "rf_risk_classifier.joblib")
    _regressor = joblib.load(ARTIFACT_DIR / "rf_risk_percentage_regressor.joblib")

    with open(ARTIFACT_DIR / "feature_columns.json", "r", encoding="utf-8") as f:
        _feature_columns = json.load(f)

    label_path = ARTIFACT_DIR / "label_mapping.json"
    if label_path.exists():
        with open(label_path, "r", encoding="utf-8") as f:
            _label_mapping = json.load(f)
    else:
        _label_mapping = {}


def _risk_label_from_percentage(value: float) -> str:
    if value < 30:
        return "VERDE"
    if value < 60:
        return "AMARILLO"
    return "ROJO"


def _normalize_label(raw_label: Any, risk_percentage: float) -> str:
    text = str(raw_label).upper()

    if text in {"VERDE", "AMARILLO", "ROJO"}:
        return text

    mapping = _label_mapping or {}

    direct = mapping.get(str(raw_label))
    if direct is not None:
        direct_text = str(direct).upper()
        if direct_text in {"VERDE", "AMARILLO", "ROJO"}:
            return direct_text

    for key, value in mapping.items():
        if str(value) == str(raw_label):
            key_text = str(key).upper()
            if key_text in {"VERDE", "AMARILLO", "ROJO"}:
                return key_text

    return _risk_label_from_percentage(risk_percentage)


def _adapt_feature_vector(feature_vector: dict[str, Any]) -> dict[str, float]:
    """
    Adapta el feature_vector actual del backend Disly al formato usado
    durante el entrenamiento del modelo sintético de 160 estudiantes.
    """

    total_items = _to_float(feature_vector.get("total_items"), 0)
    aciertos = _to_float(feature_vector.get("aciertos_primer_intento"), 0)
    error_rate = _to_float(feature_vector.get("error_rate"), 0)
    tiempo_promedio = _to_float(feature_vector.get("tiempo_promedio_ms"), 0)
    taps = _to_float(feature_vector.get("taps_erroneos_totales"), 0)
    errores_drag = _to_float(feature_vector.get("errores_drag_drop"), 0)
    errores_alta = _to_float(feature_vector.get("errores_alta"), 0)

    es_lectura = _to_float(feature_vector.get("tipo_prueba_lectura"), 0) == 1
    es_fonologia = _to_float(feature_vector.get("tipo_prueba_fonologia"), 0) == 1

    adapted = {
        "age_months": _to_float(feature_vector.get("age_months"), 96),

        "reading_items": _to_float(
            feature_vector.get("reading_items"),
            total_items if es_lectura else 0,
        ),
        "phonology_items": _to_float(
            feature_vector.get("phonology_items"),
            total_items if es_fonologia else 0,
        ),

        "reading_correct_first_attempt": _to_float(
            feature_vector.get("reading_correct_first_attempt"),
            aciertos if es_lectura else 0,
        ),
        "phonology_correct_first_attempt": _to_float(
            feature_vector.get("phonology_correct_first_attempt"),
            aciertos if es_fonologia else 0,
        ),

        "reading_error_rate": _to_float(
            feature_vector.get("reading_error_rate"),
            error_rate if es_lectura else 0,
        ),
        "phonology_error_rate": _to_float(
            feature_vector.get("phonology_error_rate"),
            error_rate if es_fonologia else 0,
        ),

        "avg_response_time_ms": _to_float(
            feature_vector.get("avg_response_time_ms"),
            tiempo_promedio,
        ),
        "wrong_taps_total": _to_float(
            feature_vector.get("wrong_taps_total"),
            taps,
        ),
        "drag_drop_errors": _to_float(
            feature_vector.get("drag_drop_errors"),
            errores_drag,
        ),
        "high_complexity_errors": _to_float(
            feature_vector.get("high_complexity_errors"),
            errores_alta,
        ),
    }

    return adapted


def predict_risk_with_ml(feature_vector: dict[str, Any]) -> dict[str, Any]:
    _load_artifacts()

    adapted = _adapt_feature_vector(feature_vector)

    row = []
    for column in _feature_columns:
        row.append(_to_float(adapted.get(column), 0))

    x = np.array([row], dtype=float)

    risk_percentage = float(_regressor.predict(x)[0])
    risk_percentage = max(0.0, min(100.0, risk_percentage))

    raw_label = _classifier.predict(x)[0]
    risk_label = _normalize_label(raw_label, risk_percentage)

    return {
        "porcentaje_riesgo": round(risk_percentage, 2),
        "semaforo": risk_label,
        "modelo_nombre": "random_forest_risk_model",
        "modelo_version": "v1.0-synthetic-160",
        "fuente_prediccion": "ML_RANDOM_FOREST",
    }

