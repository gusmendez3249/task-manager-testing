// End-to-end journey against a LOCAL test backend and a synthetic test account.
//
//   cd backend && npm run start:memory          (or a dedicated test database)
//   cd mobile  && flutter test integration_test --dart-define=API_BASE_URL=http://10.0.2.2:3000
//
// Never point this at production.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:task_manager/main.dart' as app;
import 'package:task_manager/services/secure_token_store.dart';

const _email = 'tester@example.test';
const _password = 'local-test-password';

/// Resets the test account before each run: creates it if needed and deletes its tasks.
Future<void> resetTestAccount() async {
  final base = app.apiBaseUrl;
  const json = {'Content-Type': 'application/json'};
  final credentials = jsonEncode({'email': _email, 'password': _password});

  await http.post(Uri.parse('$base/api/v1/auth/register'),
      headers: json, body: credentials); // 201, or 409 if it already exists.

  final login = await http.post(Uri.parse('$base/api/v1/auth/login'),
      headers: json, body: credentials);
  final token = (jsonDecode(login.body) as Map<String, dynamic>)['accessToken'];
  final auth = {'Authorization': 'Bearer $token'};

  final list = await http.get(Uri.parse('$base/api/v1/tasks?limit=100'),
      headers: auth);
  final tasks = (jsonDecode(list.body) as Map<String, dynamic>)['tasks'] as List;
  for (final task in tasks) {
    await http.delete(Uri.parse('$base/api/v1/tasks/${task['id']}'),
        headers: auth);
  }

  // Start signed out.
  await SecureTokenStore().clear();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(resetTestAccount);

  testWidgets('user can sign in and create a task', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('email-field')), _email);
    await tester.enterText(find.byKey(const Key('password-field')), _password);
    await tester.tap(find.byKey(const Key('login-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('add-task-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('task-title-field')), 'Check release flow');
    await tester.tap(find.byKey(const Key('save-task-button')));
    await tester.pumpAndSettle();

    expect(find.text('Check release flow'), findsOneWidget);
  });

  // Practice exercise (section 7): mark complete, log out, see the login screen.
  testWidgets('user can complete a task and log out', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('email-field')), _email);
    await tester.enterText(find.byKey(const Key('password-field')), _password);
    await tester.tap(find.byKey(const Key('login-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('add-task-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('task-title-field')), 'Check release flow');
    await tester.tap(find.byKey(const Key('save-task-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(CheckboxListTile, 'Check release flow'));
    await tester.pumpAndSettle();
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('Check release flow'), findsOneWidget);

    await tester.tap(find.byKey(const Key('logout-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login-button')), findsOneWidget);
    expect(find.byKey(const Key('email-field')), findsOneWidget);
  });
}
