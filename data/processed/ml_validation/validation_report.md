# Validación de modelos ML

## Alcance

Este reporte evalúa modelos de clasificación para tamizaje temprano de riesgo de dislexia. Los resultados no constituyen diagnóstico clínico.

## Dataset

- Filas utilizadas: 34
- Columna objetivo: `semaforo`
- Modo de validación: `holdout_70_30_estratificado`
- Número de variables predictoras: 32

## Distribución de clases

| Clase | Total |
|---|---:|
| VERDE | 25 |
| ROJO | 5 |
| AMARILLO | 4 |

## Métricas comparativas

| Modelo | Estado | Accuracy | Precision macro | Recall macro | F1 macro | F1 weighted |
|---|---|---:|---:|---:|---:|---:|
| Random Forest | OK | 0.9091 | 0.8333 | 0.8333 | 0.7778 | 0.9091 |
| XGBoost | OK | 0.8182 | 0.6296 | 0.5000 | 0.5359 | 0.8057 |

## Archivos generados

- `metrics_summary.csv`
- `class_distribution.csv`
- `random_forest_confusion_matrix.csv`
- `random_forest_feature_importance.csv`
- `random_forest_classification_report.json`
- `xgboost_confusion_matrix.csv` si XGBoost está disponible
- `xgboost_feature_importance.csv` si XGBoost está disponible
- `validation_metadata.json`

## Interpretación para tesis

Se recomienda priorizar F1 macro cuando las clases VERDE, AMARILLO y ROJO estén desbalanceadas, porque esta métrica considera el desempeño promedio por clase.
