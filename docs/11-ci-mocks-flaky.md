# 14–15. CI, cobertura, mocks y pruebas inestables

## Integración continua (`.github/workflows/tests.yml`)

| Job | Qué hace |
|-----|----------|
| `backend (postgres)` | `npm ci` + Jest/Supertest contra un **PostgreSQL 17 real** (servicio aislado de CI) con cobertura. |
| `backend (memory)` | Las mismas pruebas contra pg-mem (rápido, sin Docker). |
| `flutter` | `flutter analyze` + `flutter test --coverage`. |
| `android-build` | Genera la carpeta `android/` y compila un APK debug (smoke de compatibilidad). El APK queda como artefacto. |
| `k6-smoke` | Levanta API + PostgreSQL efímeros y corre los dos scripts k6 con umbrales. |

Se ejecuta en cada `push` a `main` y en cada pull request.

### Ejercicio: hacer fallar CI a propósito

1. En `backend/src/tasks/validation.js` cambiar `title.length > TITLE_MAX_LENGTH` por `title.length > 121`.
2. `npm test` → falla *rejects a title longer than the limit* y *just over maximum (121)*.
3. Al hacer push, el job **backend** queda en rojo y bloquea el merge.
4. Restaurar el código → verde.

## Cobertura

`npm run test:coverage` (backend ≈ 93 % de líneas) y `flutter test --coverage`. La cobertura indica **qué código se ejecutó**, no que se verificó el comportamiento correcto: por ejemplo, una prueba que crea una tarea con un solo usuario ejecuta la consulta con `owner_id` pero no demuestra que otro usuario no pueda verla. Por eso las pruebas de propiedad usan **dos cuentas**.

## Mocks vs. integración real (ejercicio de la sección 15)

| | Prueba con mock (`mobile/test/api_client_test.dart`) | Prueba de integración (`backend/tests/api/*.test.js` con PostgreSQL) |
|---|---|---|
| Velocidad | Milisegundos, sin red | Segundos, requiere BD |
| Detecta | Cabecera `Bearer`, refresh único ante 401 en paralelo, mapeo de errores, respuestas malformadas, logout offline | Autorización real por dueño, SQL parametrizado, restricciones, rotación de tokens persistida, límites de tasa |
| **No** puede detectar | Si el servidor realmente filtra por dueño o persiste los datos | Problemas de la UI o del manejo de red en el teléfono |

Regla aplicada: **nunca se mockea lo que se quiere verificar**; las pruebas de propiedad ejercitan la frontera de autorización real, no un `FakeBackend`.

## Pruebas inestables (flaky)

- Cada prueba de API vacía la BD en `beforeEach` y crea sus propios usuarios únicos.
- Jest corre con `--runInBand` para que no compitan por la misma BD.
- El token expirado se crea firmándolo con expiración negativa (no se espera con `sleep`).
- Las pruebas de widgets usan `MockClient`: sin red real ni temporizadores.
- Si una prueba falla de forma intermitente: capturar logs sin tokens, controlar tiempo/red/datos y revisar paralelismo; **no** reintentar hasta que pase.
