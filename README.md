# Task Manager — práctica para ser un mejor tester de aplicaciones

Implementación completa del tutorial *"Become a Better Application Tester: A Hands-On Task Manager Guide"*:

- **App móvil Flutter** (`mobile/`): login/registro, lista de tareas, crear/editar/completar/borrar, logout. Tokens en almacenamiento seguro y refresh automático.
- **API REST Node.js/Express** (`backend/`): PostgreSQL, JWT de acceso + refresh tokens con rotación y detección de reuso, logout y logout-all, límites de tasa, validación y autorización por dueño.
- **Pruebas en todos los niveles de la pirámide** + documentos de QA (`docs/`) + CI en GitHub Actions.

> Solo entornos locales o de prueba. Datos y cuentas sintéticas (`*@example.test`). Nunca pegues tokens reales en reportes ni capturas.

## Estructura

```
backend/            API Express + PostgreSQL
  src/              app.js, auth/, tasks/, db/ (schema.sql), middleware/
  tests/unit/       Jest: validación, límites, tokens
  tests/api/        Supertest: CRUD, propiedad, seguridad, auth, rate limit
  perf/             scripts k6
mobile/             App Flutter
  lib/              models/, services/ (ApiClient, tokens), screens/, widgets/
  test/             unitarias, widgets, ApiClient con mocks, accesibilidad
  integration_test/ recorrido E2E contra la API local
docs/               plan, casos, bugs, exploratoria, límites, OWASP, k6, a11y, matriz, regresión, CI
.github/workflows/  tests.yml
docker-compose.yml  PostgreSQL local (dev) y de pruebas
```

## Cómo correrlo

### API

```bash
cd backend
npm install
npm test                      # 127 pruebas; usa PostgreSQL en memoria (pg-mem)
npm run start:memory          # API de demo en http://localhost:3000 sin instalar PostgreSQL
```

Con PostgreSQL real:

```bash
docker compose up -d db db-test
cd backend && cp .env.example .env     # edita JWT_ACCESS_SECRET
npm run migrate && npm start
```

Pruebas contra el PostgreSQL de pruebas (puerto 5433):

```bash
cd backend && NODE_ENV=test DATABASE_URL=postgres://taskmanager:taskmanager_local_only@localhost:5433/taskmanager_test npm test
```

### App

```bash
cd mobile
flutter create --platforms=android,ios --org mx.edu.utng --project-name task_manager .   # solo la primera vez
flutter pub get
flutter test                                   # unitarias + widgets
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

Más detalles en [mobile/README.md](mobile/README.md).

## Endpoints

| Método | Ruta | Auth | Descripción |
|--------|------|------|-------------|
| GET | `/health` | — | Estado |
| POST | `/api/v1/auth/register` | — | `{email, password}` → `201 {user, accessToken, refreshToken}` |
| POST | `/api/v1/auth/login` | — | `{email, password}` → `200 {…tokens}` |
| POST | `/api/v1/auth/refresh` | — | `{refreshToken}` → nuevo par (el anterior queda revocado) |
| POST | `/api/v1/auth/logout` | — | `{refreshToken}` → `204` (revoca esa sesión) |
| POST | `/api/v1/auth/logout-all` | Bearer | `204` (revoca todas las sesiones del usuario) |
| GET | `/api/v1/tasks?limit=&offset=` | Bearer | Tareas del usuario (`limit` 1–100) |
| POST | `/api/v1/tasks` | Bearer | `{title}` (1–120 caracteres) |
| GET / PATCH / DELETE | `/api/v1/tasks/:id` | Bearer | `PATCH {title?, completed?}`. Tareas ajenas → `404` |

## Mapa del tutorial → entregables

| Sección del tutorial | Dónde está |
|----------------------|------------|
| 1. Mentalidad y plan | [docs/01-plan-de-pruebas.md](docs/01-plan-de-pruebas.md) (criterios de aceptación, pirámide, plan) |
| 2. Casos de prueba y bug reports | [docs/02-casos-de-prueba.md](docs/02-casos-de-prueba.md), [docs/03-reporte-de-bug.md](docs/03-reporte-de-bug.md) |
| 3. Exploratoria con charter | [docs/04-sesion-exploratoria.md](docs/04-sesion-exploratoria.md) (encontró BUG-002, ya corregido) |
| 4. Unitarias | `backend/tests/unit/*`, `mobile/test/task_test.dart`, `mobile/test/validation_test.dart` |
| 5. Widgets Flutter (+ botón *retry*) | `mobile/test/task_list_panel_test.dart`, `task_list_screen_test.dart`, `login_screen_test.dart` |
| 6. API e integración | `backend/tests/api/tasks.test.js`, `auth.test.js` |
| 7. Recorridos completos | `mobile/integration_test/app_test.dart` (crear, completar, logout) |
| 8. Valores límite | [docs/05-valores-limite.md](docs/05-valores-limite.md) (título y contraseña) |
| 9. Negativas y seguridad / OWASP | [docs/06-seguridad-owasp.md](docs/06-seguridad-owasp.md) |
| 10. Rendimiento k6 | `backend/perf/`, [docs/07-rendimiento-k6.md](docs/07-rendimiento-k6.md) |
| 11. Accesibilidad | [docs/08-accesibilidad.md](docs/08-accesibilidad.md) + guías automatizadas |
| 12. Compatibilidad | [docs/09-matriz-compatibilidad.md](docs/09-matriz-compatibilidad.md) |
| 13. Smoke y regresión | [docs/10-smoke-regresion.md](docs/10-smoke-regresion.md) |
| 14–15. CI, cobertura, mocks, flaky | [.github/workflows/tests.yml](.github/workflows/tests.yml), [docs/11-ci-mocks-flaky.md](docs/11-ci-mocks-flaky.md) |

## Plan de práctica de 4 semanas

| Semana | Enfoque | Resultado en este repo |
|--------|---------|------------------------|
| 1 | Mentalidad, plan, casos, exploratoria | Plan, 10 casos, 1 sesión exploratoria, 2 bug reports |
| 2 | Unitarias, widgets, API, integración | Validación de título, estados de la lista, propiedad de tareas |
| 3 | E2E, límites, seguridad, accesibilidad | Recorrido E2E, tablas de límites, checklist OWASP y a11y |
| 4 | Rendimiento, compatibilidad, regresión, CI | k6 en CI, matriz de dispositivos, checklist de regresión, workflow |
