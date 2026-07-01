# AGENTS.md - Disly

## Idioma y estilo

Responde siempre en español. Se practico, paso a paso y preciso. Antes de modificar codigo, resume brevemente el plan.

## Proyecto

Disly es una app movil offline-first para tamizaje educativo de riesgo de dislexia en estudiantes de tercer grado. No es una herramienta de diagnostico clinico.

Stack:
- Flutter / Dart mobile
- Hive local storage
- FastAPI / Python backend
- PostgreSQL
- Railway
- Random Forest / XGBoost ML

## Lenguaje obligatorio

Usar:
- tamizaje educativo
- estimacion de riesgo
- seguimiento pedagogico
- semaforo de riesgo
- no constituye diagnostico clinico

Evitar:
- diagnosticar dislexia
- validacion clinica
- prediccion clinica definitiva

## Rutas principales

Backend:
- backend/app/main.py
- backend/app/api/
- backend/app/models/
- backend/app/schemas/
- backend/app/services/
- scripts/

Mobile:
- mobile/lib/core/
- mobile/lib/features/
- mobile/lib/features/auth/
- mobile/lib/features/reportes/
- mobile/lib/features/admin/
- mobile/lib/features/seguimiento/

Documentacion:
- docs/sprints/
- docs/evidencias/
- docs/plantillas/
- docs/codex/PROJECT_CONTEXT.md

## Comandos de verificacion

Backend:
cd C:\Users\Greic\tesis-dislexia-app\backend
python -m compileall app

Mobile:
cd C:\Users\Greic\tesis-dislexia-app\mobile
flutter analyze

APK release:
cd C:\Users\Greic\tesis-dislexia-app\mobile
flutter clean
flutter pub get
flutter analyze
flutter build apk --release

## Git

No hacer push a main salvo instruccion explicita.

No agregar:
- dist/
- *.apk
- *.aab
- .env
- secretos
- backups temporales

Usar commits claros:
- feat:
- fix:
- docs:
- chore:

Antes de commit:
- Revisar git status --short
- Agregar archivos de forma selectiva
- No usar git add . salvo confirmacion explicita

## Railway

No desplegar Railway sin confirmacion explicita del usuario.

Variables sensibles como DATABASE_URL y JWT_SECRET no deben imprimirse ni guardarse en archivos del repo.

## Roles esperados

Actuar segun la tarea como:
- Arquitecto de software
- Backend FastAPI
- Frontend Flutter
- QA tester
- Scrum master
- Redactor de documentacion de tesis

## Definicion de terminado

Una tarea esta terminada cuando:
- compila backend si aplica
- flutter analyze pasa si aplica
- se describen archivos modificados
- se indica como probar
- no se suben artefactos pesados ni secretos
