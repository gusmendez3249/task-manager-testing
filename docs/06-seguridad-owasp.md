# 9. Comportamiento negativo y seguridad básica

> Todas las pruebas se ejecutan solo contra la API local o la BD de prueba de CI. Nunca contra sistemas sin permiso.

## Pruebas negativas realizadas

| # | Técnica | Resultado | Prueba |
|---|---------|-----------|--------|
| 1 | Tipos inválidos, campos faltantes, valores enormes, JSON mal formado, cuerpo > 10 kB | 400 / 413 con mensaje seguro, sin stack ni SQL | `tasks.test.js` › *negative API behavior* |
| 2 | Inyección SQL: título `' OR '1'='1` y id `1' OR '1'='1` | Se guarda como texto; el id se rechaza con 404. Todas las consultas usan parámetros `$1, $2…` | *security basics* |
| 3 | Markup: `<script>alert(1)</script>` | API responde `application/json`; Flutter lo pinta como texto (`Text` no interpreta HTML) | API + `task_list_screen_test.dart` |
| 4 | Control de acceso: token de B con tarea de A (leer, editar, borrar, listar) | 404 en todos; la tarea de A queda intacta | *does not let one user…*, *cannot update/delete another user task* |
| 5 | Límite de tasa (corrida pequeña autorizada) | 4.º intento → `429 Too many attempts…` | `auth.test.js` › *rate limiting* |
| 6 | Token expirado, firma falsa, `alg: none`, refresh usado como access, rotación, reuso, logout, logout-all | Todo rechazado / revocado como corresponde | `auth.test.js`, `tokens.test.js` |
| 7 | Asignación masiva: `ownerId` en crear y en actualizar (ejercicio) | Se ignora; la propiedad sale siempre del token | *ownerId in an update is ignored…* |

## Checklist OWASP API Security Top 10 (2023)

| Riesgo | Verificación en Task Manager | Estado |
|--------|------------------------------|--------|
| API1 Broken object-level authorization | Toda consulta de tareas filtra `WHERE owner_id = $userId` (`src/tasks/repository.js`). | ✅ probado con 2 cuentas |
| API2 Broken authentication | Access JWT HS256 de 15 min con `issuer` y algoritmo fijo; refresh opaco guardado como hash SHA-256, rotación + detección de reuso; mismo mensaje para email desconocido y contraseña errónea. | ✅ |
| API3 Broken object property-level authorization | Solo se leen `title`/`completed` del cuerpo; `ownerId`, `id`, etc. se ignoran; la respuesta no expone `owner_id` ni `password_hash`. | ✅ |
| API4 Unrestricted resource consumption | `limit` ≤ 100, cuerpo ≤ 10 kB, título ≤ 120, refresh token ≤ 200 chars. | ✅ |
| API5 Broken function-level authorization | `/tasks/*` y `/auth/logout-all` exigen Bearer válido. No hay rutas de admin. | ✅ |
| API6 Unrestricted access to sensitive business flows | `express-rate-limit` en register/login/refresh (10 por 15 min por IP en producción). | ✅ |
| API7 SSRF | La API no acepta URLs del usuario ni hace peticiones salientes. | ✅ N/A |
| API8 Security misconfiguration | `helmet` (cabeceras seguras), sin `x-powered-by`, CORS cerrado salvo `CORS_ORIGINS`, errores genéricos. **Pendiente para producción:** HTTPS detrás de un proxy. | ⚠️ HTTPS depende del despliegue |
| API9 Improper inventory management | Única versión `/api/v1`; rutas no documentadas devuelven 404 (`/api/v0/tasks` probado). | ✅ |
| API10 Unsafe consumption of APIs | La app valida cada respuesta (`Task.fromJson`, `_decodeObject`) y muestra un error seguro si el formato no es el esperado. | ✅ `api_client_test.dart` |

## Recordatorio

Una prueba en verde **no** prueba que la app sea segura; solo que los casos pensados se comportan como se espera.
