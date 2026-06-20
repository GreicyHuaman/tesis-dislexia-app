# Resultados de validación del modelo de machine learning

Documento generado el 20/06/2026 11:06.

## 1. Alcance de la validación

La validación corresponde al componente de machine learning del prototipo de tamizaje temprano de riesgo de dislexia. El objetivo del modelo es clasificar el nivel de riesgo en un esquema de semáforo: `VERDE`, `AMARILLO` o `ROJO`, a partir de variables de desempeño registradas durante las pruebas de lectura y conciencia fonológica.

El resultado del modelo debe interpretarse como apoyo para tamizaje educativo y no como diagnóstico clínico. La confirmación diagnóstica requiere evaluación profesional especializada.

## 2. Distribución de clases

El conjunto de datos utilizado contiene **34 evaluaciones**.

| Clase | Total | Porcentaje |
|---|---:|---:|
| VERDE | 25 | 73.53% |
| ROJO | 5 | 14.71% |
| AMARILLO | 4 | 11.76% |

## 3. Comparación de modelos

Se compararon los modelos disponibles considerando métricas de clasificación. Para conjuntos de datos desbalanceados se recomienda observar especialmente el `F1 macro`, porque resume el desempeño promedio por clase.

| Modelo | Estado | Accuracy | Precision macro | Recall macro | F1 macro | F1 weighted | Observación |
|---|---|---:|---:|---:|---:|---:|---|
| Random Forest | OK | 0.9091 | 0.8333 | 0.8333 | 0.7778 | 0.9091 | - |
| XGBoost | OK | 0.8182 | 0.6296 | 0.5000 | 0.5359 | 0.8057 | - |

De acuerdo con las métricas disponibles, el modelo con mejor valor de `F1 macro` fue **Random Forest**.

## 4. Matriz de confusión - Random Forest

| Clase real | pred_VERDE | pred_AMARILLO | pred_ROJO |
|---|---:|---:|---:|
| real_VERDE | 8 | 0 | 0 |
| real_AMARILLO | 0 | 1 | 0 |
| real_ROJO | 0 | 1 | 1 |

## 5. Variables más importantes - Random Forest

Las siguientes variables tuvieron mayor peso relativo en el modelo:

| Variable | Importancia |
|---|---:|
| `error_rate` | 0.154096 |
| `aciertos_primer_intento` | 0.119048 |
| `errores_primer_intento` | 0.112382 |
| `taps_erroneos_totales` | 0.107223 |
| `taps_rate` | 0.105107 |
| `tiempo_std_ms` | 0.075052 |
| `tiempo_max_ms` | 0.072934 |
| `errores_media` | 0.051072 |
| `total_alta` | 0.050375 |
| `errores_baja` | 0.043883 |

## 4. Matriz de confusión - XGBoost

| Clase real | pred_VERDE | pred_AMARILLO | pred_ROJO |
|---|---:|---:|---:|
| real_VERDE | 8 | 0 | 0 |
| real_AMARILLO | 1 | 0 | 0 |
| real_ROJO | 0 | 1 | 1 |

## 5. Variables más importantes - XGBoost

Las siguientes variables tuvieron mayor peso relativo en el modelo:

| Variable | Importancia |
|---|---:|
| `taps_erroneos_totales` | 0.188648 |
| `errores_baja` | 0.179836 |
| `error_rate` | 0.140419 |
| `errores_primer_intento` | 0.120429 |
| `aciertos_primer_intento` | 0.120236 |
| `errores_alta` | 0.072735 |
| `tiempo_std_ms` | 0.066420 |
| `total_alta` | 0.033641 |
| `errores_media` | 0.028853 |
| `tiempo_max_ms` | 0.025175 |

## 6. Interpretación técnica

En esta etapa, la validación permite comprobar que el sistema puede extraer características, construir un vector de entrada, entrenar un modelo y generar salidas interpretables para el personal académico.

## 7. Limitaciones

Las principales limitaciones de esta validación son:

- Tamaño actual del dataset: 34 evaluaciones.
- Posible desbalance entre clases `VERDE`, `AMARILLO` y `ROJO`.
- Datos recolectados en etapa de prototipo.
- El modelo no reemplaza una evaluación clínica o psicopedagógica.
- La generalización debe comprobarse con una muestra mayor y diversa.

## 8. Texto sugerido para la tesis

La validación del componente de machine learning se realizó utilizando un conjunto de datos compuesto por 34 evaluaciones registradas por el prototipo. A partir de las interacciones del estudiante durante las pruebas de lectura y conciencia fonológica, se extrajeron variables como tiempos de respuesta, cantidad de aciertos, errores de selección, eventos de arrastre y características asociadas a pseudopalabras.

El modelo con mejor desempeño preliminar según las métricas disponibles fue Random Forest. No obstante, debido al tamaño reducido del conjunto de datos y al posible desbalance entre clases, estos resultados deben interpretarse como una validación técnica preliminar del pipeline de clasificación y no como una validación clínica definitiva.

Los resultados evidencian que el prototipo permite capturar datos de evaluación, sincronizarlos con el backend, construir un dataset estructurado y aplicar modelos supervisados para estimar un nivel de riesgo mediante un semáforo interpretativo. Este enfoque proporciona una base funcional para futuras validaciones con muestras más amplias y supervisión profesional.
