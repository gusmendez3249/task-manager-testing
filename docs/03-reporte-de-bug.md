# 2b. Reportes de bug

> Severidad = impacto. Prioridad = urgencia. Ningún reporte incluye tokens, contraseñas reales ni datos personales.

## BUG-001 — Una tarea desaparece después de marcarla como completada (ejercicio de práctica)

| Campo | Contenido |
|-------|-----------|
| **Resumen** | Al marcar una tarea como completada, desaparece de la lista y no hay forma de verla ni desmarcarla. |
| **Entorno** | Emulador Android API 34 (Pixel 6), app `task_manager` 1.0.0+1 (debug), API `task-manager-api` 1.0.0 local con PostgreSQL 17. |
| **Precondiciones** | Cuenta sintética `tester@example.test` con una tarea pendiente *Finish report*. |
| **Pasos para reproducir** | 1. Iniciar sesión. 2. En *My tasks*, tocar la casilla junto a *Finish report*. 3. Observar la lista. 4. Salir y volver a entrar. |
| **Resultado esperado** | La tarea sigue visible, tachada y con el texto *Completed*; persiste tras volver a entrar. |
| **Resultado real** | La tarea desaparece inmediatamente y no vuelve a aparecer tras reiniciar sesión. |
| **Evidencia** | Captura sin datos sensibles; respuesta de `GET /api/v1/tasks` sin la tarea (token redactado como `Bearer ***`). |
| **Severidad** | **Alta** — el usuario pierde acceso a sus datos (no puede ver ni deshacer). |
| **Prioridad** | **Alta** — afecta el flujo principal de la app. |
| **Estado** | Prevenido. Pruebas de regresión: `backend/tests/api/tasks.test.js` › *a completed task stays in the list…* y `mobile/test/task_list_screen_test.dart` › *a completed task stays visible…*. El listado de la API no filtra por `completed` y la app reemplaza la tarea en lugar de quitarla. |

---

## BUG-002 — Se aceptan títulos formados solo por caracteres invisibles (encontrado en la sesión exploratoria)

| Campo | Contenido |
|-------|-----------|
| **Resumen** | `POST /api/v1/tasks` acepta un título compuesto solo por U+200B (espacio de ancho cero); la tarea se muestra "en blanco". |
| **Entorno** | Windows 11, API 1.0.0 en modo memoria (`npm run start:memory`), Node 24, curl 8. 2026-11-04. |
| **Precondiciones** | Cuenta sintética `tester-a@example.test`. |
| **Pasos para reproducir** | 1. `POST /api/v1/auth/register` con la cuenta sintética. 2. `POST /api/v1/tasks` con `{"title":"​"}` y `Authorization: Bearer <token de prueba>`. |
| **Resultado esperado** | `400 {"error":"Enter a valid title."}` (equivale a "solo espacios", criterio AC-2). |
| **Resultado real** | `201` y se crea la tarea con un título invisible. |
| **Evidencia** | `{"id":"5922c65c-…","title":"​","completed":false,…}` (id truncado). |
| **Causa** | `String.prototype.trim()` (JS) y `String.trim()` (Dart) no eliminan caracteres de formato Unicode (`\p{Cf}`) como U+200B, U+200D, U+FEFF. |
| **Severidad** | **Baja** — no hay pérdida de datos, pero rompe AC-2 y genera filas "vacías" confusas. |
| **Prioridad** | **Media** — fácil de corregir y viola un criterio de aceptación. |
| **Estado** | **Corregido.** `validateTitle` (API y app) ahora exige al menos un carácter visible. Pruebas de regresión: `backend/tests/unit/validation.test.js` › *rejects a title with only invisible characters…* y `mobile/test/validation_test.dart` › *rejects zero-width space only (BUG-002)*. |

---

## BUG-003 — Para lectores de pantalla, "Borrar" marca la tarea como completada (encontrado al capturar evidencias)

| Campo | Contenido |
|-------|-----------|
| **Resumen** | Con la semántica de accesibilidad activa, activar el botón **Delete task** de una fila marca la tarea como completada en lugar de abrir la confirmación de borrado. Los botones Editar y Borrar no existen como controles independientes. |
| **Entorno** | Build web de la app (artefacto de CI, Flutter 3.47.9), Chrome headless con la semántica de Flutter habilitada; API 1.0.0 local en modo memoria. 2026-11-04. Afecta igual a TalkBack/VoiceOver porque la causa está en el árbol de semántica. |
| **Precondiciones** | Cuenta sintética con 4 tareas. |
| **Pasos para reproducir** | 1. Habilitar accesibilidad (lector de pantalla). 2. En *My tasks*, activar el ícono de papelera de la primera tarea. |
| **Resultado esperado** | Se abre el diálogo *Delete task?*; la tarea no cambia de estado. |
| **Resultado real** | La tarea pasa a *Completed* y no aparece el diálogo. Las etiquetas "Edit task" y "Delete task" no figuran en el árbol de accesibilidad. |
| **Evidencia** | `docs/evidencias/bug-003-antes-borrar-marca-tarea.png` |
| **Causa** | `CheckboxListTile` envuelve su contenido en `MergeSemantics`: los `IconButton` del `secondary` se fusionan con el nodo del checkbox, cuya acción es alternar. |
| **Severidad** | **Alta** para usuarios de lectores de pantalla: no pueden editar ni borrar, y cambian datos sin querer. |
| **Prioridad** | **Alta.** |
| **Estado** | **Corregido.** La fila es un `ListTile` con su propio `Checkbox` (`semanticLabel`) y botones independientes. Prueba de regresión: `mobile/test/task_list_screen_test.dart` › *delete is its own accessible control (BUG-003)*, que activa Borrar por el árbol de semántica y verifica que se abra la confirmación sin completar la tarea. |
| **Lección** | Las guías automatizadas (`labeledTapTargetGuideline`) pasaban: los botones tenían tooltip, pero estaban fusionados. Una prueba en verde no garantiza que la app sea accesible. |
