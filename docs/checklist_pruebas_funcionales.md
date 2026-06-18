# Checklist de pruebas funcionales

Proyecto: App de tamizaje temprano de riesgo de dislexia  
Versión: Prototipo tesis  
Estado: Sprint 16 - Estabilización

> Nota: El sistema realiza tamizaje educativo de riesgo. No emite diagnóstico clínico.

## 1. Pruebas backend

| ID | Caso de prueba | Entrada | Resultado esperado | Estado |
|---|---|---|---|---|
| BE-01 | Health check | GET /health | Respuesta status ok | Pendiente |
| BE-02 | Estado del modelo ML | GET /api/v1/evaluaciones/model-status | Indica si el modelo está disponible | Pendiente |
| BE-03 | Listar estudiantes | GET /api/v1/estudiantes | Retorna estudiantes registrados | Pendiente |
| BE-04 | Padrón offline | GET /api/v1/estudiantes/offline-cache | Retorna estudiantes activos para caché local | Pendiente |
| BE-05 | Sync evaluación | POST /api/v1/evaluaciones/sync | Inserta evaluación, detalles y predicción | Pendiente |
| BE-06 | Debug evaluaciones | GET /api/v1/evaluaciones/debug | Muestra evaluaciones, detalles y predicciones | Pendiente |
| BE-07 | Reporte evaluaciones | GET /api/v1/reportes/evaluaciones | Retorna historial de evaluaciones | Pendiente |
| BE-08 | Filtro por tipo de prueba | tipo_prueba=FONOLOGIA | Retorna solo evaluaciones fonológicas | Pendiente |
| BE-09 | Filtro por semáforo | semaforo=AMARILLO | Retorna solo evaluaciones amarillas | Pendiente |
| BE-10 | Perfil de estudiante | GET /estudiantes/{id}/perfil-riesgo | Retorna comparativo lectura/fonología | Pendiente |
| BE-11 | Exportar dataset ML CSV | GET /api/v1/ml/dataset.csv | Descarga CSV con variables ML | Pendiente |
| BE-12 | Exportar reporte CSV | GET /api/v1/reportes/evaluaciones.csv | Descarga CSV de reportes | Pendiente |

## 2. Pruebas Flutter

| ID | Caso de prueba | Pasos | Resultado esperado | Estado |
|---|---|---|---|---|
| FL-01 | Análisis estático | Ejecutar flutter analyze | No issues found | Pendiente |
| FL-02 | Inicio de app | Ejecutar flutter run | Abre pantalla PIN | Pendiente |
| FL-03 | Preparar offline | Presionar Preparar modo offline | Descarga padrón local | Pendiente |
| FL-04 | Login PIN online | PIN 1234 con backend activo | Ingresa como estudiante | Pendiente |
| FL-05 | Login PIN offline | Apagar backend, ingresar PIN cacheado | Ingresa desde caché local | Pendiente |
| FL-06 | Selección de prueba | Ingresar como estudiante | Muestra Lectura y Fonología | Pendiente |
| FL-07 | Prueba lectura | Completar 10 ítems | Guarda sesión y muestra resumen | Pendiente |
| FL-08 | Prueba fonológica | Completar drag/drop | Guarda sesión y muestra resumen | Pendiente |
| FL-09 | Pseudopalabras | Ejecutar fonología | Aparecen palabras reales y pseudopalabras | Pendiente |
| FL-10 | Sync manual | Presionar sincronizar | Envía datos al backend | Pendiente |
| FL-11 | Sync automático | Terminar evaluación con backend disponible | Sincroniza automáticamente | Pendiente |
| FL-12 | Riesgo visible | Terminar y sincronizar | Muestra porcentaje y semáforo | Pendiente |
| FL-13 | Cambio estudiante | Presionar cambiar estudiante | Vuelve a pantalla PIN | Pendiente |

## 3. Pruebas portal académico

| ID | Caso de prueba | Usuario | Resultado esperado | Estado |
|---|---|---|---|---|
| PA-01 | Login maestra | maestra3a@demo.com | Ingresa al reporte docente | Pendiente |
| PA-02 | Login psicóloga | psicologa@demo.com | Ingresa al reporte de grado | Pendiente |
| PA-03 | Login directora | directora@demo.com | Ingresa al reporte general del grado | Pendiente |
| PA-04 | Filtro lectura | Tipo de prueba Lectura | Muestra solo lectura | Pendiente |
| PA-05 | Filtro fonología | Tipo de prueba Fonología | Muestra solo fonología | Pendiente |
| PA-06 | Filtro semáforo | Seleccionar VERDE/AMARILLO/ROJO | Filtra correctamente | Pendiente |
| PA-07 | Filtro estudiante | Ingresar estudiante ID | Muestra solo ese estudiante | Pendiente |
| PA-08 | Exportar CSV | Presionar Exportar CSV | Abre o descarga archivo CSV | Pendiente |
| PA-09 | Perfil estudiante | Tocar evaluación | Abre perfil comparativo | Pendiente |
| PA-10 | Comparativo pruebas | Ver perfil estudiante | Muestra Lectura vs Fonología | Pendiente |

## 4. Pruebas ML

| ID | Caso de prueba | Entrada | Resultado esperado | Estado |
|---|---|---|---|---|
| ML-01 | Exportar dataset | /api/v1/ml/dataset.csv | CSV contiene features | Pendiente |
| ML-02 | Variables fonológicas | Dataset ML | Incluye drag_drop y pseudopalabras | Pendiente |
| ML-03 | Entrenamiento Random Forest | python ml/train_models.py | Genera random_forest_model.joblib | Pendiente |
| ML-04 | Entrenamiento XGBoost | python ml/train_models.py | Genera modelo o warning controlado | Pendiente |
| ML-05 | Carga modelo backend | /model-status | Modelo disponible | Pendiente |
| ML-06 | Predicción sync | Nueva evaluación | Guarda predicción en predicciones_modelo | Pendiente |
| ML-07 | Trazabilidad | Reporte/debug | Muestra fuente, modelo, versión y probabilidades | Pendiente |

## 5. Evidencia sugerida para tesis

| Evidencia | Archivo o captura sugerida |
|---|---|
| Backend levantado | Captura de /health |
| Smoke test backend | Captura de scripts/smoke_test_backend.ps1 |
| Flutter analyze | Captura de No issues found |
| PIN offline | Captura de ingreso sin backend |
| Prueba lectura | Captura de pantalla de evaluación |
| Prueba fonológica | Captura de drag/drop |
| Resultado semáforo | Captura de resumen final |
| Reporte docente | Captura de reportes |
| Perfil estudiante | Captura de comparativo lectura/fonología |
| Dataset ML | Captura del CSV |
| Entrenamiento ML | Captura de training_report.json |
| Export CSV | Archivo reporte_evaluaciones.csv |

## 6. Criterio de cierre del sprint

El Sprint 16 se considera completado cuando:

- El backend responde correctamente.
- Flutter analyze no muestra errores.
- Se puede ejecutar lectura y fonología.
- Las evaluaciones se guardan offline.
- Las evaluaciones se sincronizan.
- El backend guarda predicción.
- Los reportes muestran los datos.
- Los filtros funcionan.
- El perfil comparativo del estudiante funciona.
- El CSV se exporta correctamente.
