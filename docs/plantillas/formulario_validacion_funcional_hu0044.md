# Disly - Formulario de validación funcional (HU0044 / CP044)

Versión del instrumento: 1.0.
Estado: cuestionario e instrucciones preparados; formulario externo aún no
creado, publicado ni ejecutado por QA. No existe un enlace de acceso en esta
plantilla.

## 1. Alcance y responsables

Dirigido a docentes y directores adultos que participaron en una prueba de uso
de Disly. Recoge su percepción de funcionalidad, claridad, utilidad y navegación.
Es un instrumento propuesto para el proyecto, no una escala estandarizada ni una
medición de eficacia del modelo.

Se entrega como formulario externo de Google Forms por decisión de la usuaria.
HU0044 y CP044 no exigen incorporarlo a la aplicación. Esta entrega no requiere
cambios en Flutter, FastAPI ni Railway.

El equipo Disly crea y administra el formulario; QA recibe el enlace para
responder y una vía autorizada para comprobar el registro. Responder no concede
acceso al resto de las respuestas.

## 2. Texto para copiar en Google Forms

### Título

Disly - Formulario de validación funcional

### Descripción

Este formulario recoge tu opinión después de usar Disly. Responde según las
tareas que realizaste con tu rol de docente o director. No hay respuestas
correctas o incorrectas; tu opinión nos ayuda a mejorar la aplicación.

Disly apoya el tamizaje educativo mediante una estimación de riesgo y un semáforo
de riesgo para orientar el seguimiento pedagógico. No constituye diagnóstico
clínico.

La participación es voluntaria. Usa el código que te entregue el equipo, no tu
nombre. No escribas nombres de estudiantes, PIN, contraseñas, documentos de
identidad, correos ni información de salud. Las respuestas serán revisadas por
el equipo autorizado para la validación funcional del proyecto.

### Sección A - Datos básicos de la prueba

Crear estas preguntas en el orden indicado:

| ID | Pregunta | Tipo en Google Forms | Configuración |
|---|---|---|---|
| A1 | Código de participante | Respuesta corta | Obligatoria. Ayuda: «Usa el código entregado por el equipo, por ejemplo QA-CP044-01. No escribas tu nombre». |
| A2 | Rol con el que usaste Disly | Varias opciones | Obligatoria. Opciones: Docente; Director/a. |
| A3 | Código de sesión de prueba | Respuesta corta | Obligatoria. Ayuda: «Copia el código entregado por el equipo, por ejemplo SESION-CP044-01». |
| A4 | Confirmación de participación | Casillas | Obligatoria. Única opción: «Soy una persona adulta y participé en la prueba de uso de Disly». |

El equipo debe entregar ambos códigos antes de responder y asociar la sesión
con la versión o compilación de la app evaluada en su registro de pruebas.
Google Forms registra la fecha y hora del envío; no solicitar la fecha de
nacimiento ni la edad de participantes o estudiantes.

### Sección B - Tu experiencia con Disly

Descripción de la sección:

> Marca una respuesta por afirmación según tu experiencia. Si una función no
> corresponde a tu rol o no la utilizaste, elige «No lo utilicé / No aplica».

Crear **cada afirmación como una pregunta individual de «Varias opciones»**,
obligatoria, con estas mismas seis opciones, en este orden:

- 1 - Totalmente en desacuerdo
- 2 - En desacuerdo
- 3 - Ni de acuerdo ni en desacuerdo
- 4 - De acuerdo
- 5 - Totalmente de acuerdo
- No lo utilicé / No aplica

No usar una escala lineal que impida seleccionar «No aplica», no marcar opciones
por defecto y no convertir el formulario en un cuestionario con calificación.

| ID | Dimensión | Texto de la afirmación |
|---|---|---|
| F1 | Funcionalidad | Pude completar las tareas que me correspondían con mi rol. |
| F2 | Funcionalidad | Pude consultar los reportes que necesitaba durante la prueba. |
| F3 | Funcionalidad | Pude registrar una observación de seguimiento cuando me correspondió hacerlo. |
| C1 | Claridad | Entendí las instrucciones de la aplicación. |
| C2 | Claridad | Entendí los mensajes que mostró la aplicación. |
| C3 | Claridad | Comprendí qué significa el semáforo de riesgo. |
| U1 | Utilidad | La información de los reportes me resulta útil para el seguimiento pedagógico. |
| U2 | Utilidad | La estimación de riesgo me ayuda a identificar necesidades de refuerzo pedagógico. |
| N1 | Navegación | Encontré con facilidad las opciones que necesitaba. |
| N2 | Navegación | Pude volver a las pantallas anteriores sin confundirme. |

### Sección C - Comentarios

| ID | Pregunta | Tipo | Obligatoria |
|---|---|---|---|
| O1 | ¿En qué parte tuviste dificultades? | Párrafo | No |
| O2 | ¿Qué mejorarías de Disly? | Párrafo | No |

Agregar como ayuda en ambas preguntas: «Describe la función o pantalla sin
incluir datos de estudiantes ni información personal».

### Mensaje de confirmación

> Gracias por responder. Tu respuesta fue registrada.

Este mensaje no sustituye la comprobación de la respuesta en Google Forms.

## 3. Crear, configurar y publicar

1. Entrar en [Google Forms](https://forms.google.com) con la cuenta del equipo
   responsable y crear un formulario en blanco. Copiar el título, descripción,
   secciones, preguntas y mensaje de confirmación anteriores.
2. En **Configuración**, no activar «Convertir en un cuestionario». En
   **Respuestas**, seleccionar no recopilar direcciones de correo, desactivar
   «Limitar a 1 respuesta» y «Permitir modificar las respuestas». No añadir
   preguntas de subida de archivos. Así se evitan requisitos de cuenta
   innecesarios; el acceso real debe comprobarse después de publicar.
3. En **Configuración > Presentación**, dejar desactivado **Ver resumen de
   resultados**. Las respuestas y los comentarios no deben quedar visibles
   para quienes respondan.
4. En la pestaña **Respuestas**, seleccionar **Vincular con Hojas de cálculo**
   y crear una hoja privada para el registro. Comprobar la zona horaria de la
   hoja para interpretar correctamente la marca temporal.
5. Mantener el formulario de edición y la hoja restringidos al equipo
   autorizado. No publicar la hoja ni entregar el enlace de edición como enlace
   para responder. Revisar los permisos del formulario y de la hoja por separado.
6. Pulsar **Publicar** y revisar **Gestionar / Acceso general**. Para este
   cuestionario sin datos personales requeridos, habilitar responder a quien
   tenga el enlace y compartirlo solo con los participantes y QA. Publicar y
   comprobar que **Se aceptan respuestas** esté activo.
7. Copiar el enlace **para encuestados**, no el de edición. Abrirlo en una
   ventana privada sin iniciar sesión: debe permitir responder sin pedir acceso
   a la organización ni a la hoja. Si la política de Google Workspace impide
   ese acceso, resolverlo con el administrador o acordar el acceso con QA antes
   de entregar; no declarar el formulario disponible mientras siga bloqueado.
8. Entregar a QA el enlace real, los códigos de prueba, el rol, la sesión y
   versión evaluada, y el responsable que comprobará la persistencia.

Desactivar «Limitar a 1 respuesta» no impide envíos duplicados. Para el piloto,
asignar un código distinto por participante y sesión, solicitar un solo envío
y revisar duplicados sin eliminar respuestas automáticamente. El código no
autentica al participante ni equivale a una cuenta de Disly.

## 4. Entrega y ejecución de CP044

### Datos que debe completar el equipo antes de entregar a QA

| Dato | Valor por completar |
|---|---|
| Enlace real para responder | Pendiente de publicación |
| Responsable de Google Forms y del registro | Pendiente de designación |
| Fecha y ventana de ejecución QA | Pendiente de coordinación |
| Código de participante de prueba | QA-CP044-01 (ficticio, reservar para QA) |
| Rol del participante que realizó la prueba de uso | Docente o Director/a, según la sesión real |
| Código de sesión | SESION-CP044-01 (ficticio, registrar antes de probar) |
| Versión o compilación de Disly usada en esa sesión | Pendiente de registrar |
| Verificación del registro | Con el responsable en Respuestas > Individual y en la hoja privada |

Los valores pendientes deben completarse antes de declarar que el material fue
entregado. No inventar un enlace, una versión, una participación ni respuestas.
Los envíos con códigos QA son evidencia técnica, no opiniones de participantes
reales para los resultados de la tesis.

### Precondiciones

- El docente o director adulto participó en la prueba de uso.
- El formulario está publicado, acepta respuestas y su enlace fue entregado.
- Hay conexión a Internet: este formulario externo no forma parte del modo
  offline-first de Disly.
- El responsable puede comprobar respuestas y la hoja vinculada. Si QA no tiene
  ese acceso, coordinar una comprobación supervisada sin abrir datos de terceros.

### Pasos y resultados esperados

| Paso | Acción | Resultado esperado y evidencia |
|---|---|---|
| 1 | El responsable anota el total de respuestas y verifica que el código QA-CP044-01 de la sesión no tenga un envío previo. QA abre el enlace para encuestados en una ventana privada. | Se abre el título correcto, las tres secciones están disponibles y no se exige acceso a la edición o a la organización. Captura de apertura. |
| 2 | Completar A1-A4 con los datos de prueba. En B seleccionar, en orden F1-F3, C1-C3, U1-U2, N1-N2: 4, 3, No aplica, 5, 2, 4, 3, 5, 4, 3. En O1 escribir «PRUEBA QA CP044 - comprobar registro». O2 puede quedar vacío. | Los campos aceptan los datos; todas las preguntas obligatorias tienen respuesta, incluido «No lo utilicé / No aplica» para F3. Son valores ficticios para comprobar almacenamiento, no una valoración real. |
| 3 | Pulsar Enviar una sola vez. | Se muestra «Gracias por responder. Tu respuesta fue registrada.». Captura de confirmación. |
| 4 | El responsable abre Respuestas > Individual y busca el envío por código y sesión. | Existe una respuesta nueva con ambos códigos, rol, confirmación, las diez opciones exactas, O1 y marca temporal. Verificar los valores, no solo el contador. |
| 5 | Revisar la hoja privada vinculada, recargarla y volver a abrir la respuesta en Forms. | El mismo envío permanece con sus datos completos. Con la ejecución aislada, el total aumenta en uno; si hubo otros envíos, localizar este por código y sesión. Captura de la fila QA, sin otras respuestas. |
| 6 | Desde el enlace de encuestados, comprobar que no se ofrece el resumen de resultados ni acceso a la hoja. | El participante no puede consultar las respuestas de otros. |

Prueba negativa complementaria: antes del envío positivo, intentar enviar con
F1 sin responder. Google Forms debe señalar el campo obligatorio y no crear
ninguna respuesta; completarlo después para continuar. O1 y O2 pueden quedar
vacíos y no deben bloquear el envío.

Postcondición de CP044: la respuesta enviada permanece consultable por el equipo
autorizado y coincide con los datos introducidos. Si aparece confirmación pero
falta el registro en Forms, falla la persistencia; si solo falta en la hoja,
revisar la vinculación y no declarar completa esta entrega.

Una opinión desfavorable no hace fallar CP044: el caso comprueba captura y
registro, no exige respuestas positivas ni demuestra eficacia del tamizaje.
En el análisis, «No aplica» no cuenta como cero ni como una respuesta favorable;
se excluye del cálculo de cada ítem y se informa cuántas respuestas aplicables
hubo. No se fija un umbral de aprobación no acordado para HU0044.

## 5. Cierre de QA0002652

No anular HU0044 ni CP044. Completar en CP044 los datos de prueba, el enlace,
el paso de comprobación del registro y la postcondición anteriores. No se han
editado los documentos originales adjuntos.

La incidencia queda pendiente de entrega y revalidación hasta crear y publicar
el formulario, entregar el enlace con instrucciones y comprobar el envío real.
Esta plantilla, por sí sola, no acredita que el formulario ya esté operativo.

## 6. Referencias de configuración

Ayuda oficial de Google consultada el 05/11/2026:

- [Publicar y compartir el formulario con los encuestados](https://support.google.com/docs/answer/2839588?hl=es).
- [Ver y gestionar las respuestas de los formularios](https://support.google.com/docs/answer/139706?hl=es).
