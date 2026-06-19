from __future__ import annotations

from datetime import datetime
from pathlib import Path
from typing import Any

import pandas as pd


DATASET_PATH = Path("data/processed/ml_dataset.csv")
VALIDATION_DIR = Path("data/processed/ml_validation")

OUTPUT_DOC = Path("docs/evidencia_dataset_experimental.md")
CHECKLIST_DOC = Path("docs/checklist_evidencias_experimentales.md")


FEATURE_GROUPS = {
    "Identificacion": [
        "evaluacion_id",
        "estudiante_id",
        "seccion_id",
        "tipo_prueba",
    ],
    "Tipo de prueba": [
        "tipo_prueba_lectura",
        "tipo_prueba_fonologia",
        "tipo_prueba_otro",
    ],
    "Desempeno general": [
        "total_items",
        "aciertos_primer_intento",
        "errores_primer_intento",
        "error_rate",
        "taps_erroneos_totales",
        "taps_rate",
    ],
    "Variables temporales": [
        "tiempo_promedio_ms",
        "tiempo_min_ms",
        "tiempo_max_ms",
        "tiempo_std_ms",
    ],
    "Arrastrar y soltar": [
        "items_drag_drop",
        "drag_drop_rate",
        "tiempo_promedio_drag_drop_ms",
        "errores_drag_drop",
    ],
    "Fonologia y pseudopalabras": [
        "items_palabra_real",
        "items_pseudopalabra",
        "pseudopalabra_rate",
        "errores_palabra_real",
        "errores_pseudopalabra",
        "tiempo_promedio_palabra_real_ms",
        "tiempo_promedio_pseudopalabra_ms",
    ],
    "Complejidad del estimulo": [
        "total_baja",
        "total_media",
        "total_alta",
        "total_sin_complejidad",
        "errores_baja",
        "errores_media",
        "errores_alta",
        "errores_sin_complejidad",
    ],
    "Variable objetivo": [
        "porcentaje_riesgo",
        "semaforo",
    ],
}


def main() -> None:
    if not DATASET_PATH.exists():
        raise FileNotFoundError(
            f"No existe el dataset: {DATASET_PATH}. "
            "Ejecuta primero scripts/export_ml_dataset.ps1."
        )

    OUTPUT_DOC.parent.mkdir(parents=True, exist_ok=True)

    df = _read_csv(DATASET_PATH)

    lines: list[str] = []

    lines.extend(_title())
    lines.extend(_scope())
    lines.extend(_dataset_overview(df))
    lines.extend(_data_lineage())
    lines.extend(_class_distribution(df))
    lines.extend(_test_type_distribution(df))
    lines.extend(_feature_coverage(df))
    lines.extend(_missing_values(df))
    lines.extend(_numeric_summary(df))
    lines.extend(_privacy_notes())
    lines.extend(_validation_artifacts())
    lines.extend(_thesis_text(df))

    OUTPUT_DOC.write_text(
        "\n".join(lines),
        encoding="utf-8",
    )

    CHECKLIST_DOC.write_text(
        "\n".join(_checklist()),
        encoding="utf-8",
    )

    print("")
    print("Documentos de evidencia generados correctamente:")
    print(OUTPUT_DOC)
    print(CHECKLIST_DOC)
    print("")


def _read_csv(path: Path) -> pd.DataFrame:
    try:
        return pd.read_csv(path)
    except UnicodeDecodeError:
        return pd.read_csv(path, encoding="latin-1")


def _title() -> list[str]:
    now = datetime.now()

    return [
        "# Evidencia experimental del dataset",
        "",
        f"Documento generado el {now.strftime('%d/%m/%Y %H:%M')}.",
        "",
    ]


def _scope() -> list[str]:
    return [
        "## 1. Alcance",
        "",
        "Este documento describe la evidencia experimental asociada al dataset "
        "utilizado por el componente de machine learning del prototipo de "
        "tamizaje temprano de riesgo de dislexia.",
        "",
        "El dataset se genera a partir de evaluaciones realizadas en la aplicación "
        "Flutter, almacenadas localmente en modo offline-first, sincronizadas con "
        "el backend FastAPI y exportadas posteriormente como archivo CSV para "
        "entrenamiento y validación de modelos.",
        "",
        "El resultado del modelo se interpreta como apoyo para tamizaje educativo "
        "y no como diagnóstico clínico.",
        "",
    ]


def _dataset_overview(df: pd.DataFrame) -> list[str]:
    rows = len(df)
    columns = len(df.columns)

    evaluation_count = _nunique(df, "evaluacion_id")
    student_count = _nunique(df, "estudiante_id")
    section_count = _nunique(df, "seccion_id")

    lines = [
        "## 2. Resumen del dataset",
        "",
        "| Indicador | Valor |",
        "|---|---:|",
        f"| Filas del dataset | {rows} |",
        f"| Columnas del dataset | {columns} |",
        f"| Evaluaciones unicas | {evaluation_count} |",
        f"| Estudiantes unicos | {student_count} |",
        f"| Secciones unicas | {section_count} |",
        "",
    ]

    if "porcentaje_riesgo" in df.columns:
        risk = pd.to_numeric(df["porcentaje_riesgo"], errors="coerce")

        lines.extend(
            [
                "### Estadisticos del porcentaje de riesgo",
                "",
                "| Estadistico | Valor |",
                "|---|---:|",
                f"| Minimo | {_format_number(risk.min())} |",
                f"| Promedio | {_format_number(risk.mean())} |",
                f"| Maximo | {_format_number(risk.max())} |",
                "",
            ]
        )

    return lines


def _data_lineage() -> list[str]:
    return [
        "## 3. Trazabilidad de datos",
        "",
        "El flujo de construccion del dataset es el siguiente:",
        "",
        "1. El estudiante ingresa mediante PIN en la aplicacion movil.",
        "2. La aplicacion presenta pruebas de lectura y conciencia fonologica.",
        "3. Se registran respuestas, tiempos, errores y eventos de interaccion.",
        "4. Los datos se guardan localmente en Hive para soportar modo offline.",
        "5. Cuando existe conectividad, la aplicacion sincroniza las evaluaciones al backend.",
        "6. El backend almacena sesiones y detalles en PostgreSQL.",
        "7. El endpoint protegido de dataset ML transforma los datos en variables predictoras.",
        "8. El dataset se exporta como CSV para entrenamiento y validacion.",
        "",
        "Comando utilizado para exportar el dataset:",
        "",
        "```powershell",
        ".\\scripts\\export_ml_dataset.ps1",
        "```",
        "",
    ]


def _class_distribution(df: pd.DataFrame) -> list[str]:
    lines = [
        "## 4. Distribucion de clases",
        "",
    ]

    if "semaforo" not in df.columns:
        lines.extend(
            [
                "El dataset no contiene la columna `semaforo`.",
                "",
            ]
        )
        return lines

    distribution = (
        df["semaforo"]
        .astype(str)
        .str.upper()
        .value_counts()
        .rename_axis("clase")
        .reset_index(name="total")
    )

    total = int(distribution["total"].sum())

    lines.extend(
        [
            "| Clase | Total | Porcentaje |",
            "|---|---:|---:|",
        ]
    )

    for _, row in distribution.iterrows():
        count = int(row["total"])
        percentage = count / total * 100 if total > 0 else 0

        lines.append(
            f"| {row['clase']} | {count} | {percentage:.2f}% |"
        )

    lines.append("")

    if len(distribution) < 3:
        lines.extend(
            [
                "> Observacion: El dataset no contiene actualmente las tres clases "
                "`VERDE`, `AMARILLO` y `ROJO`. Esto limita la validacion comparativa "
                "del modelo y debe considerarse en la interpretacion de resultados.",
                "",
            ]
        )

    return lines


def _test_type_distribution(df: pd.DataFrame) -> list[str]:
    lines = [
        "## 5. Distribucion por tipo de prueba",
        "",
    ]

    if "tipo_prueba" not in df.columns:
        lines.extend(
            [
                "El dataset no contiene la columna `tipo_prueba`.",
                "",
            ]
        )
        return lines

    distribution = (
        df["tipo_prueba"]
        .astype(str)
        .str.upper()
        .value_counts()
        .rename_axis("tipo_prueba")
        .reset_index(name="total")
    )

    total = int(distribution["total"].sum())

    lines.extend(
        [
            "| Tipo de prueba | Total | Porcentaje |",
            "|---|---:|---:|",
        ]
    )

    for _, row in distribution.iterrows():
        count = int(row["total"])
        percentage = count / total * 100 if total > 0 else 0

        lines.append(
            f"| {row['tipo_prueba']} | {count} | {percentage:.2f}% |"
        )

    lines.append("")

    return lines


def _feature_coverage(df: pd.DataFrame) -> list[str]:
    lines = [
        "## 6. Cobertura de variables",
        "",
        "| Grupo | Variable | Existe | No nulos | Porcentaje no nulo |",
        "|---|---|---|---:|---:|",
    ]

    total = len(df)

    for group, columns in FEATURE_GROUPS.items():
        for column in columns:
            exists = column in df.columns

            if exists:
                non_null = int(df[column].notna().sum())
                percentage = non_null / total * 100 if total > 0 else 0
                exists_text = "Si"
            else:
                non_null = 0
                percentage = 0
                exists_text = "No"

            lines.append(
                f"| {group} | `{column}` | {exists_text} | "
                f"{non_null} | {percentage:.2f}% |"
            )

    lines.append("")

    return lines


def _missing_values(df: pd.DataFrame) -> list[str]:
    missing = (
        df.isna()
        .sum()
        .rename_axis("variable")
        .reset_index(name="faltantes")
    )

    missing["porcentaje"] = (
        missing["faltantes"] / len(df) * 100
        if len(df) > 0
        else 0
    )

    missing = missing.sort_values(
        by=["faltantes", "variable"],
        ascending=[False, True],
    )

    lines = [
        "## 7. Valores faltantes",
        "",
        "| Variable | Faltantes | Porcentaje |",
        "|---|---:|---:|",
    ]

    for _, row in missing.iterrows():
        lines.append(
            f"| `{row['variable']}` | {int(row['faltantes'])} | "
            f"{float(row['porcentaje']):.2f}% |"
        )

    lines.append("")

    return lines


def _numeric_summary(df: pd.DataFrame) -> list[str]:
    numeric_columns = [
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
        "errores_drag_drop",
        "items_pseudopalabra",
        "pseudopalabra_rate",
        "errores_pseudopalabra",
        "porcentaje_riesgo",
    ]

    existing_columns = [
        column
        for column in numeric_columns
        if column in df.columns
    ]

    lines = [
        "## 8. Resumen estadistico de variables numericas",
        "",
    ]

    if not existing_columns:
        lines.extend(
            [
                "No se encontraron variables numericas esperadas.",
                "",
            ]
        )
        return lines

    lines.extend(
        [
            "| Variable | Minimo | Promedio | Maximo |",
            "|---|---:|---:|---:|",
        ]
    )

    for column in existing_columns:
        values = pd.to_numeric(df[column], errors="coerce")

        lines.append(
            f"| `{column}` | "
            f"{_format_number(values.min())} | "
            f"{_format_number(values.mean())} | "
            f"{_format_number(values.max())} |"
        )

    lines.append("")

    return lines


def _privacy_notes() -> list[str]:
    return [
        "## 9. Consideraciones de privacidad",
        "",
        "El dataset ML exportado para entrenamiento no incluye nombres ni apellidos "
        "de estudiantes. Utiliza identificadores numericos como `estudiante_id`, "
        "`evaluacion_id` y `seccion_id`, lo que reduce la exposicion de datos "
        "personales durante el proceso de analisis.",
        "",
        "La aplicacion mantiene el enfoque offline-first, por lo que las evaluaciones "
        "pueden registrarse localmente y sincronizarse posteriormente cuando exista "
        "conectividad. El acceso a reportes, dataset ML y padron offline se encuentra "
        "protegido mediante autenticacion JWT para personal academico autorizado.",
        "",
    ]


def _validation_artifacts() -> list[str]:
    lines = [
        "## 10. Artefactos de validacion disponibles",
        "",
    ]

    files = [
        "metrics_summary.csv",
        "class_distribution.csv",
        "random_forest_confusion_matrix.csv",
        "random_forest_feature_importance.csv",
        "random_forest_classification_report.json",
        "xgboost_confusion_matrix.csv",
        "xgboost_feature_importance.csv",
        "xgboost_classification_report.json",
        "validation_metadata.json",
        "validation_report.md",
    ]

    lines.extend(
        [
            "| Archivo | Estado |",
            "|---|---|",
        ]
    )

    for filename in files:
        path = VALIDATION_DIR / filename
        status = "Disponible" if path.exists() else "No generado"

        lines.append(
            f"| `{filename}` | {status} |"
        )

    lines.append("")

    return lines


def _thesis_text(df: pd.DataFrame) -> list[str]:
    rows = len(df)
    columns = len(df.columns)

    return [
        "## 11. Texto sugerido para tesis",
        "",
        f"El dataset experimental estuvo conformado por {rows} registros y "
        f"{columns} variables generadas a partir de las evaluaciones realizadas "
        "en el prototipo movil. Las variables se obtuvieron a partir de la "
        "telemetria de interaccion del estudiante, incluyendo tiempos de respuesta, "
        "aciertos, errores, taps erroneos, eventos de arrastrar y soltar, uso de "
        "pseudopalabras y complejidad del estimulo.",
        "",
        "El proceso de construccion del dataset siguio una arquitectura offline-first: "
        "las evaluaciones fueron almacenadas localmente en el dispositivo y, al "
        "detectarse conectividad con el backend, fueron sincronizadas hacia la base "
        "de datos PostgreSQL. Posteriormente, el backend genero un dataset tabular "
        "para su uso en modelos supervisados.",
        "",
        "La variable objetivo utilizada fue el semaforo de riesgo, compuesto por las "
        "clases VERDE, AMARILLO y ROJO. Esta clasificacion representa una estimacion "
        "de riesgo para fines de tamizaje educativo y no debe interpretarse como "
        "diagnostico clinico.",
        "",
    ]


def _checklist() -> list[str]:
    return [
        "# Checklist de evidencias experimentales",
        "",
        "Este checklist sirve para reunir capturas, archivos y evidencias necesarias "
        "para sustentar el funcionamiento del prototipo.",
        "",
        "## 1. Evidencias de aplicacion movil",
        "",
        "| Evidencia | Estado | Archivo sugerido |",
        "|---|---|---|",
        "| Pantalla de ingreso por PIN | Pendiente | `docs/evidencias/01_pin_login.png` |",
        "| Preparar modo offline con credenciales academicas | Pendiente | `docs/evidencias/02_preparar_offline.png` |",
        "| Prueba de lectura en ejecucion | Pendiente | `docs/evidencias/03_prueba_lectura.png` |",
        "| Prueba de conciencia fonologica | Pendiente | `docs/evidencias/04_prueba_fonologia.png` |",
        "| Resultado con porcentaje y semaforo | Pendiente | `docs/evidencias/05_resultado_semaforo.png` |",
        "| Portal de reportes | Pendiente | `docs/evidencias/06_reportes.png` |",
        "| Perfil de riesgo por estudiante | Pendiente | `docs/evidencias/07_perfil_estudiante.png` |",
        "| Panel administrativo | Pendiente | `docs/evidencias/08_panel_admin.png` |",
        "| Exportacion PDF | Pendiente | `docs/evidencias/09_reporte_pdf.png` |",
        "",
        "## 2. Evidencias de backend",
        "",
        "| Evidencia | Estado | Archivo sugerido |",
        "|---|---|---|",
        "| Health check backend | Pendiente | `docs/evidencias/10_health_backend.png` |",
        "| Login JWT exitoso | Pendiente | `docs/evidencias/11_login_jwt.png` |",
        "| Endpoint dataset ML protegido | Pendiente | `docs/evidencias/12_dataset_ml_endpoint.png` |",
        "| Smoke test backend exitoso | Pendiente | `docs/evidencias/13_smoke_backend.png` |",
        "",
        "## 3. Evidencias de machine learning",
        "",
        "| Evidencia | Estado | Archivo sugerido |",
        "|---|---|---|",
        "| Dataset CSV exportado | Pendiente | `data/processed/ml_dataset.csv` |",
        "| Validacion ML ejecutada | Pendiente | `data/processed/ml_validation/validation_report.md` |",
        "| Metricas comparativas | Pendiente | `data/processed/ml_validation/metrics_summary.csv` |",
        "| Matriz de confusion Random Forest | Pendiente | `data/processed/ml_validation/random_forest_confusion_matrix.csv` |",
        "| Importancia de variables | Pendiente | `data/processed/ml_validation/random_forest_feature_importance.csv` |",
        "",
        "## 4. Comandos de reproduccion",
        "",
        "```powershell",
        ".\\scripts\\export_ml_dataset.ps1",
        "",
        "python .\\ml\\validate_models.py `",
        "  --dataset data\\processed\\ml_dataset.csv `",
        "  --output-dir data\\processed\\ml_validation `",
        "  --models-dir ml\\models",
        "",
        "python .\\scripts\\generate_ml_validation_docs.py",
        "python .\\scripts\\generate_dataset_evidence.py",
        "```",
        "",
    ]


def _nunique(df: pd.DataFrame, column: str) -> int:
    if column not in df.columns:
        return 0

    return int(df[column].nunique(dropna=True))


def _format_number(value: Any) -> str:
    try:
        if pd.isna(value):
            return "-"
    except TypeError:
        return "-"

    try:
        return f"{float(value):.2f}"
    except (TypeError, ValueError):
        return "-"


if __name__ == "__main__":
    main()
