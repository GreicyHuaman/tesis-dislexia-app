# Evidencia experimental del dataset

Documento generado el 20/06/2026 11:06.

## 1. Alcance

Este documento describe la evidencia experimental asociada al dataset utilizado por el componente de machine learning del prototipo de tamizaje temprano de riesgo de dislexia.

El dataset se genera a partir de evaluaciones realizadas en la aplicación Flutter, almacenadas localmente en modo offline-first, sincronizadas con el backend FastAPI y exportadas posteriormente como archivo CSV para entrenamiento y validación de modelos.

El resultado del modelo se interpreta como apoyo para tamizaje educativo y no como diagnóstico clínico.

## 2. Resumen del dataset

| Indicador | Valor |
|---|---:|
| Filas del dataset | 36 |
| Columnas del dataset | 38 |
| Evaluaciones unicas | 36 |
| Estudiantes unicos | 3 |
| Secciones unicas | 1 |

### Estadisticos del porcentaje de riesgo

| Estadistico | Valor |
|---|---:|
| Minimo | 0.00 |
| Promedio | 31.68 |
| Maximo | 69.28 |

## 3. Trazabilidad de datos

El flujo de construccion del dataset es el siguiente:

1. El estudiante ingresa mediante PIN en la aplicacion movil.
2. La aplicacion presenta pruebas de lectura y conciencia fonologica.
3. Se registran respuestas, tiempos, errores y eventos de interaccion.
4. Los datos se guardan localmente en Hive para soportar modo offline.
5. Cuando existe conectividad, la aplicacion sincroniza las evaluaciones al backend.
6. El backend almacena sesiones y detalles en PostgreSQL.
7. El endpoint protegido de dataset ML transforma los datos en variables predictoras.
8. El dataset se exporta como CSV para entrenamiento y validacion.

Comando utilizado para exportar el dataset:

```powershell
.\scripts\export_ml_dataset.ps1
```

## 4. Distribucion de clases

| Clase | Total | Porcentaje |
|---|---:|---:|
| VERDE | 25 | 73.53% |
| ROJO | 5 | 14.71% |
| AMARILLO | 4 | 11.76% |

## 5. Distribucion por tipo de prueba

| Tipo de prueba | Total | Porcentaje |
|---|---:|---:|
| LECTURA | 27 | 75.00% |
| FONOLOGIA | 9 | 25.00% |

## 6. Cobertura de variables

| Grupo | Variable | Existe | No nulos | Porcentaje no nulo |
|---|---|---|---:|---:|
| Identificacion | `evaluacion_id` | Si | 36 | 100.00% |
| Identificacion | `estudiante_id` | Si | 29 | 80.56% |
| Identificacion | `seccion_id` | Si | 29 | 80.56% |
| Identificacion | `tipo_prueba` | Si | 36 | 100.00% |
| Tipo de prueba | `tipo_prueba_lectura` | Si | 36 | 100.00% |
| Tipo de prueba | `tipo_prueba_fonologia` | Si | 36 | 100.00% |
| Tipo de prueba | `tipo_prueba_otro` | Si | 36 | 100.00% |
| Desempeno general | `total_items` | Si | 36 | 100.00% |
| Desempeno general | `aciertos_primer_intento` | Si | 36 | 100.00% |
| Desempeno general | `errores_primer_intento` | Si | 36 | 100.00% |
| Desempeno general | `error_rate` | Si | 36 | 100.00% |
| Desempeno general | `taps_erroneos_totales` | Si | 36 | 100.00% |
| Desempeno general | `taps_rate` | Si | 36 | 100.00% |
| Variables temporales | `tiempo_promedio_ms` | Si | 36 | 100.00% |
| Variables temporales | `tiempo_min_ms` | Si | 36 | 100.00% |
| Variables temporales | `tiempo_max_ms` | Si | 36 | 100.00% |
| Variables temporales | `tiempo_std_ms` | Si | 36 | 100.00% |
| Arrastrar y soltar | `items_drag_drop` | Si | 36 | 100.00% |
| Arrastrar y soltar | `drag_drop_rate` | Si | 36 | 100.00% |
| Arrastrar y soltar | `tiempo_promedio_drag_drop_ms` | Si | 36 | 100.00% |
| Arrastrar y soltar | `errores_drag_drop` | Si | 36 | 100.00% |
| Fonologia y pseudopalabras | `items_palabra_real` | Si | 36 | 100.00% |
| Fonologia y pseudopalabras | `items_pseudopalabra` | Si | 36 | 100.00% |
| Fonologia y pseudopalabras | `pseudopalabra_rate` | Si | 36 | 100.00% |
| Fonologia y pseudopalabras | `errores_palabra_real` | Si | 36 | 100.00% |
| Fonologia y pseudopalabras | `errores_pseudopalabra` | Si | 36 | 100.00% |
| Fonologia y pseudopalabras | `tiempo_promedio_palabra_real_ms` | Si | 36 | 100.00% |
| Fonologia y pseudopalabras | `tiempo_promedio_pseudopalabra_ms` | Si | 36 | 100.00% |
| Complejidad del estimulo | `total_baja` | Si | 36 | 100.00% |
| Complejidad del estimulo | `total_media` | Si | 36 | 100.00% |
| Complejidad del estimulo | `total_alta` | Si | 36 | 100.00% |
| Complejidad del estimulo | `total_sin_complejidad` | Si | 36 | 100.00% |
| Complejidad del estimulo | `errores_baja` | Si | 36 | 100.00% |
| Complejidad del estimulo | `errores_media` | Si | 36 | 100.00% |
| Complejidad del estimulo | `errores_alta` | Si | 36 | 100.00% |
| Complejidad del estimulo | `errores_sin_complejidad` | Si | 36 | 100.00% |
| Variable objetivo | `porcentaje_riesgo` | Si | 34 | 94.44% |
| Variable objetivo | `semaforo` | Si | 34 | 94.44% |

## 7. Valores faltantes

| Variable | Faltantes | Porcentaje |
|---|---:|---:|
| `estudiante_id` | 7 | 19.44% |
| `seccion_id` | 7 | 19.44% |
| `porcentaje_riesgo` | 2 | 5.56% |
| `semaforo` | 2 | 5.56% |
| `aciertos_primer_intento` | 0 | 0.00% |
| `drag_drop_rate` | 0 | 0.00% |
| `error_rate` | 0 | 0.00% |
| `errores_alta` | 0 | 0.00% |
| `errores_baja` | 0 | 0.00% |
| `errores_drag_drop` | 0 | 0.00% |
| `errores_media` | 0 | 0.00% |
| `errores_palabra_real` | 0 | 0.00% |
| `errores_primer_intento` | 0 | 0.00% |
| `errores_pseudopalabra` | 0 | 0.00% |
| `errores_sin_complejidad` | 0 | 0.00% |
| `evaluacion_id` | 0 | 0.00% |
| `items_drag_drop` | 0 | 0.00% |
| `items_palabra_real` | 0 | 0.00% |
| `items_pseudopalabra` | 0 | 0.00% |
| `pseudopalabra_rate` | 0 | 0.00% |
| `taps_erroneos_totales` | 0 | 0.00% |
| `taps_rate` | 0 | 0.00% |
| `tiempo_max_ms` | 0 | 0.00% |
| `tiempo_min_ms` | 0 | 0.00% |
| `tiempo_promedio_drag_drop_ms` | 0 | 0.00% |
| `tiempo_promedio_ms` | 0 | 0.00% |
| `tiempo_promedio_palabra_real_ms` | 0 | 0.00% |
| `tiempo_promedio_pseudopalabra_ms` | 0 | 0.00% |
| `tiempo_std_ms` | 0 | 0.00% |
| `tipo_prueba` | 0 | 0.00% |
| `tipo_prueba_fonologia` | 0 | 0.00% |
| `tipo_prueba_lectura` | 0 | 0.00% |
| `tipo_prueba_otro` | 0 | 0.00% |
| `total_alta` | 0 | 0.00% |
| `total_baja` | 0 | 0.00% |
| `total_items` | 0 | 0.00% |
| `total_media` | 0 | 0.00% |
| `total_sin_complejidad` | 0 | 0.00% |

## 8. Resumen estadistico de variables numericas

| Variable | Minimo | Promedio | Maximo |
|---|---:|---:|---:|
| `total_items` | 2.00 | 9.58 | 10.00 |
| `aciertos_primer_intento` | 1.00 | 7.64 | 10.00 |
| `errores_primer_intento` | 0.00 | 1.94 | 9.00 |
| `error_rate` | 0.00 | 0.21 | 0.90 |
| `taps_erroneos_totales` | 0.00 | 4.19 | 46.00 |
| `taps_rate` | 0.00 | 0.44 | 4.60 |
| `tiempo_promedio_ms` | 880.00 | 2288.53 | 12041.00 |
| `tiempo_min_ms` | 277.00 | 1011.28 | 2100.00 |
| `tiempo_max_ms` | 1362.00 | 8626.61 | 108334.00 |
| `tiempo_std_ms` | 267.89 | 2268.91 | 32101.67 |
| `items_drag_drop` | 0.00 | 2.50 | 10.00 |
| `errores_drag_drop` | 0.00 | 0.08 | 2.00 |
| `items_pseudopalabra` | 0.00 | 0.33 | 3.00 |
| `pseudopalabra_rate` | 0.00 | 0.03 | 0.30 |
| `errores_pseudopalabra` | 0.00 | 0.00 | 0.00 |
| `porcentaje_riesgo` | 0.00 | 31.68 | 69.28 |

## 9. Consideraciones de privacidad

El dataset ML exportado para entrenamiento no incluye nombres ni apellidos de estudiantes. Utiliza identificadores numericos como `estudiante_id`, `evaluacion_id` y `seccion_id`, lo que reduce la exposicion de datos personales durante el proceso de analisis.

La aplicacion mantiene el enfoque offline-first, por lo que las evaluaciones pueden registrarse localmente y sincronizarse posteriormente cuando exista conectividad. El acceso a reportes, dataset ML y padron offline se encuentra protegido mediante autenticacion JWT para personal academico autorizado.

## 10. Artefactos de validacion disponibles

| Archivo | Estado |
|---|---|
| `metrics_summary.csv` | Disponible |
| `class_distribution.csv` | Disponible |
| `random_forest_confusion_matrix.csv` | Disponible |
| `random_forest_feature_importance.csv` | Disponible |
| `random_forest_classification_report.json` | Disponible |
| `xgboost_confusion_matrix.csv` | Disponible |
| `xgboost_feature_importance.csv` | Disponible |
| `xgboost_classification_report.json` | Disponible |
| `validation_metadata.json` | Disponible |
| `validation_report.md` | Disponible |

## 11. Texto sugerido para tesis

El dataset experimental estuvo conformado por 36 registros y 38 variables generadas a partir de las evaluaciones realizadas en el prototipo movil. Las variables se obtuvieron a partir de la telemetria de interaccion del estudiante, incluyendo tiempos de respuesta, aciertos, errores, taps erroneos, eventos de arrastrar y soltar, uso de pseudopalabras y complejidad del estimulo.

El proceso de construccion del dataset siguio una arquitectura offline-first: las evaluaciones fueron almacenadas localmente en el dispositivo y, al detectarse conectividad con el backend, fueron sincronizadas hacia la base de datos PostgreSQL. Posteriormente, el backend genero un dataset tabular para su uso en modelos supervisados.

La variable objetivo utilizada fue el semaforo de riesgo, compuesto por las clases VERDE, AMARILLO y ROJO. Esta clasificacion representa una estimacion de riesgo para fines de tamizaje educativo y no debe interpretarse como diagnostico clinico.
