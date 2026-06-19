from __future__ import annotations

from datetime import datetime
from pathlib import Path
from typing import Any

import pandas as pd


VALIDATION_DIR = Path("data/processed/ml_validation")
OUTPUT_PATH = Path("docs/resultados_validacion_ml.md")


def main() -> None:
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)

    metrics_df = _read_csv(VALIDATION_DIR / "metrics_summary.csv")
    distribution_df = _read_csv(VALIDATION_DIR / "class_distribution.csv")

    rf_confusion_df = _read_csv(
        VALIDATION_DIR / "random_forest_confusion_matrix.csv",
        index_col=0,
    )

    rf_importance_df = _read_csv(
        VALIDATION_DIR / "random_forest_feature_importance.csv",
    )

    xgb_confusion_path = VALIDATION_DIR / "xgboost_confusion_matrix.csv"
    xgb_importance_path = VALIDATION_DIR / "xgboost_feature_importance.csv"

    xgb_confusion_df = (
        _read_csv(xgb_confusion_path, index_col=0)
        if xgb_confusion_path.exists()
        else None
    )

    xgb_importance_df = (
        _read_csv(xgb_importance_path)
        if xgb_importance_path.exists()
        else None
    )

    lines: list[str] = []

    lines.extend(_section_title())
    lines.extend(_section_context())
    lines.extend(_section_dataset_distribution(distribution_df))
    lines.extend(_section_metrics(metrics_df))
    lines.extend(_section_confusion_matrix("Random Forest", rf_confusion_df))
    lines.extend(_section_feature_importance("Random Forest", rf_importance_df))

    if xgb_confusion_df is not None:
        lines.extend(_section_confusion_matrix("XGBoost", xgb_confusion_df))

    if xgb_importance_df is not None:
        lines.extend(_section_feature_importance("XGBoost", xgb_importance_df))

    lines.extend(_section_interpretation(metrics_df, distribution_df))
    lines.extend(_section_limitations(distribution_df))
    lines.extend(_section_thesis_text(metrics_df, distribution_df))

    OUTPUT_PATH.write_text(
        "\n".join(lines),
        encoding="utf-8",
    )

    print("")
    print("Documento de resultados ML generado correctamente:")
    print(OUTPUT_PATH)
    print("")


def _read_csv(path: Path, **kwargs: Any) -> pd.DataFrame:
    if not path.exists():
        raise FileNotFoundError(f"No existe el archivo requerido: {path}")

    try:
        return pd.read_csv(path, **kwargs)
    except UnicodeDecodeError:
        return pd.read_csv(path, encoding="latin-1", **kwargs)


def _section_title() -> list[str]:
    now = datetime.now()

    return [
        "# Resultados de validación del modelo de machine learning",
        "",
        f"Documento generado el {now.strftime('%d/%m/%Y %H:%M')}.",
        "",
    ]


def _section_context() -> list[str]:
    return [
        "## 1. Alcance de la validación",
        "",
        "La validación corresponde al componente de machine learning del prototipo "
        "de tamizaje temprano de riesgo de dislexia. El objetivo del modelo es "
        "clasificar el nivel de riesgo en un esquema de semáforo: `VERDE`, "
        "`AMARILLO` o `ROJO`, a partir de variables de desempeño registradas "
        "durante las pruebas de lectura y conciencia fonológica.",
        "",
        "El resultado del modelo debe interpretarse como apoyo para tamizaje "
        "educativo y no como diagnóstico clínico. La confirmación diagnóstica "
        "requiere evaluación profesional especializada.",
        "",
    ]


def _section_dataset_distribution(distribution_df: pd.DataFrame) -> list[str]:
    total = int(distribution_df["total"].sum()) if not distribution_df.empty else 0

    lines = [
        "## 2. Distribución de clases",
        "",
        f"El conjunto de datos utilizado contiene **{total} evaluaciones**.",
        "",
        "| Clase | Total | Porcentaje |",
        "|---|---:|---:|",
    ]

    for _, row in distribution_df.iterrows():
        clase = row.get("clase", "-")
        count = int(row.get("total", 0))
        percentage = (count / total * 100) if total > 0 else 0

        lines.append(
            f"| {clase} | {count} | {percentage:.2f}% |"
        )

    lines.append("")

    return lines


def _section_metrics(metrics_df: pd.DataFrame) -> list[str]:
    lines = [
        "## 3. Comparación de modelos",
        "",
        "Se compararon los modelos disponibles considerando métricas de clasificación. "
        "Para conjuntos de datos desbalanceados se recomienda observar especialmente "
        "el `F1 macro`, porque resume el desempeño promedio por clase.",
        "",
        "| Modelo | Estado | Accuracy | Precision macro | Recall macro | F1 macro | F1 weighted | Observación |",
        "|---|---|---:|---:|---:|---:|---:|---|",
    ]

    for _, row in metrics_df.iterrows():
        lines.append(
            "| "
            f"{_value(row, 'model_name')} | "
            f"{_value(row, 'status')} | "
            f"{_metric(row, 'accuracy')} | "
            f"{_metric(row, 'precision_macro')} | "
            f"{_metric(row, 'recall_macro')} | "
            f"{_metric(row, 'f1_macro')} | "
            f"{_metric(row, 'f1_weighted')} | "
            f"{_value(row, 'note')} |"
        )

    lines.append("")

    best = _best_model(metrics_df)

    if best:
        lines.extend(
            [
                f"De acuerdo con las métricas disponibles, el modelo con mejor "
                f"valor de `F1 macro` fue **{best}**.",
                "",
            ]
        )

    return lines


def _section_confusion_matrix(
    model_name: str,
    confusion_df: pd.DataFrame,
) -> list[str]:
    lines = [
        f"## 4. Matriz de confusión - {model_name}",
        "",
    ]

    if confusion_df.empty:
        lines.extend(
            [
                "No se generó matriz de confusión para este modelo.",
                "",
            ]
        )
        return lines

    headers = ["Clase real"] + [str(column) for column in confusion_df.columns]

    lines.append("| " + " | ".join(headers) + " |")
    lines.append("|" + "|".join(["---"] + ["---:"] * len(confusion_df.columns)) + "|")

    for index, row in confusion_df.iterrows():
        values = [str(index)] + [str(row[column]) for column in confusion_df.columns]
        lines.append("| " + " | ".join(values) + " |")

    lines.append("")

    return lines


def _section_feature_importance(
    model_name: str,
    importance_df: pd.DataFrame,
) -> list[str]:
    lines = [
        f"## 5. Variables más importantes - {model_name}",
        "",
    ]

    if importance_df.empty:
        lines.extend(
            [
                "No se generó importancia de variables para este modelo.",
                "",
            ]
        )
        return lines

    top_df = importance_df.head(10)

    lines.extend(
        [
            "Las siguientes variables tuvieron mayor peso relativo en el modelo:",
            "",
            "| Variable | Importancia |",
            "|---|---:|",
        ]
    )

    for _, row in top_df.iterrows():
        feature = row.get("feature", "-")
        importance = _to_float(row.get("importance"))

        lines.append(f"| `{feature}` | {importance:.6f} |")

    lines.append("")

    return lines


def _section_interpretation(
    metrics_df: pd.DataFrame,
    distribution_df: pd.DataFrame,
) -> list[str]:
    total_classes = len(distribution_df)
    total_rows = int(distribution_df["total"].sum()) if not distribution_df.empty else 0

    lines = [
        "## 6. Interpretación técnica",
        "",
    ]

    if total_rows < 30:
        lines.extend(
            [
                "El número de evaluaciones disponibles todavía es reducido, por lo que "
                "las métricas deben entenderse como evidencia preliminar del funcionamiento "
                "del pipeline de machine learning.",
                "",
            ]
        )

    if total_classes < 2:
        lines.extend(
            [
                "El conjunto de datos contiene una sola clase de salida. En esta condición, "
                "no es posible evaluar de forma completa la capacidad discriminativa del "
                "modelo entre niveles de riesgo. Se requieren evaluaciones en las clases "
                "`AMARILLO` y `ROJO` para una validación comparativa más sólida.",
                "",
            ]
        )
    elif total_classes < 3:
        lines.extend(
            [
                "El conjunto de datos no contiene las tres clases del semáforo. Por ello, "
                "la validación todavía no cubre todo el rango esperado de riesgo.",
                "",
            ]
        )

    xgb_rows = metrics_df[
        metrics_df["model_name"].astype(str).str.upper().str.contains("XGBOOST")
    ]

    if not xgb_rows.empty:
        status = str(xgb_rows.iloc[0].get("status", ""))

        if status in {"OMITIDO", "NO_DISPONIBLE"}:
            note = str(xgb_rows.iloc[0].get("note", ""))

            lines.extend(
                [
                    f"XGBoost aparece con estado `{status}`. Motivo: {note}",
                    "",
                ]
            )

    lines.extend(
        [
            "En esta etapa, la validación permite comprobar que el sistema puede "
            "extraer características, construir un vector de entrada, entrenar un "
            "modelo y generar salidas interpretables para el personal académico.",
            "",
        ]
    )

    return lines


def _section_limitations(distribution_df: pd.DataFrame) -> list[str]:
    total = int(distribution_df["total"].sum()) if not distribution_df.empty else 0

    return [
        "## 7. Limitaciones",
        "",
        "Las principales limitaciones de esta validación son:",
        "",
        f"- Tamaño actual del dataset: {total} evaluaciones.",
        "- Posible desbalance entre clases `VERDE`, `AMARILLO` y `ROJO`.",
        "- Datos recolectados en etapa de prototipo.",
        "- El modelo no reemplaza una evaluación clínica o psicopedagógica.",
        "- La generalización debe comprobarse con una muestra mayor y diversa.",
        "",
    ]


def _section_thesis_text(
    metrics_df: pd.DataFrame,
    distribution_df: pd.DataFrame,
) -> list[str]:
    total = int(distribution_df["total"].sum()) if not distribution_df.empty else 0
    best = _best_model(metrics_df) or "Random Forest"

    return [
        "## 8. Texto sugerido para la tesis",
        "",
        "La validación del componente de machine learning se realizó utilizando "
        f"un conjunto de datos compuesto por {total} evaluaciones registradas por "
        "el prototipo. A partir de las interacciones del estudiante durante las "
        "pruebas de lectura y conciencia fonológica, se extrajeron variables como "
        "tiempos de respuesta, cantidad de aciertos, errores de selección, eventos "
        "de arrastre y características asociadas a pseudopalabras.",
        "",
        f"El modelo con mejor desempeño preliminar según las métricas disponibles "
        f"fue {best}. No obstante, debido al tamaño reducido del conjunto de datos "
        "y al posible desbalance entre clases, estos resultados deben interpretarse "
        "como una validación técnica preliminar del pipeline de clasificación y no "
        "como una validación clínica definitiva.",
        "",
        "Los resultados evidencian que el prototipo permite capturar datos de "
        "evaluación, sincronizarlos con el backend, construir un dataset estructurado "
        "y aplicar modelos supervisados para estimar un nivel de riesgo mediante un "
        "semáforo interpretativo. Este enfoque proporciona una base funcional para "
        "futuras validaciones con muestras más amplias y supervisión profesional.",
        "",
    ]


def _best_model(metrics_df: pd.DataFrame) -> str | None:
    valid_df = metrics_df.copy()

    valid_df["f1_macro_numeric"] = pd.to_numeric(
        valid_df.get("f1_macro"),
        errors="coerce",
    )

    valid_df = valid_df.dropna(subset=["f1_macro_numeric"])

    if valid_df.empty:
        return None

    best_row = valid_df.sort_values(
        by="f1_macro_numeric",
        ascending=False,
    ).iloc[0]

    return str(best_row.get("model_name", ""))


def _value(row: pd.Series, key: str) -> str:
    value = row.get(key)

    if pd.isna(value):
        return "-"

    text = str(value).strip()

    return text if text else "-"


def _metric(row: pd.Series, key: str) -> str:
    value = row.get(key)

    if pd.isna(value):
        return "-"

    parsed = _to_float(value)

    return f"{parsed:.4f}"


def _to_float(value: Any) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return 0.0


if __name__ == "__main__":
    main()
