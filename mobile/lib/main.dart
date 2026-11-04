import 'package:flutter/material.dart';

import 'app.dart';
import 'services/api_client.dart';
import 'services/secure_token_store.dart';

/// API location. 10.0.2.2 is the host machine from the Android emulator.
/// Override with: flutter run --dart-define=API_BASE_URL=http://localhost:3000
const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:3000',
);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    TaskManagerApp(
      api: ApiClient(baseUrl: apiBaseUrl, tokenStore: SecureTokenStore()),
    ),
  );
}
