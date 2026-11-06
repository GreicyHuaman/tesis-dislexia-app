# PROJECT_CONTEXT.md - Disly

## Resumen general

Disly es una app movil offline-first para tamizaje educativo de riesgo de dislexia en estudiantes de tercer grado.

El sistema no diagnostica dislexia. Los resultados son una estimacion de riesgo para seguimiento pedagogico y posible derivacion sugerida.

## Stack tecnico

Mobile:
- Flutter / Dart
- Hive local storage
- Offline-first
- APK Android

Backend:
- FastAPI / Python
- SQLModel
- PostgreSQL
- Railway

ML:
- Random Forest
- XGBoost
- Dataset sintetico/piloto de validacion tecnica
- No validacion clinica

## Repositorio

Ruta local:
C:\Users\Greic\tesis-dislexia-app

Repositorio GitHub:
https://github.com/GreicyHuaman/tesis-dislexia-app.git

Rama principal:
main

Backend Railway:
https://tesis-dislexia-app-production.up.railway.app

## Usuarios demo

Directora:
directora@demo.com / 123456

Docente:
maestra3a@demo.com / 123456

Psicologia:
psicologa@demo.com / 123456
psicologa3@demo.com / 123456

## Flujo principal

1. Directora inicia sesion.
2. Gestiona secciones.
3. Registra estudiante con consentimiento.
4. Asigna docente a seccion.
5. Docente inicia sesion.
6. Entra a Reportes.
7. Desde Reportes entra a Panel docente.
8. Activa jornada o modo aula.
9. Estudiante ingresa PIN.
10. Realiza prueba.
11. App sincroniza evaluacion.
12. Personal revisa reportes.
13. Personal revisa seguimiento semanal.

## Sprint 27B ML

Se entreno ML con dataset sintetico/piloto de 160 estudiantes.

Resultados:
- Random Forest accuracy: 0.8750
- Random Forest weighted F1: 0.8707
- XGBoost accuracy: 0.7917
- XGBoost weighted F1: 0.7724
- Random Forest Regressor MAE: 6.6554 puntos porcentuales
- R2: 0.6882

Estos resultados son validacion tecnica del pipeline, no validacion clinica.

## Sprint 30B

Objetivo:
Gestion institucional, matricula, PIN seguro, jornadas activas e intentos fallidos.

Implementado:
- Gestion de estudiantes.
- Gestion de secciones.
- Docente-seccion.
- PIN automatico seguro.
- Jornada activa / modo aula.
- Bloqueo por intentos fallidos de PIN.
- Login diferenciado por rol.
- Panel administrativo para directora.
- Panel docente para maestro.
- Reportes primero al iniciar sesion como personal.
- Acceso a panel desde Reportes.

Estado:
La demo fue aprobada por el director.

Decision posterior:
El campo codigo_estudiante no es necesario y no debe incluirse en Excel/CSV de importacion. Puede quedar internamente en base de datos, pero no debe ser visible ni obligatorio.

Columnas actuales de importacion:
- nombres
- apellidos
- fecha_nacimiento
- grado
- seccion
- consentimiento_firmado
- fecha_consentimiento
- activo

### Correccion local QA 0002522 - HU0005 / CP005

- El registro y la edicion de secciones muestran el grado fijo en 3.o de primaria.
- El turno se selecciona obligatoriamente entre Manana y Tarde. Los valores
  persistidos son `MAÑANA` y `TARDE`.
- El backend rechaza grados distintos de 3 y turnos nulos, vacios o no autorizados.
  Las variantes de mayusculas/minusculas y el valor anterior `MANANA` se
  normalizan al guardar; no se aceptan textos libres como "turno manana".
- No se modifican automaticamente registros antiguos. Al editar una seccion con
  turno vacio o desconocido, se solicita elegir un turno autorizado.
- En HU0005-1, precisar el evento: registrar el nombre de la seccion de 3.o de
  primaria y seleccionar un turno obligatorio. El resultado debe incluir grado 3
  y turno estandarizado, ademas de disponibilidad para asignaciones.
- CP005 positivo: verificar el grado no editable, ingresar una seccion no
  registrada, seleccionar Manana o Tarde, guardar y confirmar ambos valores
  en el listado. Completar su postcondicion con la seccion creada y disponible.
- Caso negativo separado (numeracion pendiente): guardar sin seleccionar turno
  debe mostrar "Selecciona un turno." y mantener abierto el formulario sin
  registrar la seccion. Las llamadas directas con grado 4/5, turno vacio o no
  autorizado deben devolver HTTP 422 sin escribir datos.
- Estos cambios son locales, sin commit, push ni despliegue a Railway. Las
  pruebas automaticas utilizan SQLite en memoria y un formulario aislado.

### Correccion local QA 0002524 - HU0006 / CP006

- `GET /api/v1/secciones` devuelve al docente solo sus secciones activas,
  segun las asignaciones de `docente_seccion`. Direccion y psicologia conservan
  su visibilidad institucional.
- Modo aula y el formulario de estudiantes usan el mismo listado filtrado.
  No se ofrecen secciones ajenas ni se preselecciona un identificador que
  ya no este disponible.
- Al cambiar de cuenta o actualizar asignaciones, se recarga el alcance.
  Un modo aula local de una seccion no disponible se desactiva con aviso;
  no se cierra ninguna jornada del servidor ni se borran evaluaciones.
- Sin secciones activas asignadas, se muestra "No tienes secciones activas
  asignadas. Solicita la asignacion al director." y no se habilita activar jornada
  ni crear estudiantes.
- HU0006-1 y CP006 ya exigen visualizar solo las secciones asignadas:
  no necesitan cambiar su regla. Completar CP006 con Jessica Linares asignada
  a 3 X, otras secciones no asignadas y verificacion explicita en los selectores
  de Modo aula y de estudiantes. Postcondicion: asignacion persistida y acceso
  limitado a las secciones asignadas.
- Casos complementarios: docente sin asignaciones, varias asignaciones,
  seccion inactiva, reasignacion y cambio de cuenta en el mismo dispositivo.
- Cambios locales sin commit, push ni despliegue. Pruebas en SQLite en memoria
  y Flutter con servicios simulados y almacenamiento temporal aislado.

### Correccion local QA 0002525 - HU0007 / CP007

- Nombres, apellidos y fecha de nacimiento son obligatorios en el registro.
  Los nombres y apellidos no pueden ser vacios, nulos ni contener solo espacios;
  se eliminan espacios al inicio y al final sin restringir nombres legitimos
  con tildes, espacios internos o apostrofes.
- Por decision de la usuaria, el rango de edad es obligatorio: solo se permite
  guardar fechas que correspondan a 8 o 9 anos cumplidos, desde el octavo
  cumpleanos hasta el dia anterior al decimo. No se usan anios de nacimiento
  fijos. Mobile y backend calculan la edad con la fecha de Lima (UTC-5).
- Se rechazan fechas ausentes, imposibles, futuras o fuera del rango.
  Flutter admite YYYY-MM-DD y DD/MM/YYYY y envia la fecha normalizada en ISO.
  Antes de cerrar el formulario se muestran errores por campo, conservando
  los datos y sin enviar una peticion de registro o edicion.
- Mensajes del formulario: "Ingresa los nombres del estudiante.",
  "Ingresa los apellidos del estudiante.",
  "Ingresa la fecha de nacimiento del estudiante." y
  "El estudiante debe tener entre 8 y 9 años cumplidos.".
- La creacion por API rechaza datos invalidos con HTTP 422 antes de generar
  PIN o guardar. En PATCH se validan los campos enviados; omitir un campo
  mantiene su valor, pero enviar nombres o nacimiento nulos no lo elimina.
  No se migran registros anteriores; el formulario solicita corregir datos
  invalidos al editarlos.
- La importacion CSV/XLSX aplica la misma regla de nacimiento antes de crear
  o actualizar cada estudiante. Los nombres ya eran obligatorios en este flujo.
  Las filas invalidas se reportan individualmente sin guardar ni sobrescribir
  estudiantes; las filas validas conservan el procesamiento anterior.
- Se mantienen las reglas de consentimiento y PIN: con datos validos y
  consentimiento firmado con fecha, el registro puede quedar activo y con
  PIN automatico. La edicion valida no regenera el PIN existente.
- HU0007-1: precisar que el registro requiere nombres, apellidos y nacimiento
  valido de 8 a 9 anos, ademas del consentimiento y la seccion correspondiente.
  El resultado conserva al estudiante activo y habilitado para evaluacion.
  HU0007-2 mantiene el rechazo de habilitacion sin consentimiento.
- CP007 permanece positivo: ingresar datos completos con fecha que corresponda
  a 8 o 9 anos, marcar consentimiento, guardar y verificar datos persistidos,
  estado activo y PIN. Postcondicion: estudiante registrado con consentimiento
  y habilitado para evaluacion.
- CP negativo separado, numeracion pendiente: intentar guardar nombres o
  apellidos vacios/espacios, nacimiento ausente/imposible/futuro, de 2006,
  de 7 anos o de 10 anos. Resultado: mensaje por campo, formulario abierto,
  datos conservados y ningun estudiante/PIN nuevo. No mezclarlo con el caso
  negativo de consentimiento de HU0007-2.
- Las HU/CP adjuntas son imagenes; estos son ajustes sugeridos, no ediciones
  de sus archivos originales.
- Verificacion local: desde backend, `.venv\Scripts\python.exe -m unittest
  discover -s tests -p "test_*.py"`; desde mobile, `flutter test --no-pub
  test\student_form_validation_test.dart test\teacher_section_scope_test.dart
  test\section_form_dialog_test.dart`. Las pruebas utilizan SQLite en memoria,
  servicios simulados y Hive temporal, sin conexiones a Railway.
- Cambios exclusivamente locales, sin commit, push, despliegue ni modificaciones
  de datos remotos. La URL predeterminada de la app no se cambia.

### Correccion local QA 0002528 - HU0013 / CP013

- Modo aula incorpora la opcion explicita "Descargar sección", habilitada
  solo para una seccion activa disponible para la cuenta actual.
- Por decision de la usuaria, la descarga activa o recupera una jornada y
  prepara la seccion en un solo paso. No requiere pulsar antes "Activar jornada".
  Se conserva la preparacion automatica del boton "Activar jornada".
- Se guardan localmente los estudiantes activos con consentimiento firmado,
  sus PIN, datos y niveles de lectura/fonologia. La descarga reemplaza el
  padron de esa seccion, retirando entradas antiguas que ya no estan habilitadas
  sin borrar el padron de otras secciones ni las evaluaciones.
- Los estimulos de lectura y fonologia vienen incluidos en la aplicacion.
  Antes de confirmar la descarga se verifica que ambos recursos se pueden leer.
- La jornada debe estar activa, vigente y pertenecer a la seccion seleccionada.
  El modo aula se guarda despues del padron y de verificar los recursos.
  No se confirma una descarga con padron vacio, PIN invalidos/duplicados,
  errores de lectura/almacenamiento o una jornada invalida.
- La confirmacion indica la seccion y cantidad de estudiantes habilitados:
  "Sección 3 A descargada: 3 estudiantes habilitados. Disponible sin conexión
  mientras la jornada siga vigente.". Los controles se bloquean temporalmente
  durante la preparacion para evitar operaciones simultaneas.
- Sin padron local de la seccion, el ingreso informa:
  "Esta sección no está disponible sin conexión. Pide al docente que use
  “Descargar sección” con conexión a Internet.". La falta de preparacion no
  se contabiliza como PIN incorrecto. Un PIN incorrecto en un padron existente
  mantiene el control anterior de intentos.
- HU0013-1 y CP013 mantienen la opcion "Descargar seccion". Precisar que
  prepara una jornada vigente y confirmar su disponibilidad antes de desconectar.
  Para ingresar sin conexion se utiliza "Ir a PIN estudiante"; no se incorpora
  un modulo nuevo de consulta/listado docente offline.
- CP013 debe ejecutarse con estudiantes habilitados y PIN validos, en un
  dispositivo sin datos previos de esa seccion. Comprobar confirmacion de descarga,
  ingreso PIN, niveles y prueba sin red. La disponibilidad para ingreso esta
  condicionada a la vigencia de la jornada, aun cuando el padron permanezca local.
- HU0013-2 corresponde a falta de preparacion previa (sin descarga explicita
  ni preparacion automatica mediante Activar jornada). Las respuestas se
  conservan localmente; las evaluaciones finalizadas quedan pendientes de
  sincronizacion hasta recuperar la conexion.
- Verificacion aislada en `mobile\test\teacher_section_scope_test.dart` y
  `mobile\test\offline_student_cache_test.dart`: servicios simulados, HTTP
  sustituido por MockClient y Hive temporal; no se utilizan cuentas ni datos
  de Railway.
- Cambios exclusivamente locales, sin commit, push ni despliegue. La URL
  predeterminada de la aplicacion no se modifica.

## Sprint 31

Objetivo:
Seguimiento semanal longitudinal.

Implementado backend:
- backend/app/models/seguimiento.py
- backend/app/schemas/seguimiento_schema.py
- backend/app/api/seguimiento.py
- scripts/migrate_sprint_31_seguimiento.py
- Router en backend/app/main.py

Endpoints:
- GET /api/v1/seguimiento/resumen
- GET /api/v1/seguimiento/priorizados
- GET /api/v1/seguimiento/estudiante/{estudiante_id}
- POST /api/v1/seguimiento/observaciones
- PATCH /api/v1/seguimiento/{seguimiento_id}

Implementado Flutter:
- mobile/lib/core/models/seguimiento_models.dart
- mobile/lib/core/services/seguimiento_service.dart
- mobile/lib/features/seguimiento/screens/seguimiento_screen.dart
- Acceso desde ReportesScreen

Reglas:
- Proxima evaluacion = ultima evaluacion + 7 dias.
- Estados: SIN_EVALUACION, AL_DIA, VENCE_HOY, VENCIDA.
- Tendencia: MEJORA, ESTABLE, EMPEORA, SIN_HISTORIAL.
- Prioridad: ALTA, MEDIA, BAJA.

Observaciones:
- VERDE: opcional.
- AMARILLO: recomendada.
- ROJO: obligatoria.
- VENCIDA: obligatoria.
- Derivacion sugerida o cierre manual: obligatoria.

Estado:
Sprint 31 funciona y fue mergeado a main.

## Sprint 32 sugerido

Objetivo:
Banco adaptativo de palabras.

Reglas acordadas:
- Aplica a lectura y fonologia.
- Cada prueba tiene 10 items.
- Niveles separados: nivel_lectura y nivel_fonologia.
- Todos empiezan en nivel 1.
- Nivel 1: 10 faciles.
- Nivel 2: 6 faciles + 4 medias.
- Nivel 3: 4 faciles + 4 medias + 2 dificiles.
- Subir un nivel solo con dos VERDE consecutivos en el mismo tipo de prueba.
- AMARILLO mantiene nivel.
- ROJO baja un nivel si aplica.
- No mostrar dificultad en PDF.
- Guardar internamente nivel aplicado, distribucion de dificultad y version del banco.

Banco aprobado:
- 540 estimulos.
- BAJA: 180.
- MEDIA: 180.
- ALTA: 180.
- Revision docente aprobada.

Archivos relacionados:
- data/word_bank/v1/
- backend/app/data/word_bank/
- scripts/prepare_word_bank_v1.py

## Reglas para Codex

Antes de modificar:
1. Leer AGENTS.md.
2. Leer docs/codex/PROJECT_CONTEXT.md.
3. Revisar archivos reales del repo.
4. Proponer plan.
5. Esperar confirmacion si la tarea es grande.

No hacer:
- Deploy Railway sin permiso.
- Push a main sin permiso.
- Subir APK.
- Guardar secretos.
- Afirmar diagnostico clinico.
- Afirmar validacion clinica.

Comandos minimos:

Backend:
cd C:\Users\Greic\tesis-dislexia-app\backend
python -m compileall app

Mobile:
cd C:\Users\Greic\tesis-dislexia-app\mobile
flutter analyze

## QA0002531 - Mensajes de conexion (HU0024 / CP024)

- Reportes, perfil del estudiante, exportacion CSV y sincronizacion de evaluaciones
  muestran mensajes comprensibles, sin excepciones, URL ni cuerpos de respuestas.
- Sin una interfaz de red disponible se muestra exactamente:
  "Sin conexión a Internet. Verifique su conexión y vuelva a intentarlo."
  La solicitud HTTP no se envia.
- Timeout con red disponible o respuesta HTTP 5xx: servicio temporalmente no
  disponible. Un fallo de transporte con interfaz activa no prueba por si solo
  que falte Internet: se muestra un mensaje general de conexion.
- La presencia de Wi-Fi o datos moviles no garantiza acceso efectivo a Internet.
  Se comprueba nuevamente la conectividad despues de un fallo de transporte.
- Se conserva Reintentar y la recuperacion cuando vuelve la conexion, los filtros,
  los datos ya cargados y las evaluaciones pendientes guardadas en Hive.
- HTTP 401 conserva el aviso de sesion vencida; HTTP 403 indica falta de permiso.
  Los errores inesperados se registran en consola sin tokens, URL ni cuerpos,
  y se muestran con un mensaje general de la operacion.
- No se modifican mensajes del alumno, reglas adaptativas ni calculo de riesgo.
- Verificar localmente con pruebas HTTP simuladas. No probar guardados contra
  Railway ni desplegar como parte de esta incidencia.

## QA0002532 - Exportacion PDF institucional (HU0031 / CP031)

- Reproduccion local: un reporte docente de 5 filas se generaba; reportes de
  100 y 2500 filas fallaban con TooManyPagesException.
- La tabla de evaluaciones se encontraba dentro de Column, que impedia su
  paginacion correcta. Se coloca directamente en MultiPage, en bloques de
  hasta 100 filas que conservan todos los registros y repiten los encabezados.
  No se aumenta ni elimina arbitrariamente la proteccion de maxPages.
- La generacion se ejecuta con compute fuera del hilo de la interfaz en mobile.
  La pantalla muestra progreso y evita exportaciones simultaneas.
- Los errores de generacion o guardado se notifican sin detalles tecnicos.
  Se conserva el flujo de guardado y apertura existente para docente/director
  y el PDF individual; no se cambian permisos, filtros ni datos del backend.
- Se verifica el contenido de los PDF generados con datos ficticios locales:
  todas las filas, totales, paginacion y lenguaje de tamizaje educativo no
  diagnostico. Se corrige la lectura del total de cada semaforo en el resumen PDF.
- Las pruebas cubren reportes de 5, 100 y 2500 filas (1, 4 y 73 paginas),
  reporte vacio, PDF individual con tildes y controles de exportacion de ambos
  roles: progreso, pulsaciones repetidas, error, recuperacion y salida de pantalla.
- CP031 recibido posteriormente contempla reportes individuales e institucionales.
- No se obtuvo log del cierre nativo: no habia un Android conectado. El cierre
  reportado debe revalidarse en el dispositivo de QA antes de cerrar la incidencia.
- Revalidacion: instalar una APK generada con los cambios locales, entrar como
  Director y exportar desde el menu principal con un historial amplio. Verificar
  que la app siga abierta, el PDF se abra y conserve todas las evaluaciones.
  Repetir desde el menu docente y el perfil individual del estudiante.

## QA0002533 - Resumen institucional del director (HU0032 / CP032)

- Al ingresar como Director, la pantalla de reportes se identifica como
  "Resumen institucional" y muestra el bloque institucional antes del historial
  y de sus filtros. CP032 permite el modulo de reportes: no se necesita crear
  una pantalla separada ni anular HU0032/CP032.
- Decision de la usuaria: contar todos los registros del alcance autorizado,
  distinguiendo secciones activas/inactivas y estudiantes activos/inactivos.
- Indicadores: totales de secciones, estudiantes y evaluaciones registradas en
  el servidor; estudiantes con al menos una evaluacion, estudiantes sin
  evaluaciones y cobertura sobre el total de estudiantes registrados.
  Una evaluacion no equivale a completar ambos tipos de prueba. No se incluyen
  las sesiones pendientes en Hive como si fueran totales de toda la institucion.
- El endpoint GET /api/v1/reportes/resumen-institucional solo admite el rol
  DIRECTORA con JWT. Respeta grado_scope e incluye los registros inactivos de
  ese grado; no modifica la visibilidad del historial existente.
- Los conteos se realizan mediante agregados en una sola sentencia SQL para
  conservar un mismo instante. No se descargan padrones completos, PIN ni
  nombres para calcularlos; las evaluaciones repetidas no duplican estudiantes.
- Los filtros del historial no cambian el resumen institucional. Actualizar,
  deslizar para recargar y volver del panel administrativo actualizan los datos.
  El docente y psicologia no consultan ni visualizan este bloque.
- La carga del resumen es independiente del historial. Se informa falta de red
  o errores sin detalles tecnicos y se permite reintentar. Un error no se muestra
  como una institucion vacia; los datos anteriores se conservan con aviso de
  posible desactualizacion, excepto cuando se pierde autenticacion o permiso.
- Cambiar de cuenta o alcance limpia los datos y descarta respuestas anteriores;
  una exportacion pendiente tampoco debe abrir datos de la cuenta anterior.
- Pruebas locales con SQLite aislado y respuestas HTTP simuladas: conteos,
  estados, alcance, roles, datos vacios/incompletos, cobertura, independencia
  de filtros, recuperacion, cambio de cuenta y regresiones PDF/conexion.
- Validacion local completada: 13 pruebas backend y 70 pruebas Flutter pasan;
  compileall app y flutter analyze sin errores. Los PDF de regresion conservan
  todas las filas, totales, numeracion y lenguaje educativo.
- Revalidar CP032 con un backend actualizado y una APK que incluya los cambios:
  autenticar al director, comparar los totales con registros conocidos,
  revisar activos/inactivos y cobertura, filtrar el historial y comprobar que
  los totales institucionales no cambian. Repetir con docente sin este bloque.
- Se agrego un endpoint nuevo: el backend que utilice la APK debe incluirlo.
  No se cambio la URL Railway predeterminada ni se desplego, hizo commit/push,
  genero APK o modifico datos reales como parte de esta incidencia.

## QA0002650 - Catalogo de observaciones (HU0035 / CP035)

- El formulario "Registrar observacion" utiliza las cinco categorias de HU0035:
  Refuerzo pedagógico, Reevaluación, Coordinación con familia,
  Seguimiento general y Otro. Se mantiene la seleccion multiple existente.
- Se exige al menos una categoria valida antes de enviar el formulario.
  POST rechaza categorias ausentes, vacias o ajenas al catalogo con HTTP 422,
  sin guardar. PATCH valida el reemplazo si se envia; omitir categorias
  conserva las existentes, mientras null o una lista vacia se rechazan.
- Las observaciones antiguas conservan texto y categorias en el historial:
  no se migran ni se convierten automaticamente. Al crear una nueva observacion
  a partir de una anterior, solo se preseleccionan categorias vigentes y se
  informa si habia categorias antiguas.
- Categoria y estado son campos distintos. Se conservan Abierto, Reforzamiento,
  Derivacion sugerida y Cerrado, sin cambiar automaticamente el estado segun
  la categoria. Se mantienen las reglas de texto obligatorio para riesgo ROJO,
  evaluacion vencida, derivacion sugerida o cierre.
- La fecha y el responsable los asigna el backend usando la sesion autenticada.
  Los permisos por seccion se conservan. Se informa un fallo de guardado sin
  detalles tecnicos y sin perder texto, categoria ni estado. Mientras se guarda
  se bloquean los controles y el cierre para evitar solicitudes simultaneas.
- CP035 debe ejecutarse con un estudiante con historial de evaluacion y con
  permiso para el docente. Abrir el formulario con un estudiante sin evaluaciones
  no acredita esa precondicion; el sistema conserva ese uso como caso separado.
  No se agrega una prohibicion nueva de registrar observaciones sin evaluaciones.
- Validacion local: 13 pruebas backend con SQLite aislado, incluida persistencia
  al volver a consultar con una nueva sesion; 22 pruebas del formulario y flujo
  de seguimiento, y 47 regresiones de reportes, resumen institucional y PDF.
  Compileall app y flutter analyze pasan. No se usaron datos del servidor.

### Pasos precisados para revalidar CP035

1. Ingresar como docente y abrir Seguimiento. Ubicar un estudiante autorizado
   que tenga al menos una evaluacion registrada.
2. Si se abre "Ver historial", pulsar "Cerrar". En la tarjeta del estudiante,
   pulsar "Registrar observacion"; el historial no es el formulario.
3. Seleccionar categoria "Refuerzo pedagógico", estado "Reforzamiento" y
   escribir "Reforzar lectura de sílabas.".
4. Guardar y comprobar la confirmacion. Abrir "Ver historial" y verificar texto,
   categoria, estado, fecha y responsable correspondientes al docente autenticado.
5. Salir de Seguimiento, volver a entrar y consultar otra vez el historial para
   comprobar la persistencia.
6. Caso negativo HU0035-2 separado: dejar todas las categorias sin seleccionar
   y guardar. Debe solicitar al menos una categoria valida, conservar el
   formulario y no crear una observacion.

- No es necesario anular HU0035 ni CP035. Estos pasos precisan navegacion,
  estado y precondicion; no se han editado los documentos originales adjuntos.
- Cambios exclusivamente locales. Para revalidar en Android se necesita una
  APK con el nuevo formulario y un backend con el contrato actualizado.
  No se despliega Railway, modifica datos reales, genera APK ni hace commit/push
  como parte de esta correccion.

## QA0002651 - Selector de Modo aula y permisos (HU0037 / CP037)

- El caso del docente asignado a 3 E que puede seleccionar 3 D corresponde
  al mismo defecto de listado de secciones tratado en QA0002524 (HU0006/CP006).
  Se conserva la correccion local existente; no se amplian permisos ni se
  agregan filtros por nombre de seccion en Flutter.
- GET /api/v1/secciones obtiene con JWT las secciones activas asignadas al
  usuario MAESTRO. Modo aula y nuevo estudiante utilizan ese listado, limpian
  selecciones anteriores y no recuperan secciones de otra cuenta.
- Tener una seccion asignada no implica tener una jornada activa. Para 3 E
  autorizada sin jornada, la consulta devuelve HTTP 404 con "No hay jornada
  activa para esta sección.". El docente puede activar la jornada en 3 E.
- La consulta o activacion directa de 3 D no asignada devuelve HTTP 403,
  incluso si hay una jornada activa en esa seccion. No debe mostrar sus datos
  ni modificarla; ocultar la opcion en Flutter no reemplaza esta validacion.
- Se agrega regresion explicita con 3 E asignada y 3 D ajena: listado por
  asignacion, ausencia de jornada propia, rechazo de acceso ajeno, activacion
  autorizada y preservacion de la jornada ajena, usando datos ficticios locales.
- Validacion local: pasan 20 pruebas backend de secciones/jornadas y 20 pruebas
  Flutter del alcance docente y modo aula. Compileall app y flutter analyze
  sin errores. Para esta incidencia solo se agregaron pruebas y documentacion:
  no fue necesario modificar de nuevo el codigo productivo corregido en QA0002524.
- CP037 debe incluir esa asignacion conocida, comprobar que el selector no
  ofrece 3 D y separar la comprobacion de jornada de la comprobacion de permisos.
  HU0037-2 debe probar la denegacion directa del recurso ajeno, no habilitarlo
  para evitar el mensaje. No se anulan HU0037, CP037 ni CP006.
- Esta revision cubre el escenario reportado y su relacion con QA0002524;
  no acredita por si sola todas las funciones y reportes de los otros roles
  mencionados en CP037.
- Revalidar con backend y APK que incluyan QA0002524, iniciar una sesion docente
  nueva o actualizar el panel, comprobar solo 3 E y verificar la jornada.
  Un "No hay jornada activa" en 3 E es esperado si aun no fue activada.
- No se verifico la version instalada por QA ni se consultaron asignaciones
  reales en Railway. No se desplego, modifico datos remotos, genero APK ni
  hizo commit/push; la correccion continua exclusivamente local.

## QA0002652 - Formulario funcional faltante (HU0044 / CP044)

- CP044 no se pudo ejecutar por falta del formulario, enlace e instrucciones.
  La matriz tecnica y el reporte de validacion automatica existentes no
  sustituyen la percepcion del docente/director sobre el uso de Disly.
- La usuaria eligio preparar el cuestionario e instrucciones para publicarlo
  en Google Forms, no incorporarlo a Flutter ni persistirlo en Railway.
- Plantilla: `docs/plantillas/formulario_validacion_funcional_hu0044.md`.
  Incluye titulo y descripcion, datos basicos mediante codigos, confirmacion
  de participacion adulta, diez afirmaciones de funcionalidad/claridad/utilidad/
  navegacion y dos comentarios opcionales. No pide datos de estudiantes,
  nombres, correos, credenciales ni informacion de salud.
- Escala de acuerdo 1-5 mas "No lo utilice / No aplica"; no se exige una
  opinion favorable para aprobar CP044, ni se presenta el instrumento como
  escala estandarizada o evidencia de eficacia del modelo.
- La guia incluye publicacion, enlace para encuestados, acceso sin cuenta
  comprobado en ventana privada, hoja restringida, resumen publico desactivado
  y comprobacion del registro exacto tras enviar y volver a consultar.
- Se mantiene HU0044/CP044; completar enlace, datos y postcondicion, sin editar
  los originales adjuntos. Los envios QA ficticios no son resultados del piloto.
- Pendiente: crear y publicar en la cuenta responsable, entregar enlace real
  e instrucciones y ejecutar CP044 con evidencia. No hay formulario operativo
  ni persistencia remota comprobada por haber creado esta plantilla.
- Solo documentacion local: no cambios de app/backend, publicacion externa,
  despliegue Railway, datos reales, APK, commit ni push.

## QA0002653 - Login institucional sin conexion (HU0001 / CP047)

- Causa: AuthService.login devolvia "Error iniciando sesion: $error" y la
  pantalla mostraba ese resultado, exponiendo excepciones y la URL del servidor.
- AuthService.login ahora reutiliza runNetworkRequest y los mensajes seguros
  de QA0002531. Sin interfaces de red no envia la peticion de credenciales.
  Si se pierde la red durante el envio, tambien informa la desconexion.
- Mensaje sin red: "Sin conexión a Internet. Verifique su conexión y vuelva a
  intentarlo.". No muestra ClientException, SocketException, Failed host lookup,
  direcciones del servidor ni cuerpos de respuesta.
- Un fallo DNS con Wi-Fi disponible no prueba ausencia de Internet: muestra el
  mensaje general de fallo de conexion. Un timeout con red o HTTP 5xx informa
  indisponibilidad temporal del servicio. Si falla la comprobacion de red,
  se comunica explicitamente sin enviar credenciales.
- HTTP 401/403 conserva "Credenciales inválidas.", sin revelar que dato fallo.
  Las respuestas inesperadas o sin token no producen un login exitoso.
  Los fallos se registran con el helper seguro, sin imprimir excepciones completas,
  cuerpos, direcciones del servicio ni credenciales.
- En el recorrido CP047 no se guarda usuario/token ni se abre el panel.
  El formulario mantiene los datos introducidos, habilita Ingresar y permite
  volver a intentarlo con las mismas credenciales cuando se recupera la red.
- No se modifican la recuperacion de sesiones ya guardadas ni el acceso offline
  por PIN del estudiante. CP047 parte de haber cerrado la sesion institucional.
- Archivos: mobile/lib/core/services/auth_service.dart;
  mobile/test/staff_login_connection_test.dart; este documento.
- Validacion local: 31 pruebas nuevas del servicio y pantalla y 43 regresiones
  de conexion/reportes/sincronizacion/PIN offline, 74 en total, pasan.
  flutter analyze sin observaciones. HTTP y conectividad simulados; Hive usa
  carpetas temporales de prueba, sin autenticar cuentas reales ni llamar Railway.
- Revalidacion QA: cerrar sesion, abrir Personal educativo, desactivar Wi-Fi
  y datos, ingresar credenciales autorizadas y pulsar Ingresar. Comprobar el
  mensaje exacto, ausencia de datos tecnicos y que no se abre el panel.
  Recuperar Internet, pulsar Ingresar otra vez y comprobar acceso segun el rol.
- HU0001 y CP047 mantienen su regla; precisar el mensaje y el reintento.
  En la imagen de la HU, corregir la numeracion del tercer criterio de HU0000-3
  a HU0001-3. No se editaron los originales adjuntos.
- Correccion solo local: pendiente instalar una APK actualizada y repetir CP047
  en dispositivo. No requiere cambios de backend. No se desplego Railway,
  genero APK ni hizo commit/push.

## QA0002654 - Registro inactivo sin consentimiento (HU0007 / CP050)

- Decision expresa de la usuaria: permitir guardar un estudiante inactivo
  sin consentimiento y bloquear su activacion y participacion en evaluaciones
  hasta registrar consentimiento informado firmado y su fecha.
- Causa: la validacion de creacion rechazaba consentimiento_firmado=false sin
  consultar activo, aunque el formulario enviaba activo=false. La importacion
  ya admitia registros inactivos sin consentimiento.
- Alta manual: activo=false y consentimiento=false se guarda, sin fecha de
  consentimiento ni PIN. No es necesario borrar previamente la fecha sugerida:
  no se envia desde el formulario y el backend la normaliza a null.
- La fecha queda deshabilitada sin consentimiento. Intentar guardar activo=true
  y consentimiento=false muestra dentro del formulario:
  "Para activar al estudiante se requiere consentimiento informado firmado.".
  No se envia la peticion, no se cierra el formulario ni se pierden sus datos.
  La misma combinacion enviada directamente a POST/PATCH devuelve HTTP 400.
- Editar datos de un registro inactivo sigue permitido. Al registrar despues
  consentimiento y fecha, se genera su PIN; no se activa automaticamente si
  continua marcado inactivo. Al activarlo posteriormente se conserva ese PIN.
  Se mantienen los requisitos de seccion asignada y jornada del modo aula.
- Al retirar consentimiento en una edicion se eliminan fecha y PIN del registro.
  Si no se solicita un estado explicito, se conserva la desactivacion automatica
  anterior; pedir activo=true sin consentimiento se rechaza sin guardar cambios.
- Regenerar PIN sin consentimiento se bloquea en API y el boton no se habilita
  en Flutter. Los registros no habilitados quedan fuera del padron descargable
  y no se recuperan por PIN, incluso si un registro antiguo aun tuviera PIN.
  No se modifican la sincronizacion de evaluaciones previas ni las reglas
  adaptativas. Un equipo desconectado no recibe cambios hasta actualizar su padron.
- AdminService conserva los mensajes de rechazo mediante RequestFailure para
  no anteponer "Exception:" al mensaje mostrado.
- Archivos: backend/app/api/estudiantes.py; backend/tests/test_estudiantes.py;
  mobile/lib/core/services/admin_service.dart;
  mobile/lib/features/admin/screens/admin_panel_screen.dart;
  mobile/test/student_form_validation_test.dart; este documento.
- Validacion local: 41 pruebas backend (21 estudiantes y 20 secciones), 58 Flutter
  (28 formulario/servicio y 30 alcance docente/PIN offline), compileall app y
  flutter analyze correctos. Los datos son ficticios, con SQLite y Hive temporales.
- Precisar HU0007-2: se permite el registro administrativo inactivo pendiente
  de consentimiento; no implica habilitacion para evaluacion.
- CP050: usar una seccion activa asignada, por ejemplo 3 E, y datos ficticios
  validos de un estudiante de 8 o 9 anos. Guardar con Consentimiento firmado=No
  y Activo=No; comprobar persistencia al actualizar el listado, estado Inactivo,
  sin PIN y fuera del padron offline. Luego editar, marcar Activo=Si manteniendo
  Consentimiento=No e intentar guardar: debe informar el requisito, conservar
  el formulario y mantener el registro persistido inactivo. Esa es la
  postcondicion del caso negativo. Probar consentimiento y fecha validos como
  recorrido positivo separado de HU0007-1/CP007.
- No anular HU0007 ni CP050; completar explicitamente el estado Activo y la
  diferencia entre guardar y habilitar. No se editaron los originales adjuntos.
- Correccion exclusivamente local. Pendiente revalidar con backend y APK
  actualizados; no se desplego Railway, migro datos reales, genero APK ni hizo
  commit/push.

## QA0002656 - Recuperar evaluaciones incompletas (HU0015 / CP061)

- Decision expresa de la usuaria: conservar el avance y ofrecer Continuar en
  lectura y conciencia fonologica, para el mismo estudiante y tipo de prueba,
  sin crear otra sesion al volver a ingresar.
- Causa: se guardaban los detalles resueltos en Hive, pero cada apertura creaba
  una sesion y seleccion aleatoria nuevas. El orden, las opciones, el indice,
  los errores y el tiempo del item pendiente solo existian en memoria.
- Las sesiones nuevas guardan un plan versionado con los diez estimulos y todas
  sus opciones en el orden elegido originalmente, junto con las respuestas
  completadas y el estado del siguiente item. Se mantienen el nivel, la
  distribucion y la version del banco aplicados al comenzar.
- La respuesta y el avance se guardan juntos en el registro de sesion y se
  confirma su escritura antes de avanzar en pantalla. El registro es la fuente
  de recuperacion; los detalles usan claves por sesion/indice y se reparan desde
  esa fuente si hubo una interrupcion entre ambas escrituras, sin duplicarlos.
- El selector ofrece Continuar lectura / Continuar fonologia y muestra
  "Respuestas guardadas: X de 10. Faltan Y.". Al reabrir restaura exactamente el
  item pendiente, sus opciones, los intentos previos y el tiempo activo guardado.
  No ofrece el progreso de otro estudiante ni mezcla los dos tipos de prueba.
- El reloj se detiene cuando la app deja de estar activa y no agrega el tiempo
  que permanecio cerrada. Los errores se guardan en cada intento; el tiempo del
  item pendiente se actualiza periodicamente y al pausar/salir. Un cierre
  abrupto puede perder el tiempo posterior al ultimo checkpoint persistido:
  no se promete precision absoluta del cronometro ante la muerte del proceso.
- No se cambia la regla adaptativa, la cantidad de diez items ni el calculo de
  aciertos al primer intento. Se mantienen "Intenta otra vez" en lectura y
  "Esa no es la silaba inicial. Intenta otra vez." en fonologia. Se bloquean
  interacciones nuevas mientras se confirma el guardado.
- No se permite finalizar con 3/10 u 8/10 ni reducir el total para simular una
  prueba completa. Las sesiones PENDING siguen fuera de la sincronizacion y
  no generan una nueva estimacion de riesgo. Si ya se guardo la ultima respuesta
  pero se cerro antes de finalizar la sesion, la reapertura completa ese cierre
  sin generar otra sesion ni duplicar respuestas.
- La sincronizacion conserva su contrato: el plan, las respuestas canonicas y
  el checkpoint permanecen locales, no se envian al backend. No se modifico el
  endpoint de sincronizacion ni se requiere un despliegue Railway por este cambio.
- Si falla la lectura/validacion del progreso se muestra un aviso seguro y no
  se empieza otra prueba silenciosamente. Los fallos de guardado se informan,
  no se presenta la prueba como finalizada y se permite reintentar.
- Compatibilidad: las sesiones iniciadas antes de esta correccion no guardaban
  el orden original. Se conservan sus respuestas sin inventar ese orden ni
  presentarlas como recuperables. Se informa la limitacion y se pide confirmar
  antes de empezar otra prueba. La recuperacion completa corresponde a sesiones
  iniciadas con esta version y guardadas en el mismo dispositivo.
- Archivos: mobile/lib/core/models/local_assessment_progress.dart;
  local_evaluation_detail.dart, stimulus.dart y phonology_stimulus.dart en
  esa misma carpeta; mobile/lib/core/repositories/local_evaluation_storage.dart;
  mobile/lib/core/services/assessment_progress_tracker.dart;
  mobile/lib/features/home/screens/test_selection_screen.dart;
  mobile/lib/features/lectura/screens/lectura_assessment_screen.dart;
  mobile/lib/features/fonologia/screens/fonologia_assessment_screen.dart;
  mobile/test/assessment_resume_test.dart; este documento.
- Validacion local: pasan 22 pruebas nuevas de almacenamiento/pantallas y 17
  regresiones de sincronizacion y acceso offline, 39 en total. flutter analyze
  sin observaciones. Se ejecutan toques y arrastres reales, cierre/reapertura de
  Hive, planes nuevos con assets reales, recuperacion 3/10 y 8/10, intentos
  conservados, finalizacion unica en 10/10 y compatibilidad con sesiones antiguas.
  Solo se utilizan Hive temporal y conectividad/HTTP simulados.
- CP061: comenzar una lectura nueva con un estudiante habilitado, responder
  tres items, cerrar y reabrir la app e ingresar con el mismo estudiante en el
  mismo dispositivo. Comprobar Continuar lectura y 3/10; continuar en el cuarto
  item original, sin otra sesion ni respuestas duplicadas. Repetir con 8/10 y
  comprobar que faltan dos respuestas y no hay resultado definitivo. Completar
  las diez y comprobar el cierre normal y la sincronizacion cuando corresponda.
  Probar conciencia fonologica con el mismo recorrido como caso paralelo.
- Mantener HU0015/CP061 y precisar cierre/reapertura, recuperacion del avance,
  postcondicion y el caso de fonologia; no se editaron los originales adjuntos.
  La funcionalidad es de tamizaje educativo y no constituye diagnostico clinico.
- Correccion exclusivamente local. Pendiente instalar una APK actualizada y
  revalidar cierre real del proceso en Android; las pruebas locales no sustituyen
  esa evidencia. No se genero APK, desplego Railway, altero datos reales ni hizo
  commit/push.

## Preparacion local de publicacion - Sincronizacion y configuracion

- Decisiones expresas de la usuaria: el estudiante sigue trabajando offline
  sin credenciales institucionales; enviar evaluaciones requiere una sesion
  vigente de docente o direccion. Si caduca, las respuestas permanecen pendientes.
  Si el estudiante esta inactivo o sin consentimiento al enviar, conservar el
  pendiente y bloquear su envio hasta la revision docente; no eliminar respuestas.
- POST /api/v1/evaluaciones/sync requiere Bearer y usuario activo con rol
  MAESTRO o DIRECTORA. Un docente solo puede enviar estudiantes de sus secciones
  asignadas. Para nuevas evaluaciones se comprueban estudiante activo,
  consentimiento firmado con fecha y seccion activa.
- Solo se reciben sesiones COMPLETED_PENDING_SYNC de diez items con estudiante
  identificado, fechas coherentes y diez respuestas distintas. Se validan tipo de
  prueba, tiempos y errores no negativos, aciertos al primer intento, promedio y
  distribucion declarada contra el detalle. El promedio conserva el redondeo
  positivo de Dart. Las sesiones incompletas continuan exclusivamente locales.
- La identidad local se persiste en evaluaciones.local_session_id con indice
  unico; sync_payload_hash identifica el contenido validado. Reenviar la misma
  sesion y contenido devuelve la evaluacion original, sin repetir detalles,
  inferencia ni actualizacion adaptativa. Reordenar los detalles no cambia la
  identidad; reenviar contenido diferente con el mismo identificador devuelve 409.
- Evaluacion, prediccion, detalles y nivel se guardan en una sola transaccion
  por lote. Si alguna sesion es rechazada, no se guarda parcialmente el lote.
  Se bloquean los estudiantes en orden estable y se reintenta una colision del
  identificador unico; no se modifican las reglas adaptativas.
- Una evaluacion ya recibida legitimamente puede confirmar su recepcion aunque
  despues se haya desactivado al estudiante. Exige el mismo contenido y alcance
  autorizado, y no crea datos nuevos. No permite enviar una evaluacion nueva
  para un estudiante que continua inhabilitado.
- Flutter envia el token institucional; ante 401 conserva las evaluaciones y
  solicita nuevo ingreso. Un 401 tardio no borra una sesion renovada con otro
  token. Al ingresar o continuar como docente/directora se reintenta el envio
  sin bloquear la navegacion ni esperar un nuevo cambio de conectividad.
- Antes de modificar Hive se valida todo el acuse: estado, conteos enteros,
  identificadores solicitados y unicos, evaluacion del servidor, cantidad de
  detalles confirmados y niveles. HTTP 200 con {}, lista vacia o acuses
  inconsistentes no marca pendientes como enviados. Solo se marcan sesiones
  confirmadas; un acuse parcial conserva el resto e informa que falta enviarlo.
  Una confirmacion de reenvio puede tener cero inserciones y diez confirmaciones.
  Se fuerza flush de sesiones y detalles al registrar el envio.
- No cambia la recuperacion local de QA0002656: plan, opciones y checkpoint no
  se envian al servidor. Tampoco se cambian mensajes de reintento ni reglas de
  tamizaje educativo; la estimacion de riesgo no constituye diagnostico clinico.

### Configuracion y compatibilidad para Railway

- El arranque exige JWT_SECRET_KEY, sin clave predeterminada. HS256 requiere al
  menos 32 bytes; HS384, 48; HS512, 64. Usar una clave aleatoria privada, no un
  texto predecible de longitud suficiente. JWT_SECRET no reemplaza esta variable.
  ACCESS_TOKEN_EXPIRE_MINUTES conserva 480 minutos por defecto y debe ser
  entero positivo. Se verifican firma, expiracion y claims obligatorios del JWT.
- ENABLE_DEMO_SEED debe estar ausente o ser false en produccion: seed-demo
  devuelve 404 por defecto, incluso en una base vacia. Habilitarlo explicitamente
  se reserva a un entorno demo aislado y mantiene la autenticacion del reseed.
  Esto no desactiva automaticamente cuentas demo que ya existan; revisarlas
  antes de usar datos reales.
- Se fijaron las dependencias antes libres (ML, bcrypt, JWT y Excel) a versiones
  instaladas y se eliminaron duplicados de backend/requirements.txt.
- Antes de publicar el nuevo backend sobre una base existente, realizar un
  respaldo autorizado y ejecutar, con la conexion privada del entorno destino:
  `python -m app.db.migrate_sync_sessions`. El modulo esta dentro de la imagen
  Docker y puede configurarse como comando pre-deploy del servicio backend.
  Agrega dos columnas nullable y el indice unico sin borrar ni reconstruir
  evaluaciones. El arranque comprueba columnas e identidad unica; create_all
  no sustituye esta migracion. Una base nueva recibe el esquema al arrancar.
- No se inventan identificadores ni se deduplican retroactivamente registros
  historicos sin identidad local. Un pendiente de una APK antigua que ya se
  hubiese recibido antes de esta migracion necesita revision de correspondencia:
  no se puede prometer deduplicacion contra filas historicas sin identificador.
- Coordinar backend y APK nueva: el endpoint ahora requiere autenticacion y el
  acuse incorpora details_confirmed. Una APK anterior sin Bearer no podra enviar;
  la nueva no aceptara acuses del backend anterior. No desinstalar ni borrar
  datos del dispositivo al actualizar: contiene los pendientes de Hive.
- Verificar privadamente DATABASE_URL y JWT_SECRET_KEY antes del despliegue;
  no imprimirlas, pegarlas en documentacion ni guardarlas en el repositorio.
  Cambiar la clave JWT obliga al personal a volver a ingresar, sin borrar los
  pendientes educativos locales.
- Estado remoto observado en la revision previa: /health respondia 200, pero
  el OpenAPI publicado aun no incluia resumen-institucional. Este trabajo no
  actualiza Railway: falta publicar y comprobar la version efectiva.

### Archivos y comprobacion

- Backend: app/api/evaluaciones.py, app/schemas/evaluation_sync.py,
  app/models/evaluation.py, app/db/session.py, app/db/migrate_sync_sessions.py,
  app/services/jwt_service.py, app/api/auth.py, app/api/admin_demo.py,
  app/main.py y requirements.txt, bajo backend/.
- Mobile: evaluation_sync_service.dart y auto_sync_service.dart en
  mobile/lib/core/services/; local_evaluation_storage.dart en
  mobile/lib/core/repositories/; staff_login_screen.dart en
  mobile/lib/features/auth/screens/.
- Pruebas: backend/tests/test_evaluation_sync.py y
  test_release_configuration.py; mobile/test/sync_connection_test.dart,
  staff_login_connection_test.dart y widget_test.dart. Se corrigieron la
  inicializacion de Hive y los textos obsoletos de la prueba de arranque.
- Regresion local: 92 pruebas backend y 254 Flutter correctas. Incluye
  autorizacion real con JWT de prueba, alcance docente, consentimiento,
  validacion de diez items, reenvios, rollback del lote, fallo de base,
  colision simulada, acuses invalidos, persistencia al reabrir Hive y reingreso
  desde el formulario con envio automatico. Solo SQLite/Hive temporales,
  identidades ficticias y HTTP/conectividad simulados.
- Para repetir: en backend ejecutar compileall app, pip check y
  `python -m unittest discover -s tests -p "test_*.py"` con DATABASE_URL
  de prueba y una clave JWT de prueba privada; en mobile ejecutar
  `flutter analyze` y `flutter test`. No apuntar las pruebas a PostgreSQL real.
- QA manual posterior con datos ficticios: completar diez respuestas offline,
  comprobar que no se envian sin sesion institucional, ingresar como docente
  autorizado y verificar confirmacion sin perder respuestas. Repetir con
  estudiante inhabilitado: debe permanecer pendiente hasta regularizar su
  estado/consentimiento y volver a enviar. Verificar APK y backend nuevos
  juntos, conservando el almacenamiento al actualizar.
- Pendiente remoto: ejecutar y verificar la migracion sobre PostgreSQL con
  respaldo y autorizacion, comprobar variables privadas, validar despliegue y
  reenvios concurrentes reales. No se valido PostgreSQL/Docker en ejecucion ni
  la APK en Android. Sin commit, push, despliegue, APK ni cambios de datos reales.
