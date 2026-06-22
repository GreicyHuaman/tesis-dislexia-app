# Guía UX/UI del prototipo

## 1. Objetivo de diseño

La interfaz del prototipo fue diseñada para facilitar el uso en un contexto escolar, considerando dos grupos principales de usuarios:

- Estudiantes de tercer grado de primaria.
- Personal académico: maestra, psicóloga y directora.

## 2. Principios de diseño

| Principio | Aplicación en el prototipo |
|---|---|
| Claridad | Textos breves y botones con acciones directas. |
| Accesibilidad | Botones grandes, formularios simples y contraste visual. |
| Seguridad emocional | Los resultados se muestran como riesgo orientativo, no como diagnóstico. |
| Offline-first | Se informa al usuario cuándo debe preparar el modo offline. |
| Separación de roles | La experiencia del estudiante se mantiene separada del portal académico. |
| Trazabilidad | El personal académico puede consultar reportes, CSV y PDF. |

## 3. Pantalla de ingreso por PIN

La pantalla inicial usa un PIN de 4 dígitos para facilitar el acceso del estudiante. Esta pantalla evita solicitar datos personales al menor durante la evaluación.

También incluye un aviso de que el sistema realiza tamizaje educativo y no diagnóstico clínico.

## 4. Pruebas para estudiantes

Las pruebas utilizan interacciones simples:

- Selección por toque.
- Arrastrar y soltar.
- Retroalimentación visual.
- Ítems breves.

Esto reduce carga cognitiva y permite registrar telemetría sin requerir grabación de voz.

## 5. Portal académico

El portal académico está protegido por credenciales y JWT. Permite al personal autorizado revisar reportes, exportar archivos y consultar perfiles de riesgo.

## 6. Reportes

Los reportes utilizan un enfoque de semáforo:

- VERDE: riesgo bajo estimado.
- AMARILLO: riesgo intermedio estimado.
- ROJO: riesgo alto estimado.

El sistema incluye notas visibles indicando que el resultado no constituye diagnóstico clínico.

## 7. Panel administrativo

El panel administrativo está disponible para la directora y permite gestionar:

- Estudiantes.
- Secciones.
- Usuarios académicos.
- Asignaciones docente-sección.

## 8. Consideraciones para la demo

Durante la demostración se recomienda seguir este flujo:

1. Ingresar a la app.
2. Preparar modo offline.
3. Iniciar evaluación con PIN.
4. Ejecutar prueba de lectura.
5. Ejecutar prueba fonológica.
6. Revisar semáforo.
7. Ingresar como personal académico.
8. Revisar reportes.
9. Exportar CSV/PDF.
10. Abrir panel administrativo.

## 9. Alcance

Las mejoras UX/UI buscan que el prototipo sea más claro, presentable y defendible en una sustentación académica, sin alterar la lógica funcional del sistema.
