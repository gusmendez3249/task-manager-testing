import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/app.dart';

import 'support/fake_backend.dart';

// Smoke test of the whole widget tree with a fake backend: app opens, login works,
// task list loads, a task can be created, logout returns to the login screen.
void main() {
  testWidgets('smoke: sign in, create a task, sign out', (tester) async {
    final backend = FakeBackend();
    await tester.pumpWidget(TaskManagerApp(api: backend.signedOutClient()));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('email-field')), 'tester@example.test');
    await tester.enterText(
        find.byKey(const Key('password-field')), 'local-test-password');
    await tester.tap(find.byKey(const Key('login-button')));
    await tester.pumpAndSettle();

    expect(find.text('My tasks'), findsOneWidget);

    await tester.tap(find.byKey(const Key('add-task-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('task-title-field')), 'Check release flow');
    await tester.tap(find.byKey(const Key('save-task-button')));
    await tester.pumpAndSettle();
    expect(find.text('Check release flow'), findsOneWidget);

    await tester.tap(find.byKey(const Key('logout-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login-button')), findsOneWidget);
  });

  testWidgets('an existing session opens the task list directly',
      (tester) async {
    final backend = FakeBackend()..seed('Remembered');
    await tester.pumpWidget(TaskManagerApp(api: backend.signedInClient()));
    await tester.pumpAndSettle();

    expect(find.text('Remembered'), findsOneWidget);
  });
}
