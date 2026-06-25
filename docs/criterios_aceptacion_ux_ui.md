# Criterios de aceptación UX/UI

## Objetivo

Definir los criterios mínimos que debe cumplir la interfaz del prototipo para considerarse adecuada para demostración académica.

## Criterios generales

| Código | Criterio | Estado esperado |
|---|---|---|
| UX-01 | La aplicación inicia sin errores. | Cumple |
| UX-02 | La pantalla inicial muestra ingreso por PIN. | Cumple |
| UX-03 | El usuario entiende que el sistema es de tamizaje. | Cumple |
| UX-04 | La navegación principal es clara. | Cumple |
| UX-05 | Los botones tienen textos comprensibles. | Cumple |
| UX-06 | Los mensajes de error son visibles. | Cumple |
| UX-07 | Las pantallas de carga no quedan en blanco. | Cumple |
| UX-08 | Los estados vacíos muestran mensaje explicativo. | Cumple |
| UX-09 | Los semáforos se diferencian visualmente. | Cumple |
| UX-10 | El resultado indica que no es diagnóstico clínico. | Cumple |

## Criterios para estudiantes

| Código | Criterio | Estado esperado |
|---|---|---|
| EST-01 | El estudiante ingresa con PIN de 4 dígitos. | Cumple |
| EST-02 | No se solicitan datos personales al menor durante la prueba. | Cumple |
| EST-03 | La selección de prueba es simple. | Cumple |
| EST-04 | Las opciones de lectura son visibles. | Cumple |
| EST-05 | La interacción drag/drop es comprensible. | Cumple |
| EST-06 | El resultado final usa porcentaje y semáforo. | Cumple |

## Criterios para personal académico

| Código | Criterio | Estado esperado |
|---|---|---|
| DOC-01 | El personal inicia sesión con correo y contraseña. | Cumple |
| DOC-02 | Los reportes requieren JWT. | Cumple |
| DOC-03 | El portal muestra evaluaciones registradas. | Cumple |
| DOC-04 | Los filtros permiten revisar por prueba o semáforo. | Cumple |
| DOC-05 | Se puede exportar CSV. | Cumple |
| DOC-06 | Se puede exportar PDF general. | Cumple |
| DOC-07 | Se puede consultar perfil individual. | Cumple |
| DOC-08 | Se puede exportar PDF individual. | Cumple |

## Criterios para directora

| Código | Criterio | Estado esperado |
|---|---|---|
| DIR-01 | La directora accede al panel administrativo. | Cumple |
| DIR-02 | Puede gestionar estudiantes. | Cumple |
| DIR-03 | Puede gestionar secciones. | Cumple |
| DIR-04 | Puede gestionar usuarios. | Cumple |
| DIR-05 | Puede gestionar asignaciones docente-sección. | Cumple |

## Criterios de accesibilidad básica

| Código | Criterio | Estado esperado |
|---|---|---|
| ACC-01 | Botones suficientemente grandes. | Cumple |
| ACC-02 | Textos principales legibles. | Cumple |
| ACC-03 | Iconos acompañados por texto o tooltip. | Cumple |
| ACC-04 | Colores de riesgo acompañados por texto. | Cumple |
| ACC-05 | La app no depende solo del color para comunicar riesgo. | Cumple |

## Criterio de cierre

El Sprint 27 se considera aceptado cuando:

    flutter analyze

termina con:

    No issues found!

y se validan visualmente las pantallas principales.
