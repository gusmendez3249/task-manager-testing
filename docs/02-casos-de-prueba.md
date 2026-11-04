# 2. Casos de prueba

Plantilla: ID y título · Precondiciones · Pasos · Datos · Resultado esperado · Resultado real · Entorno.

> **Entorno de referencia:** API `task-manager-api` 1.0.0 (Node 22, PostgreSQL 17 o pg-mem), app `task_manager` 1.0.0+1 (Flutter stable), emulador Android API 34. El "resultado real" de las filas automatizadas es el estado de la prueba en CI.

---

### TC-01 — Crear una tarea con título válido

| Campo | Contenido |
|-------|-----------|
| Precondiciones | Usuario A registrado y con sesión iniciada; lista vacía. |
| Pasos | 1. Tocar **Add task**. 2. Escribir el título. 3. Tocar **Save**. |
| Datos | Título: `"  Plan tests  "` |
| Esperado | El diálogo se cierra; aparece **Plan tests** (sin espacios extra) con estado *Pending*. `GET /api/v1/tasks` devuelve 1 tarea. |
| Real | ✅ Pasa (`task_list_screen_test.dart` › *creates a task…*; API › *a signed-in user can create a task…*). |
| Entorno | Ver arriba. |

### TC-02 — Rechazar título solo con espacios

| Campo | Contenido |
|-------|-----------|
| Precondiciones | Usuario A con sesión. |
| Pasos | 1. **Add task**. 2. Escribir 3 espacios. 3. **Save**. |
| Datos | `"   "` |
| Esperado | App: mensaje *Enter a title.* y no se envía petición. API (directo): `400 {"error":"Enter a valid title."}`. |
| Real | ✅ Pasa (app y API). |

### TC-03 — Un usuario no puede leer la tarea de otro

| Campo | Contenido |
|-------|-----------|
| Precondiciones | Usuarios A y B registrados. A tiene la tarea *Private task* con id `X`. |
| Pasos | 1. Con el token de B: `GET /api/v1/tasks/X`. |
| Datos | Token de B (sintético), id de A. |
| Esperado | `404 {"error":"Task not found."}` — idéntico a un id inexistente, para no revelar que existe. |
| Real | ✅ Pasa (*does not let one user read another user task*, *a well-formed but unknown task ID returns the same 404*). |

### TC-04 — Completar una tarea la mantiene visible (regresión BUG-001)

| Campo | Contenido |
|-------|-----------|
| Precondiciones | Usuario A con la tarea *Finish report* pendiente. |
| Pasos | 1. Tocar la casilla de *Finish report*. |
| Esperado | La tarea sigue en la lista, tachada y con el texto *Completed*. `completed: true` en la API. |
| Real | ✅ Pasa (app y API). |

### TC-05 — Doble toque en "Save" crea una sola tarea

| Campo | Contenido |
|-------|-----------|
| Precondiciones | Usuario A con sesión. |
| Pasos | 1. **Add task**. 2. Escribir `Once`. 3. Tocar **Save** 3 veces seguidas muy rápido. |
| Esperado | Solo 1 `POST /api/v1/tasks`; aparece una sola tarea *Once*. |
| Real | ✅ Pasa (*rapid repeated taps on Save create only one task*). |

### TC-06 — Editar sin conexión no pierde datos

| Campo | Contenido |
|-------|-----------|
| Precondiciones | Tarea *Original title*. |
| Pasos | 1. Tocar el lápiz. 2. Cambiar a `Edited offline`. 3. Cortar la red. 4. **Save**. 5. **Cancel**. |
| Esperado | Paso 4: el diálogo sigue abierto con el texto y un error explicando cómo recuperarse. Paso 5: la lista conserva *Original title*. |
| Real | ✅ Pasa (*editing offline keeps the typed text and the old title*). |

### TC-07 — Reuso de refresh token revoca la sesión

| Campo | Contenido |
|-------|-----------|
| Precondiciones | Usuario A con par de tokens `R1`. |
| Pasos | 1. `POST /auth/refresh` con `R1` → recibe `R2`. 2. Repetir con `R1`. 3. Intentar con `R2`. |
| Esperado | Paso 2: `401 Refresh token reuse detected…`. Paso 3: `401` (toda la familia revocada). |
| Real | ✅ Pasa (*reusing an old refresh token is detected…*). |

### TC-08 — Logout-all cierra todas las sesiones

| Campo | Contenido |
|-------|-----------|
| Precondiciones | Usuario A con sesión en 2 "dispositivos". |
| Pasos | 1. `POST /auth/logout-all` con el access token del dispositivo 1. 2. Intentar refresh con ambos refresh tokens. |
| Esperado | `204`; ambos refresh devuelven `401`. Las sesiones de B no se afectan. |
| Real | ✅ Pasa. |

### TC-09 — Límite de intentos de login

| Campo | Contenido |
|-------|-----------|
| Precondiciones | App de prueba con límite de 3 intentos/minuto (corrida pequeña y autorizada). |
| Pasos | 1. 4 logins con contraseña incorrecta. |
| Esperado | `401, 401, 401, 429` con mensaje seguro y cabecera `RateLimit-Policy`. |
| Real | ✅ Pasa. |

### TC-10 — Smoke de la app completa

| Campo | Contenido |
|-------|-----------|
| Pasos | Abrir app → login → ver lista → crear tarea → logout. |
| Esperado | Termina en la pantalla de login. |
| Real | ✅ Pasa con backend falso (`test/app_test.dart`). Con backend real: `integration_test/app_test.dart` (manual). |
