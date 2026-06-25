# Guion de demostración del prototipo

## Objetivo

Demostrar el funcionamiento del prototipo móvil offline-first para el tamizaje temprano de riesgo de dislexia en estudiantes de tercer grado de primaria.

El sistema permite:

- Ingreso de estudiante mediante PIN.
- Preparación de modo offline.
- Ejecución de prueba de lectura.
- Ejecución de prueba de conciencia fonológica.
- Registro de telemetría.
- Sincronización con backend.
- Visualización de reportes.
- Exportación CSV y PDF.
- Consulta de perfil individual.
- Administración de estudiantes, secciones, usuarios y asignaciones.

## Preparación previa

Desde la raíz del proyecto:

    docker compose -f infra\docker-compose.yml up -d

Verificar backend:

    Invoke-RestMethod http://127.0.0.1:8000/health

Ejecutar aplicación:

    cd mobile
    flutter run

## Credenciales demo

| Rol | Correo | Contraseña |
|---|---|---|
| Directora | directora@demo.com | 123456 |
| Maestra | maestra3a@demo.com | 123456 |

## PINs demo

| Estudiante | PIN |
|---|---|
| Ana Torres Flores | 1234 |
| Luis Ramirez Soto | 5678 |
| Camila Vargas Rojas | 9012 |

## Flujo sugerido

1. Mostrar pantalla inicial con PIN.
2. Explicar que el sistema es de tamizaje educativo, no diagnóstico clínico.
3. Preparar modo offline con credenciales académicas.
4. Ingresar con PIN de estudiante.
5. Ejecutar prueba de lectura.
6. Ejecutar prueba de conciencia fonológica.
7. Mostrar resultado con porcentaje y semáforo.
8. Ingresar al portal académico.
9. Mostrar reportes, filtros, CSV y PDF.
10. Abrir perfil individual del estudiante.
11. Exportar PDF individual.
12. Abrir panel administrativo con cuenta directora.

## Mensaje de cierre sugerido

El prototipo demuestra una arquitectura offline-first para tamizaje temprano de riesgo de dislexia, con captura de telemetría, sincronización, control de acceso por roles, reportes académicos y validación preliminar mediante Random Forest y XGBoost. El sistema no reemplaza una evaluación clínica, sino que orienta la detección temprana y el seguimiento educativo.
