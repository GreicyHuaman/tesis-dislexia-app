# Diccionario de variables del dataset de machine learning

Este documento describe las principales variables utilizadas para entrenar y validar los modelos de clasificación de riesgo de dislexia.

## 1. Variables de identificación

| Variable | Descripción |
|---|---|
| `evaluacion_id` | Identificador de la evaluación registrada en backend. |
| `estudiante_id` | Identificador del estudiante evaluado. |
| `seccion_id` | Identificador de la sección académica. |
| `tipo_prueba` | Tipo de evaluación aplicada: lectura o conciencia fonológica. |

## 2. Variables de tipo de prueba

| Variable | Descripción |
|---|---|
| `tipo_prueba_lectura` | Valor binario que indica si la evaluación corresponde a lectura. |
| `tipo_prueba_fonologia` | Valor binario que indica si la evaluación corresponde a conciencia fonológica. |
| `tipo_prueba_otro` | Valor binario para pruebas que no pertenecen a las categorías anteriores. |

## 3. Variables de desempeño general

| Variable | Descripción |
|---|---|
| `total_items` | Cantidad total de ítems presentados en la evaluación. |
| `aciertos_primer_intento` | Número de respuestas correctas en el primer intento. |
| `errores_primer_intento` | Número de respuestas incorrectas en el primer intento. |
| `error_rate` | Proporción de errores respecto al total de ítems. |
| `taps_erroneos_totales` | Total de toques o selecciones erróneas registradas. |
| `taps_rate` | Proporción de taps erróneos respecto al total de ítems. |

## 4. Variables temporales

| Variable | Descripción |
|---|---|
| `tiempo_promedio_ms` | Tiempo promedio de respuesta en milisegundos. |
| `tiempo_min_ms` | Menor tiempo de respuesta registrado en la evaluación. |
| `tiempo_max_ms` | Mayor tiempo de respuesta registrado en la evaluación. |
| `tiempo_std_ms` | Desviación estándar de los tiempos de respuesta. |

## 5. Variables de arrastrar y soltar

| Variable | Descripción |
|---|---|
| `items_drag_drop` | Cantidad de ítems que utilizaron interacción de arrastrar y soltar. |
| `drag_drop_rate` | Proporción de ítems drag/drop respecto al total. |
| `tiempo_promedio_drag_drop_ms` | Tiempo promedio de resolución en ítems drag/drop. |
| `errores_drag_drop` | Cantidad de errores cometidos en ítems drag/drop. |

## 6. Variables fonológicas y pseudopalabras

| Variable | Descripción |
|---|---|
| `items_palabra_real` | Cantidad de ítems basados en palabras reales. |
| `items_pseudopalabra` | Cantidad de ítems basados en pseudopalabras. |
| `pseudopalabra_rate` | Proporción de pseudopalabras respecto al total de ítems. |
| `errores_palabra_real` | Errores registrados en palabras reales. |
| `errores_pseudopalabra` | Errores registrados en pseudopalabras. |
| `tiempo_promedio_palabra_real_ms` | Tiempo promedio de respuesta en palabras reales. |
| `tiempo_promedio_pseudopalabra_ms` | Tiempo promedio de respuesta en pseudopalabras. |

## 7. Variables de complejidad del estímulo

| Variable | Descripción |
|---|---|
| `total_baja` | Cantidad de ítems de complejidad baja. |
| `total_media` | Cantidad de ítems de complejidad media. |
| `total_alta` | Cantidad de ítems de complejidad alta. |
| `total_sin_complejidad` | Cantidad de ítems sin complejidad clasificada. |
| `errores_baja` | Errores en ítems de complejidad baja. |
| `errores_media` | Errores en ítems de complejidad media. |
| `errores_alta` | Errores en ítems de complejidad alta. |
| `errores_sin_complejidad` | Errores en ítems sin complejidad clasificada. |

## 8. Variable objetivo

| Variable | Descripción |
|---|---|
| `porcentaje_riesgo` | Porcentaje estimado de riesgo calculado por el sistema. |
| `semaforo` | Clase objetivo utilizada para clasificación: `VERDE`, `AMARILLO` o `ROJO`. |

## 9. Observación metodológica

Las variables fueron diseñadas para capturar indicadores observables durante la interacción del estudiante con la aplicación. Estas variables no constituyen por sí mismas un diagnóstico, sino señales de desempeño que permiten estimar un nivel de riesgo preliminar para fines de tamizaje educativo.
