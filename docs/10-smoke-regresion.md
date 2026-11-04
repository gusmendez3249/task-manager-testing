# 13. Smoke, regresión y datos de prueba

## Suite smoke (después de cada build)

| # | Verificación | Automatizado en |
|---|--------------|-----------------|
| 1 | La app abre | `mobile/test/app_test.dart` |
| 2 | El login funciona | `app_test.dart`, `login_screen_test.dart` |
| 3 | La lista de tareas carga | `app_test.dart` |
| 4 | Se puede crear una tarea | `app_test.dart` |
| 5 | El logout funciona | `app_test.dart` |
| 6 | La API responde `/health` | `tasks.test.js` › *health*, job `k6-smoke` |

## Checklist de regresión (ejercicio)

| Área | Caso | Auto |
|------|------|------|
| Creación | Título válido se guarda y aparece | ✅ |
| Creación | Vacío, solo espacios, invisibles y 121 caracteres se rechazan | ✅ |
| Creación | Doble toque crea una sola tarea | ✅ |
| Edición | Renombrar actualiza la lista y la API | ✅ |
| Edición | Error de red conserva el texto y el título anterior | ✅ |
| Completar | Marcar/desmarcar mantiene la tarea visible (BUG-001) | ✅ |
| Eliminación | Confirmar elimina; cancelar conserva | ✅ |
| Acceso cruzado | B no puede leer/editar/borrar/listar tareas de A | ✅ |
| Sesión | Refresh rota; reuso revoca familia; logout y logout-all | ✅ |

## Datos de prueba

- Sintéticos y reproducibles: `tester<timestamp>-<n>@example.test`, contraseña `local-test-password`.
- Antes de cada prueba se vacía **solo** la BD de prueba (`resetForTests` lanza error si no es `NODE_ENV=test` o BD en memoria).
- El E2E reinicia la cuenta `tester@example.test` (crea si falta, borra sus tareas, cierra sesión local).
- Entorno y build quedan registrados en cada ejecución de GitHub Actions (versión de Node/Flutter, commit).
