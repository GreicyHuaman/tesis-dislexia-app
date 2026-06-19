from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

import joblib
import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import (
    accuracy_score,
    classification_report,
    confusion_matrix,
    precision_recall_fscore_support,
)
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder


FEATURE_COLUMNS = [
    "tipo_prueba_lectura",
    "tipo_prueba_fonologia",
    "tipo_prueba_otro",
    "total_items",
    "aciertos_primer_intento",
    "errores_primer_intento",
    "error_rate",
    "taps_erroneos_totales",
    "taps_rate",
    "tiempo_promedio_ms",
    "tiempo_min_ms",
    "tiempo_max_ms",
    "tiempo_std_ms",
    "items_drag_drop",
    "drag_drop_rate",
    "tiempo_promedio_drag_drop_ms",
    "errores_drag_drop",
    "items_palabra_real",
    "items_pseudopalabra",
    "pseudopalabra_rate",
    "errores_palabra_real",
    "errores_pseudopalabra",
    "tiempo_promedio_palabra_real_ms",
    "tiempo_promedio_pseudopalabra_ms",
    "total_baja",
    "total_media",
    "total_alta",
    "total_sin_complejidad",
    "errores_baja",
    "errores_media",
    "errores_alta",
    "errores_sin_complejidad",
]

TARGET_CANDIDATES = [
    "semaforo",
    "target",
    "label",
    "clase_riesgo",
    "riesgo_clase",
]

CLASS_ORDER = [
    "VERDE",
    "AMARILLO",
    "ROJO",
]


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Valida modelos ML para tamizaje de riesgo de dislexia.",
    )

    parser.add_argument(
        "--dataset",
        default="data/processed/ml_dataset.csv",
        help="Ruta del dataset CSV.",
    )

    parser.add_argument(
        "--output-dir",
        default="data/processed/ml_validation",
        help="Carpeta de salida para métricas y reportes.",
    )

    parser.add_argument(
        "--models-dir",
        default="ml/models",
        help="Carpeta donde se guardarán modelos entrenados para evidencia.",
    )

    args = parser.parse_args()

    dataset_path = Path(args.dataset)
    output_dir = Path(args.output_dir)
    models_dir = Path(args.models_dir)

    output_dir.mkdir(parents=True, exist_ok=True)
    models_dir.mkdir(parents=True, exist_ok=True)

    df = _read_dataset(dataset_path)
    target_column = _find_target_column(df)

    if target_column is None and "porcentaje_riesgo" in df.columns:
        df["semaforo"] = df["porcentaje_riesgo"].apply(_semaforo_from_percentage)
        target_column = "semaforo"

    if target_column is None:
        raise ValueError(
            "No se encontró columna objetivo. Se esperaba una de: "
            f"{', '.join(TARGET_CANDIDATES)} o porcentaje_riesgo."
        )

    df = _prepare_dataframe(df, target_column)

    class_distribution = (
        df[target_column]
        .value_counts()
        .rename_axis("clase")
        .reset_index(name="total")
    )

    class_distribution.to_csv(
        output_dir / "class_distribution.csv",
        index=False,
        encoding="utf-8-sig",
    )

    if df.empty:
        raise ValueError("El dataset no contiene filas válidas para entrenamiento.")

    available_features = [
        column
        for column in FEATURE_COLUMNS
        if column in df.columns
    ]

    missing_features = [
        column
        for column in FEATURE_COLUMNS
        if column not in df.columns
    ]

    for column in missing_features:
        df[column] = 0

    available_features = FEATURE_COLUMNS

    x = df[available_features].copy()
    y = df[target_column].copy()

    for column in available_features:
        x[column] = pd.to_numeric(x[column], errors="coerce").fillna(0)

    valid_split = _can_make_valid_split(y)

    if valid_split:
        x_train, x_test, y_train, y_test = train_test_split(
            x,
            y,
            test_size=0.30,
            random_state=42,
            stratify=y,
        )
        validation_mode = "holdout_70_30_estratificado"
        warning = None
    else:
        x_train = x
        x_test = x
        y_train = y
        y_test = y
        validation_mode = "evaluacion_sobre_entrenamiento"
        warning = (
            "Dataset pequeño o con pocas clases. Las métricas son solo "
            "evidencia técnica de funcionamiento y no deben interpretarse "
            "como rendimiento real del modelo."
        )

    results: list[dict[str, Any]] = []

    rf_result = _train_random_forest(
        x_train=x_train,
        y_train=y_train,
        x_test=x_test,
        y_test=y_test,
        feature_columns=available_features,
        output_dir=output_dir,
        models_dir=models_dir,
        validation_mode=validation_mode,
    )

    results.append(rf_result)

    xgb_result = _train_xgboost_if_available(
        x_train=x_train,
        y_train=y_train,
        x_test=x_test,
        y_test=y_test,
        feature_columns=available_features,
        output_dir=output_dir,
        models_dir=models_dir,
        validation_mode=validation_mode,
    )

    if xgb_result is not None:
        results.append(xgb_result)

    metrics_df = pd.DataFrame(results)
    metrics_df.to_csv(
        output_dir / "metrics_summary.csv",
        index=False,
        encoding="utf-8-sig",
    )

    metadata = {
        "dataset_path": str(dataset_path),
        "rows": int(len(df)),
        "target_column": target_column,
        "features_total": len(available_features),
        "validation_mode": validation_mode,
        "warning": warning,
        "class_distribution": class_distribution.to_dict(orient="records"),
        "models": results,
        "missing_features_filled_with_zero": missing_features,
    }

    with open(output_dir / "validation_metadata.json", "w", encoding="utf-8") as file:
        json.dump(metadata, file, ensure_ascii=False, indent=2)

    _write_markdown_report(
        output_dir=output_dir,
        metadata=metadata,
        metrics_df=metrics_df,
        class_distribution=class_distribution,
    )

    print("")
    print("Validacion ML finalizada correctamente.")
    print(f"Salida: {output_dir}")
    print("")
    print(metrics_df.to_string(index=False))


def _read_dataset(dataset_path: Path) -> pd.DataFrame:
    if not dataset_path.exists():
        raise FileNotFoundError(f"No existe el dataset: {dataset_path}")

    try:
        return pd.read_csv(dataset_path)
    except UnicodeDecodeError:
        return pd.read_csv(dataset_path, encoding="latin-1")


def _find_target_column(df: pd.DataFrame) -> str | None:
    columns = set(df.columns)

    for candidate in TARGET_CANDIDATES:
        if candidate in columns:
            return candidate

    return None


def _prepare_dataframe(
    df: pd.DataFrame,
    target_column: str,
) -> pd.DataFrame:
    prepared = df.copy()

    prepared[target_column] = (
        prepared[target_column]
        .astype(str)
        .str.strip()
        .str.upper()
    )

    prepared = prepared[
        prepared[target_column].isin(CLASS_ORDER)
    ].copy()

    return prepared


def _semaforo_from_percentage(value: Any) -> str:
    parsed = pd.to_numeric(value, errors="coerce")

    if pd.isna(parsed):
        return "VERDE"

    if parsed < 35:
        return "VERDE"

    if parsed < 65:
        return "AMARILLO"

    return "ROJO"


def _can_make_valid_split(y: pd.Series) -> bool:
    total_rows = len(y)
    class_counts = y.value_counts()

    if total_rows < 10:
        return False

    if len(class_counts) < 2:
        return False

    if class_counts.min() < 2:
        return False

    return True


def _train_random_forest(
    *,
    x_train: pd.DataFrame,
    y_train: pd.Series,
    x_test: pd.DataFrame,
    y_test: pd.Series,
    feature_columns: list[str],
    output_dir: Path,
    models_dir: Path,
    validation_mode: str,
) -> dict[str, Any]:
    model = RandomForestClassifier(
        n_estimators=300,
        random_state=42,
        class_weight="balanced",
        max_depth=None,
        min_samples_leaf=1,
    )

    model.fit(x_train, y_train)

    predictions = model.predict(x_test)

    model_path = models_dir / "random_forest_validated.joblib"
    joblib.dump(model, model_path)

    _save_confusion_matrix(
        y_true=y_test,
        y_pred=predictions,
        model_name="random_forest",
        output_dir=output_dir,
    )

    _save_classification_report(
        y_true=y_test,
        y_pred=predictions,
        model_name="random_forest",
        output_dir=output_dir,
    )

    _save_feature_importance(
        feature_columns=feature_columns,
        importances=model.feature_importances_,
        model_name="random_forest",
        output_dir=output_dir,
    )

    return _build_metrics_result(
        model_name="Random Forest",
        y_true=y_test,
        y_pred=predictions,
        validation_mode=validation_mode,
        model_path=model_path,
    )


def _train_xgboost_if_available(
    *,
    x_train: pd.DataFrame,
    y_train: pd.Series,
    x_test: pd.DataFrame,
    y_test: pd.Series,
    feature_columns: list[str],
    output_dir: Path,
    models_dir: Path,
    validation_mode: str,
) -> dict[str, Any] | None:
    unique_classes = sorted(set(y_train.astype(str)))

    if len(unique_classes) < 2:
        return {
            "model_name": "XGBoost",
            "status": "OMITIDO",
            "accuracy": None,
            "precision_macro": None,
            "recall_macro": None,
            "f1_macro": None,
            "f1_weighted": None,
            "validation_mode": validation_mode,
            "model_path": None,
            "note": (
                "XGBoost fue omitido porque el dataset contiene una sola clase. "
                "Se requieren al menos dos clases para entrenar un clasificador comparativo."
            ),
        }

    try:
        from xgboost import XGBClassifier
    except Exception:
        return {
            "model_name": "XGBoost",
            "status": "NO_DISPONIBLE",
            "accuracy": None,
            "precision_macro": None,
            "recall_macro": None,
            "f1_macro": None,
            "f1_weighted": None,
            "validation_mode": validation_mode,
            "model_path": None,
            "note": "xgboost no está instalado en el entorno local.",
        }

    encoder = LabelEncoder()

    y_train_encoded = encoder.fit_transform(y_train)
    y_test_encoded = encoder.transform(y_test)

    objective = "binary:logistic" if len(unique_classes) == 2 else "multi:softprob"

    model = XGBClassifier(
        n_estimators=250,
        max_depth=4,
        learning_rate=0.05,
        subsample=0.90,
        colsample_bytree=0.90,
        objective=objective,
        eval_metric="logloss" if len(unique_classes) == 2 else "mlogloss",
        random_state=42,
    )

    model.fit(x_train, y_train_encoded)

    predictions_encoded = model.predict(x_test)

    if len(unique_classes) == 2:
        predictions_encoded = np.asarray(predictions_encoded).astype(int)

    predictions = encoder.inverse_transform(predictions_encoded)

    model_bundle = {
        "model": model,
        "label_encoder": encoder,
        "feature_columns": feature_columns,
    }

    model_path = models_dir / "xgboost_validated.joblib"
    joblib.dump(model_bundle, model_path)

    _save_confusion_matrix(
        y_true=y_test,
        y_pred=predictions,
        model_name="xgboost",
        output_dir=output_dir,
    )

    _save_classification_report(
        y_true=y_test,
        y_pred=predictions,
        model_name="xgboost",
        output_dir=output_dir,
    )

    _save_feature_importance(
        feature_columns=feature_columns,
        importances=model.feature_importances_,
        model_name="xgboost",
        output_dir=output_dir,
    )

    return _build_metrics_result(
        model_name="XGBoost",
        y_true=y_test,
        y_pred=predictions,
        validation_mode=validation_mode,
        model_path=model_path,
    )


def _build_metrics_result(
    *,
    model_name: str,
    y_true: pd.Series,
    y_pred: np.ndarray,
    validation_mode: str,
    model_path: Path,
) -> dict[str, Any]:
    precision_macro, recall_macro, f1_macro, _ = precision_recall_fscore_support(
        y_true,
        y_pred,
        average="macro",
        zero_division=0,
    )

    _, _, f1_weighted, _ = precision_recall_fscore_support(
        y_true,
        y_pred,
        average="weighted",
        zero_division=0,
    )

    return {
        "model_name": model_name,
        "status": "OK",
        "accuracy": round(float(accuracy_score(y_true, y_pred)), 4),
        "precision_macro": round(float(precision_macro), 4),
        "recall_macro": round(float(recall_macro), 4),
        "f1_macro": round(float(f1_macro), 4),
        "f1_weighted": round(float(f1_weighted), 4),
        "validation_mode": validation_mode,
        "model_path": str(model_path),
        "note": None,
    }


def _save_confusion_matrix(
    *,
    y_true: pd.Series,
    y_pred: np.ndarray,
    model_name: str,
    output_dir: Path,
) -> None:
    labels = [
        label
        for label in CLASS_ORDER
        if label in set(y_true) or label in set(y_pred)
    ]

    matrix = confusion_matrix(
        y_true,
        y_pred,
        labels=labels,
    )

    matrix_df = pd.DataFrame(
        matrix,
        index=[f"real_{label}" for label in labels],
        columns=[f"pred_{label}" for label in labels],
    )

    matrix_df.to_csv(
        output_dir / f"{model_name}_confusion_matrix.csv",
        encoding="utf-8-sig",
    )


def _save_classification_report(
    *,
    y_true: pd.Series,
    y_pred: np.ndarray,
    model_name: str,
    output_dir: Path,
) -> None:
    report = classification_report(
        y_true,
        y_pred,
        output_dict=True,
        zero_division=0,
    )

    with open(
        output_dir / f"{model_name}_classification_report.json",
        "w",
        encoding="utf-8",
    ) as file:
        json.dump(report, file, ensure_ascii=False, indent=2)


def _save_feature_importance(
    *,
    feature_columns: list[str],
    importances: np.ndarray,
    model_name: str,
    output_dir: Path,
) -> None:
    importance_df = pd.DataFrame(
        {
            "feature": feature_columns,
            "importance": importances,
            "model": model_name,
        }
    ).sort_values(
        by="importance",
        ascending=False,
    )

    importance_df.to_csv(
        output_dir / f"{model_name}_feature_importance.csv",
        index=False,
        encoding="utf-8-sig",
    )


def _write_markdown_report(
    *,
    output_dir: Path,
    metadata: dict[str, Any],
    metrics_df: pd.DataFrame,
    class_distribution: pd.DataFrame,
) -> None:
    lines: list[str] = []

    lines.append("# Validación de modelos ML")
    lines.append("")
    lines.append("## Alcance")
    lines.append("")
    lines.append(
        "Este reporte evalúa modelos de clasificación para tamizaje temprano "
        "de riesgo de dislexia. Los resultados no constituyen diagnóstico clínico."
    )
    lines.append("")
    lines.append("## Dataset")
    lines.append("")
    lines.append(f"- Filas utilizadas: {metadata['rows']}")
    lines.append(f"- Columna objetivo: `{metadata['target_column']}`")
    lines.append(f"- Modo de validación: `{metadata['validation_mode']}`")
    lines.append(f"- Número de variables predictoras: {metadata['features_total']}")
    lines.append("")

    if metadata.get("warning"):
        lines.append("> Advertencia: " + metadata["warning"])
        lines.append("")

    lines.append("## Distribución de clases")
    lines.append("")
    lines.append("| Clase | Total |")
    lines.append("|---|---:|")

    for _, row in class_distribution.iterrows():
        lines.append(f"| {row['clase']} | {row['total']} |")

    lines.append("")
    lines.append("## Métricas comparativas")
    lines.append("")
    lines.append(
        "| Modelo | Estado | Accuracy | Precision macro | Recall macro | F1 macro | F1 weighted |"
    )
    lines.append("|---|---|---:|---:|---:|---:|---:|")

    for _, row in metrics_df.iterrows():
        lines.append(
            "| "
            f"{row.get('model_name', '-')} | "
            f"{row.get('status', '-')} | "
            f"{_format_metric(row.get('accuracy'))} | "
            f"{_format_metric(row.get('precision_macro'))} | "
            f"{_format_metric(row.get('recall_macro'))} | "
            f"{_format_metric(row.get('f1_macro'))} | "
            f"{_format_metric(row.get('f1_weighted'))} |"
        )

    lines.append("")
    lines.append("## Archivos generados")
    lines.append("")
    lines.append("- `metrics_summary.csv`")
    lines.append("- `class_distribution.csv`")
    lines.append("- `random_forest_confusion_matrix.csv`")
    lines.append("- `random_forest_feature_importance.csv`")
    lines.append("- `random_forest_classification_report.json`")
    lines.append("- `xgboost_confusion_matrix.csv` si XGBoost está disponible")
    lines.append("- `xgboost_feature_importance.csv` si XGBoost está disponible")
    lines.append("- `validation_metadata.json`")
    lines.append("")

    lines.append("## Interpretación para tesis")
    lines.append("")
    lines.append(
        "Se recomienda priorizar F1 macro cuando las clases VERDE, AMARILLO "
        "y ROJO estén desbalanceadas, porque esta métrica considera el "
        "desempeño promedio por clase."
    )
    lines.append("")

    with open(output_dir / "validation_report.md", "w", encoding="utf-8") as file:
        file.write("\n".join(lines))


def _format_metric(value: Any) -> str:
    if value is None:
        return "-"

    try:
        if pd.isna(value):
            return "-"
    except TypeError:
        pass

    try:
        return f"{float(value):.4f}"
    except ValueError:
        return str(value)


if __name__ == "__main__":
    main()

