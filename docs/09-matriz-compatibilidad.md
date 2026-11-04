# 12. Compatibilidad de dispositivos y plataformas

| Plataforma | Perfil de dispositivo | Rango de SO | Verificaciones | Cómo / estado |
|------------|----------------------|-------------|----------------|---------------|
| Android | Pantalla pequeña (320×568 dp) | Mínimo soportado por Flutter (API 21+) | Login, texto escalado, red | Widget test *works on a small screen with 2x text* ✅; dispositivo físico ☐ |
| Android | Dispositivo actual común (Pixel 6/7) | Android 14–15 | CRUD de tareas, refresh, logout | Emulador + `integration_test` ☐ |
| iOS | Pantalla pequeña (iPhone SE) | iOS mínimo soportado | Layout, almacenamiento seguro (Keychain), accesibilidad | ☐ Requiere Mac |
| iOS | Dispositivo actual | iOS actual | Login, ciclo de vida (segundo plano), recuperación de red | ☐ Requiere Mac |
| Emulador | Perfil de desarrollo | Toolchain actual | Smoke automatizado rápido | CI: `flutter test` + `flutter build apk --debug` ✅ |

**Ejercicio:** abrir la lista en una pantalla pequeña y en una tableta; anotar desbordes, texto recortado y controles difíciles de tocar.

| Pantalla | Desbordes | Texto recortado | Controles difíciles |
|----------|-----------|-----------------|---------------------|
| 320×568 (test automatizado) | Ninguno | El título largo se ajusta a varias líneas | Ninguno (guía de 48 dp pasa) |
| Tableta 10" | ☐ | ☐ | ☐ |
