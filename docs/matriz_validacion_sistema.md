# Matriz de validación funcional del sistema

Este documento registra las pruebas funcionales finales del prototipo de tamizaje temprano de riesgo de dislexia.

## 1. Alcance

La validación cubre los principales componentes del sistema:

- Aplicación móvil Flutter.
- Modo offline-first con Hive.
- Backend FastAPI.
- Base de datos PostgreSQL.
- Autenticación JWT y roles.
- Sincronización de evaluaciones.
- Reportes académicos.
- Exportación CSV/PDF.
- Dataset de machine learning.
- Validación preliminar de modelos ML.
- Panel administrativo.

## 2. Criterios generales de aceptación

| Criterio | Descripción |
|---|---|
| Disponibilidad backend | El endpoint `/health` responde correctamente. |
| Seguridad | Los endpoints sensibles requieren JWT. |
| Roles | Maestra, psicóloga y directora acceden solo a información permitida. |
| Offline-first | El estudiante puede rendir evaluación sin internet si existe caché local. |
| Sincronización | Las sesiones locales se sincronizan cuando el backend está disponible. |
| Reportes | El personal autorizado puede consultar reportes y exportar CSV/PDF. |
| ML | El sistema puede exportar dataset, validar modelo y generar métricas. |
| Evidencia | Existen documentos y capturas sugeridas para sustentar el funcionamiento. |

## 3. Matriz de pruebas funcionales

| ID | Módulo | Caso de prueba | Resultado esperado | Estado |
|---|---|---|---|---|
| PF-001 | Backend | Consultar `/health` | El backend responde `status: ok`. | Pendiente |
| PF-002 | Backend | Ejecutar smoke test backend | Todos los endpoints críticos responden OK. | Pendiente |
| PF-003 | Autenticación | Login con `directora@demo.com` | Devuelve JWT válido y datos de usuario. | Pendiente |
| PF-004 | Autenticación | Consultar `/api/v1/auth/me` con JWT | Devuelve usuario autenticado. | Pendiente |
| PF-005 | Seguridad | Consultar endpoint protegido sin JWT | Devuelve 401 Unauthorized. | Pendiente |
| PF-006 | Roles | Maestra accede a reportes de su sección | Solo visualiza datos autorizados. | Pendiente |
| PF-007 | Roles | Directora accede a panel administrativo | Visualiza opciones administrativas. | Pendiente |
| PF-008 | Estudiantes | Login por PIN válido | El estudiante ingresa a selección de prueba. | Pendiente |
| PF-009 | Estudiantes | Login por PIN inválido | La app muestra mensaje de error. | Pendiente |
| PF-010 | Offline-first | Preparar padrón offline | Descarga estudiantes autorizados a caché local. | Pendiente |
| PF-011 | Offline-first | Ingresar por PIN sin backend | El estudiante ingresa usando caché local. | Pendiente |
| PF-012 | Lectura | Ejecutar prueba de lectura | Registra respuestas, tiempos y errores. | Pendiente |
| PF-013 | Fonología | Ejecutar prueba fonológica | Registra drag/drop, pseudopalabras y tiempos. | Pendiente |
| PF-014 | Sincronización | Crear evaluación offline y reconectar | La evaluación se sincroniza al backend. | Pendiente |
| PF-015 | Riesgo | Finalizar evaluación | Muestra porcentaje de riesgo y semáforo. | Pendiente |
| PF-016 | Reportes | Abrir portal académico | Carga resumen y lista de evaluaciones. | Pendiente |
| PF-017 | Reportes | Filtrar por tipo de prueba | La lista se filtra correctamente. | Pendiente |
| PF-018 | Reportes | Exportar CSV | Se genera archivo CSV protegido por JWT. | Pendiente |
| PF-019 | Reportes | Exportar PDF | Se genera archivo PDF con resumen y tabla. | Pendiente |
| PF-020 | Perfil | Abrir perfil de estudiante | Muestra comparación por tipo de prueba. | Pendiente |
| PF-021 | Admin | Crear estudiante desde panel | El estudiante queda registrado. | Pendiente |
| PF-022 | Admin | Editar estudiante desde panel | Los cambios quedan persistidos. | Pendiente |
| PF-023 | Admin | Crear sección | La sección queda disponible. | Pendiente |
| PF-024 | Admin | Crear usuario académico | El usuario puede iniciar sesión. | Pendiente |
| PF-025 | Admin | Asignar docente a sección | La relación queda registrada. | Pendiente |
| PF-026 | ML | Exportar dataset ML | Se genera `data/processed/ml_dataset.csv`. | Pendiente |
| PF-027 | ML | Ejecutar validación ML | Se generan métricas, matriz e importancia. | Pendiente |
| PF-028 | ML | Generar documento de resultados ML | Se genera `docs/resultados_validacion_ml.md`. | Pendiente |
| PF-029 | Evidencia | Generar evidencia experimental | Se genera `docs/evidencia_dataset_experimental.md`. | Pendiente |
| PF-030 | Flutter | Ejecutar `flutter analyze` | No se reportan errores ni warnings críticos. | Pendiente |

## 4. Evidencias sugeridas

| Evidencia | Archivo sugerido |
|---|---|
| Pantalla PIN | `docs/evidencias/01_pin_login.png` |
| Preparar modo offline | `docs/evidencias/02_preparar_offline.png` |
| Prueba lectura | `docs/evidencias/03_prueba_lectura.png` |
| Prueba fonología | `docs/evidencias/04_prueba_fonologia.png` |
| Resultado semáforo | `docs/evidencias/05_resultado_semaforo.png` |
| Reportes | `docs/evidencias/06_reportes.png` |
| Perfil estudiante | `docs/evidencias/07_perfil_estudiante.png` |
| Panel administrativo | `docs/evidencias/08_panel_admin.png` |
| Exportación PDF | `docs/evidencias/09_reporte_pdf.png` |
| Smoke test backend | `docs/evidencias/13_smoke_backend.png` |
| Validación final automática | `docs/evidencias/validacion_final_YYYYMMDD_HHMMSS.txt` |

## 5. Observación

La validación funcional confirma que el prototipo opera como sistema de apoyo para tamizaje educativo. Los resultados del modelo no constituyen diagnóstico clínico.
