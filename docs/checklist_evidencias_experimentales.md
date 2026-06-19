# Checklist de evidencias experimentales

Este checklist sirve para reunir capturas, archivos y evidencias necesarias para sustentar el funcionamiento del prototipo.

## 1. Evidencias de aplicacion movil

| Evidencia | Estado | Archivo sugerido |
|---|---|---|
| Pantalla de ingreso por PIN | Pendiente | `docs/evidencias/01_pin_login.png` |
| Preparar modo offline con credenciales academicas | Pendiente | `docs/evidencias/02_preparar_offline.png` |
| Prueba de lectura en ejecucion | Pendiente | `docs/evidencias/03_prueba_lectura.png` |
| Prueba de conciencia fonologica | Pendiente | `docs/evidencias/04_prueba_fonologia.png` |
| Resultado con porcentaje y semaforo | Pendiente | `docs/evidencias/05_resultado_semaforo.png` |
| Portal de reportes | Pendiente | `docs/evidencias/06_reportes.png` |
| Perfil de riesgo por estudiante | Pendiente | `docs/evidencias/07_perfil_estudiante.png` |
| Panel administrativo | Pendiente | `docs/evidencias/08_panel_admin.png` |
| Exportacion PDF | Pendiente | `docs/evidencias/09_reporte_pdf.png` |

## 2. Evidencias de backend

| Evidencia | Estado | Archivo sugerido |
|---|---|---|
| Health check backend | Pendiente | `docs/evidencias/10_health_backend.png` |
| Login JWT exitoso | Pendiente | `docs/evidencias/11_login_jwt.png` |
| Endpoint dataset ML protegido | Pendiente | `docs/evidencias/12_dataset_ml_endpoint.png` |
| Smoke test backend exitoso | Pendiente | `docs/evidencias/13_smoke_backend.png` |

## 3. Evidencias de machine learning

| Evidencia | Estado | Archivo sugerido |
|---|---|---|
| Dataset CSV exportado | Pendiente | `data/processed/ml_dataset.csv` |
| Validacion ML ejecutada | Pendiente | `data/processed/ml_validation/validation_report.md` |
| Metricas comparativas | Pendiente | `data/processed/ml_validation/metrics_summary.csv` |
| Matriz de confusion Random Forest | Pendiente | `data/processed/ml_validation/random_forest_confusion_matrix.csv` |
| Importancia de variables | Pendiente | `data/processed/ml_validation/random_forest_feature_importance.csv` |

## 4. Comandos de reproduccion

```powershell
.\scripts\export_ml_dataset.ps1

python .\ml\validate_models.py `
  --dataset data\processed\ml_dataset.csv `
  --output-dir data\processed\ml_validation `
  --models-dir ml\models

python .\scripts\generate_ml_validation_docs.py
python .\scripts\generate_dataset_evidence.py
```
