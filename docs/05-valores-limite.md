# 8. Valores límite y particiones de equivalencia

## Título de tarea (1 a 120 caracteres después de recortar)

| Partición o límite | Entrada de ejemplo | Esperado | Prueba (API / app) |
|--------------------|--------------------|----------|--------------------|
| Vacío | `""` | Rechazar | ✅ / ✅ |
| Solo espacios | `" "` | Rechazar | ✅ / ✅ |
| Solo invisibles (BUG-002) | `"​"` | Rechazar | ✅ / ✅ |
| Longitud mínima válida | `"a"` | Aceptar | ✅ / ✅ |
| Título típico | `"Plan tests"` | Aceptar | ✅ / ✅ |
| Longitud máxima | 120 caracteres | Aceptar | ✅ / ✅ |
| 120 + espacios alrededor | `"  " + 120 + "  "` | Aceptar (se recorta) | ✅ / — |
| Justo sobre el máximo | 121 caracteres | Rechazar | ✅ / ✅ |
| Tipo incorrecto en JSON | `title: 42`, `null`, `[]`, `{}`, `true` | Rechazar con 400 seguro | ✅ / ✅ (`Task.fromJson`) |
| Unicode válido | `"🎉 Fiesta ñ"` | Aceptar | ✅ / ✅ |

En la app el campo tiene `maxLength: 120`, por lo que el teclado no permite escribir el carácter 121; la API lo valida igualmente (nunca confiar solo en el cliente).

## Contraseña (8 a 72 **bytes** UTF-8) — ejercicio de práctica

bcrypt solo usa los primeros 72 bytes; aceptar más haría que dos contraseñas distintas fueran equivalentes.

| Partición o límite | Entrada de ejemplo (sintética) | Esperado | Prueba |
|--------------------|-------------------------------|----------|--------|
| Vacía | `""` | Rechazar | ✅ unit + API + app |
| Justo bajo el mínimo | 7 caracteres | Rechazar | ✅ |
| Mínimo | 8 caracteres | Aceptar | ✅ |
| Típica | `local-test-password` | Aceptar | ✅ |
| Máximo | 72 caracteres ASCII | Aceptar | ✅ |
| Sobre el máximo | 73 caracteres | Rechazar | ✅ |
| Multibyte sobre el máximo | `"ñ" × 37` (74 bytes) | Rechazar | ✅ |
| Tipo incorrecto | `12345678` (número) | Rechazar | ✅ |

## Paginación (`limit` 1–100, `offset` 0–100000)

| Entrada | Esperado |
|---------|----------|
| `limit=0` / `limit=101` / `limit=abc` / `limit=2.5` | 400 |
| `limit=1` / `limit=100` | 200 |
| `offset=-1` | 400 |
| sin parámetros | `limit=50, offset=0` |
