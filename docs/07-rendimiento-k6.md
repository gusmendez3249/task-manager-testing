# 10. Rendimiento y carga (de forma segura)

- **Autorización:** solo contra la API local o la API efímera que levanta GitHub Actions. Nunca contra producción.
- **Entorno dedicado:** el job `k6-smoke` de CI arranca su propio PostgreSQL y la API en `localhost:3000`.
- **Carga inicial pequeña y condición de paro:** umbrales `http_req_failed < 1 %` (con `abortOnFail` en el script autenticado) y `p(95) < 500 ms`.
- **Métricas:** tiempo de respuesta (`http_req_duration`), tasa de error (`http_req_failed`), throughput (`http_reqs`). CPU, memoria y conexiones de BD se observan localmente con el Administrador de tareas / `docker stats` y `SELECT count(*) FROM pg_stat_activity`.

## Scripts

| Script | Carga | Qué mide |
|--------|-------|----------|
| `backend/perf/health-test.js` | 5 VUs × 30 s | `/health` (el del tutorial) |
| `backend/perf/tasks-list-test.js` | rampa 0→5→10→0 VUs en 40 s | `GET /api/v1/tasks?limit=20` autenticado, con 20 tareas sembradas |

## Cómo correrlo localmente

```bash
cd backend
npm run start:memory          # o npm start con PostgreSQL
BASE_URL=http://localhost:3000 k6 run perf/health-test.js
```

## Ejercicio: cambiar un umbral y explicar el reporte

1. Correr `health-test.js` tal cual. En el resumen, buscar `http_req_duration ... p(95)=` y `✓ http_req_duration` (umbral cumplido).
2. Cambiar el umbral a `'p(95)<1'` (1 ms) y volver a correr.
3. **Interpretación:** k6 marcará `✗ http_req_duration` y terminará con código de salida 99 (*thresholds have been crossed*). La API no se volvió más lenta: el **criterio** se volvió irreal. Un umbral es un acuerdo de negocio (p. ej. "95 % de respuestas en menos de 500 ms"), no una medida de la API por sí mismo.
4. Restaurar `'p(95)<500'`.

## Resultados

Los resúmenes (`k6-health.json`, `k6-tasks.json`) se guardan como artefacto **k6-results** en cada ejecución del workflow *Tests* en GitHub Actions.
