# Task Manager — app Flutter

## Primera vez

Las carpetas de plataforma (`android/`, `ios/`) no se versionan; se generan con:

```bash
flutter create --platforms=android,ios --org mx.edu.utng --project-name task_manager .
flutter pub get
```

Para builds **release** en Android agrega `<uses-permission android:name="android.permission.INTERNET"/>` en `android/app/src/main/AndroidManifest.xml` (en debug ya viene incluido).

## Ejecutar

1. Levanta la API: `cd ../backend && npm run start:memory`.
2. Corre la app apuntando a la API:
   - Emulador Android: `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000`
   - Simulador iOS / escritorio: `flutter run --dart-define=API_BASE_URL=http://localhost:3000`
   - Teléfono físico: usa la IP de tu PC en la misma red, p. ej. `http://192.168.1.50:3000`.

## Pruebas

```bash
flutter analyze
flutter test                       # unitarias + widgets (sin red, con MockClient)
flutter test --coverage
```

E2E (necesita emulador y la API local; usa la cuenta sintética `tester@example.test`, que el propio test crea y limpia):

```bash
flutter test integration_test --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

## Claves usadas por las pruebas

`email-field`, `password-field`, `login-button`, `register-toggle`, `add-task-button`, `task-title-field`, `save-task-button`, `cancel-task-button`, `logout-button`, `retry-button`, `confirm-delete-button`.
