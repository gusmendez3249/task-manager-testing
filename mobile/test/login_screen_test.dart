import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/screens/login_screen.dart';

import 'support/fake_backend.dart';

void main() {
  late FakeBackend backend;
  late int signedIn;

  setUp(() {
    backend = FakeBackend();
    signedIn = 0;
  });

  Future<void> pumpLogin(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(
          api: backend.signedOutClient(),
          onSignedIn: () => signedIn++,
        ),
      ),
    );
  }

  testWidgets('shows validation errors without calling the API', (tester) async {
    await pumpLogin(tester);

    await tester.enterText(find.byKey(const Key('email-field')), 'not-an-email');
    await tester.enterText(find.byKey(const Key('password-field')), 'short');
    await tester.tap(find.byKey(const Key('login-button')));
    await tester.pump();

    expect(find.text('Enter a valid email.'), findsOneWidget);
    expect(find.text('Password must be 8 to 72 characters.'), findsOneWidget);
    expect(backend.requests, isEmpty);
    expect(signedIn, 0);
  });

  testWidgets('signs in with valid synthetic credentials', (tester) async {
    await pumpLogin(tester);

    await tester.enterText(
        find.byKey(const Key('email-field')), 'tester@example.test');
    await tester.enterText(
        find.byKey(const Key('password-field')), 'local-test-password');
    await tester.tap(find.byKey(const Key('login-button')));
    await tester.pumpAndSettle();

    expect(signedIn, 1);
    expect(backend.count('POST', '/api/v1/auth/login'), 1);
  });

  testWidgets('shows the server error for wrong credentials', (tester) async {
    await pumpLogin(tester);

    await tester.enterText(
        find.byKey(const Key('email-field')), 'tester@example.test');
    await tester.enterText(
        find.byKey(const Key('password-field')), 'wrong-password');
    await tester.tap(find.byKey(const Key('login-button')));
    await tester.pumpAndSettle();

    expect(find.text('Invalid email or password.'), findsOneWidget);
    expect(signedIn, 0);
  });

  testWidgets('rapid repeated taps send only one login request', (tester) async {
    await pumpLogin(tester);

    await tester.enterText(
        find.byKey(const Key('email-field')), 'tester@example.test');
    await tester.enterText(
        find.byKey(const Key('password-field')), 'local-test-password');
    await tester.tap(find.byKey(const Key('login-button')));
    await tester.tap(find.byKey(const Key('login-button')),
        warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(backend.count('POST', '/api/v1/auth/login'), 1);
    expect(signedIn, 1);
  });

  testWidgets('offline sign-in shows how to recover', (tester) async {
    backend.offline = true;
    await pumpLogin(tester);

    await tester.enterText(
        find.byKey(const Key('email-field')), 'tester@example.test');
    await tester.enterText(
        find.byKey(const Key('password-field')), 'local-test-password');
    await tester.tap(find.byKey(const Key('login-button')));
    await tester.pumpAndSettle();

    expect(
      find.text('Could not reach the server. Check your connection and try again.'),
      findsOneWidget,
    );
  });

  testWidgets('can switch to account creation', (tester) async {
    await pumpLogin(tester);

    await tester.tap(find.byKey(const Key('register-toggle')));
    await tester.pump();

    expect(find.text('Create account'), findsNWidgets(2));
    expect(find.text('8 to 72 characters'), findsOneWidget);
  });
}
