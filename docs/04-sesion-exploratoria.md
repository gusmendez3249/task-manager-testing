# 3. Pruebas exploratorias con charter

## Sesión 1 — API (ejecutada)

- **Charter:** "Explorar la creación y edición de tareas en la API para encontrar entradas que se guarden mal o generen duplicados."
- **Límite de tiempo:** 20 min.
- **Entorno:** API 1.0.0 en modo memoria (`npm run start:memory`, puerto 3123), Windows 11, Node 24, curl. Fecha: 2026-11-04.
- **Datos:** cuenta sintética `tester-a@example.test`.

| Tiempo | Acción o condición | Observación | Seguimiento |
|--------|--------------------|-------------|-------------|
| 00:00 | `GET /health` | `200 OK` | — |
| 00:01 | Registro de tester A | `201`, se reciben tokens | No pegar tokens en notas ✅ |
| 00:03 | Título de 121 caracteres | `400 Enter a valid title.` | Coincide con la tabla de límites |
| 00:05 | Título con emoji `🎉 Fiesta` desde Git Bash | Se guardó como `?? Fiesta` | **Pregunta:** ¿bug de la API? Se repitió con `fetch` de Node enviando UTF-8 → se guarda `🎉 Fiesta ñ` correctamente. Era la codificación de la consola de Windows, **no** un bug. |
| 00:08 | 5 `POST` simultáneos con el mismo título (simula doble toque) | Los 5 devuelven `201` → 5 tareas *Doble tap* | La API no es idempotente. Riesgo de duplicados desde la app → TC-05: la app bloquea el botón mientras guarda. |
| 00:11 | `PATCH /tasks/abc` sin cuerpo | `404 Task not found.` | Correcto: id mal formado no revela nada. |
| 00:12 | Título con salto de línea `line1\nline2` | `201`, se guarda tal cual | **Pregunta para producto:** ¿los títulos deben ser de una línea? No hay criterio; se deja anotado. |
| 00:14 | Título solo `​` (espacio de ancho cero) | `201`, tarea "invisible" | **Bug → BUG-002** (corregido). |
| 00:16 | Cuerpo `text/plain` | `400 Enter a valid title.` | Correcto. |
| 00:17 | `PATCH` con `{"title": null}` | `400 Enter a valid title.` | Correcto. |

**Qué me sorprendió:** que `trim()` no quite U+200B, y que la consola de Windows alterara el emoji (casi lo reporto como bug: siempre confirmar con otra herramienta antes de reportar).

**Resultado:** 1 bug (BUG-002), 1 riesgo convertido en prueba (TC-05), 1 pregunta abierta (títulos multilínea), 1 falso positivo descartado (emoji).

---

## Sesión 2 — App móvil (plantilla para ejecutar en dispositivo)

- **Charter:** "Explorar la edición de tareas para encontrar problemas de pérdida de datos."
- **Límite:** 15 min. Probar título largo, título vacío, toques repetidos rápidos y conectividad interrumpida (modo avión).

| Tiempo | Acción o condición | Observación | Seguimiento |
|--------|--------------------|-------------|-------------|
| 00:00 | Iniciar sesión como tester A | Lista cargada | Revisar estado vacío |
| 00:05 | Editar un título y activar modo avión antes de guardar | *(esperado: error en el diálogo, texto conservado — TC-06)* | Verificar que el título viejo sigue en la lista |
| … | | | |

> Las fallas reproducibles se convierten en casos de prueba (`02-casos-de-prueba.md`) y reportes (`03-reporte-de-bug.md`).
