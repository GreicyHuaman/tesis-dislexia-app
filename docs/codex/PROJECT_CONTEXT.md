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
