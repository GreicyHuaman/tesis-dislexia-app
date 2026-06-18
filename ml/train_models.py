import argparse
import json
from pathlib import Path
from typing import Any

import joblib
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score, classification_report, confusion_matrix
from sklearn.model_selection import train_test_split


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

LABEL_COLUMN = "semaforo"

SEMAFORO_ORDER = [
    "VERDE",
    "AMARILLO",
    "ROJO",
]


def normalize_label(value: Any) -> str | None:
    if value is None:
        return None

    text = str(value).strip().upper()

    if text in {"", "NONE", "NAN", "NULL", "SIN_RESULTADO"}:
        return None

    return text


def load_dataset(dataset_path: Path) -> pd.DataFrame:
    if not dataset_path.exists():
        raise FileNotFoundError(
            f"No existe el dataset: {dataset_path}. "
            "Primero exporta data/processed/ml_dataset.csv."
        )

    df = pd.read_csv(dataset_path)

    missing_features = [
        column for column in FEATURE_COLUMNS if column not in df.columns
    ]

    if missing_features:
        raise ValueError(
            "Faltan columnas requeridas en el CSV: "
            + ", ".join(missing_features)
        )

    if LABEL_COLUMN not in df.columns:
        raise ValueError(f"Falta la columna etiqueta: {LABEL_COLUMN}")

    df[LABEL_COLUMN] = df[LABEL_COLUMN].apply(normalize_label)
    df = df.dropna(subset=[LABEL_COLUMN]).copy()

    for column in FEATURE_COLUMNS:
        df[column] = pd.to_numeric(df[column], errors="coerce").fillna(0)

    return df


def build_label_mapping(labels: list[str]) -> dict[str, int]:
    ordered_labels = [
        label for label in SEMAFORO_ORDER if label in labels
    ]

    extra_labels = sorted(
        label for label in labels if label not in ordered_labels
    )

    final_labels = ordered_labels + extra_labels

    return {
        label: index for index, label in enumerate(final_labels)
    }


def can_use_stratified_split(y: pd.Series) -> bool:
    counts = y.value_counts()

    if len(counts) < 2:
        return False

    return counts.min() >= 2 and len(y) >= 8


def evaluate_model(model, x_eval, y_eval, label_names: list[str]) -> dict[str, Any]:
    predictions = model.predict(x_eval)

    return {
        "accuracy": round(float(accuracy_score(y_eval, predictions)), 4),
        "classification_report": classification_report(
            y_eval,
            predictions,
            target_names=label_names,
            labels=list(range(len(label_names))),
            zero_division=0,
            output_dict=True,
        ),
        "confusion_matrix": confusion_matrix(
            y_eval,
            predictions,
            labels=list(range(len(label_names))),
        ).tolist(),
    }


def train_random_forest(x_train, y_train):
    model = RandomForestClassifier(
        n_estimators=300,
        max_depth=8,
        min_samples_leaf=1,
        random_state=42,
        class_weight="balanced",
    )

    model.fit(x_train, y_train)

    return model


def train_xgboost(x_train, y_train, num_classes: int):
    try:
        from xgboost import XGBClassifier
    except ImportError:
        return None, "xgboost no esta instalado."

    if num_classes < 2:
        return None, "XGBoost requiere al menos 2 clases."

    model = XGBClassifier(
        n_estimators=180,
        max_depth=3,
        learning_rate=0.08,
        subsample=0.9,
        colsample_bytree=0.9,
        objective="multi:softprob",
        num_class=num_classes,
        eval_metric="mlogloss",
        random_state=42,
    )

    model.fit(x_train, y_train)

    return model, None


def save_json(path: Path, data: dict[str, Any]) -> None:
    path.write_text(
        json.dumps(data, indent=2, ensure_ascii=False),
        encoding="utf-8",
    )


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Entrena modelos ML para tamizaje de riesgo de dislexia."
    )
    parser.add_argument(
        "--dataset",
        default="data/processed/ml_dataset.csv",
        help="Ruta del CSV exportado desde el backend.",
    )
    parser.add_argument(
        "--output-dir",
        default="ml/models",
        help="Carpeta donde se guardaran modelos y metricas.",
    )

    args = parser.parse_args()

    dataset_path = Path(args.dataset)
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    df = load_dataset(dataset_path)

    report: dict[str, Any] = {
        "dataset_path": str(dataset_path),
        "rows_total": int(len(df)),
        "feature_columns": FEATURE_COLUMNS,
        "label_column": LABEL_COLUMN,
        "models": {},
        "warnings": [],
    }

    if df.empty:
        report["warnings"].append(
            "El dataset no tiene filas con semaforo valido. No se entreno ningun modelo."
        )
        save_json(output_dir / "training_report.json", report)
        print(json.dumps(report, indent=2, ensure_ascii=False))
        return

    labels = sorted(df[LABEL_COLUMN].unique().tolist())
    label_mapping = build_label_mapping(labels)
    inverse_label_mapping = {
        value: key for key, value in label_mapping.items()
    }

    label_names = [
        inverse_label_mapping[index]
        for index in range(len(inverse_label_mapping))
    ]

    df["label_encoded"] = df[LABEL_COLUMN].map(label_mapping)

    x = df[FEATURE_COLUMNS]
    y = df["label_encoded"]

    report["labels_found"] = labels
    report["label_mapping"] = label_mapping
    report["class_counts"] = {
        str(label): int(count)
        for label, count in df[LABEL_COLUMN].value_counts().to_dict().items()
    }

    report["test_type_counts"] = {
        "LECTURA": int(df["tipo_prueba_lectura"].sum()),
        "FONOLOGIA": int(df["tipo_prueba_fonologia"].sum()),
        "OTRO": int(df["tipo_prueba_otro"].sum()),
    }

    report["stimulus_type_totals"] = {
        "items_palabra_real": int(df["items_palabra_real"].sum()),
        "items_pseudopalabra": int(df["items_pseudopalabra"].sum()),
    }

    if len(label_mapping) < 2:
        report["warnings"].append(
            "Solo existe una clase en el dataset. Random Forest puede entrenar, "
            "pero el modelo todavia no es util para clasificacion real. "
            "Genera evaluaciones VERDE, AMARILLO y ROJO para entrenar mejor."
        )

    if can_use_stratified_split(y):
        x_train, x_test, y_train, y_test = train_test_split(
            x,
            y,
            test_size=0.25,
            random_state=42,
            stratify=y,
        )
        evaluation_mode = "test_split_stratified"
    else:
        x_train, x_test, y_train, y_test = x, x, y, y
        evaluation_mode = "train_only_small_dataset"
        report["warnings"].append(
            "Dataset pequeno o clases con pocos ejemplos. "
            "Se evaluara sobre entrenamiento solo para validar el pipeline."
        )

    report["evaluation_mode"] = evaluation_mode
    report["train_rows"] = int(len(x_train))
    report["test_rows"] = int(len(x_test))

    random_forest = train_random_forest(x_train, y_train)

    rf_path = output_dir / "random_forest_model.joblib"

    joblib.dump(
        {
            "model": random_forest,
            "feature_columns": FEATURE_COLUMNS,
            "label_mapping": label_mapping,
            "inverse_label_mapping": inverse_label_mapping,
            "model_version": "v0.3-pseudopalabras",
        },
        rf_path,
    )

    report["models"]["random_forest"] = {
        "path": str(rf_path),
        "metrics": evaluate_model(
            random_forest,
            x_test,
            y_test,
            label_names,
        ),
    }

    xgb_model, xgb_error = train_xgboost(
        x_train,
        y_train,
        num_classes=len(label_mapping),
    )

    if xgb_model is None:
        report["models"]["xgboost"] = {
            "trained": False,
            "reason": xgb_error,
        }
    else:
        xgb_path = output_dir / "xgboost_model.joblib"

        joblib.dump(
            {
                "model": xgb_model,
                "feature_columns": FEATURE_COLUMNS,
                "label_mapping": label_mapping,
                "inverse_label_mapping": inverse_label_mapping,
                "model_version": "v0.3-pseudopalabras",
            },
            xgb_path,
        )

        report["models"]["xgboost"] = {
            "trained": True,
            "path": str(xgb_path),
            "metrics": evaluate_model(
                xgb_model,
                x_test,
                y_test,
                label_names,
            ),
        }

    metadata_path = output_dir / "model_metadata.json"

    metadata = {
        "feature_columns": FEATURE_COLUMNS,
        "label_mapping": label_mapping,
        "inverse_label_mapping": inverse_label_mapping,
        "preferred_model": "random_forest",
        "model_version": "v0.3-pseudopalabras",
    }

    save_json(metadata_path, metadata)

    report["metadata_path"] = str(metadata_path)

    report_path = output_dir / "training_report.json"

    save_json(report_path, report)

    print("Entrenamiento completado.")
    print(f"Reporte: {report_path}")
    print(f"Metadata: {metadata_path}")
    print(json.dumps(report, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
