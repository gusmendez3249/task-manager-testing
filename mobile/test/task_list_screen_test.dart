import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/screens/task_list_screen.dart';

import 'support/fake_backend.dart';

void main() {
  late FakeBackend backend;
  late int signedOut;

  setUp(() {
    backend = FakeBackend();
    signedOut = 0;
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
        home: TaskListScreen(
          api: backend.signedInClient(),
          onSignedOut: () => signedOut++,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> addTask(WidgetTester tester, String title) async {
    await tester.tap(find.byKey(const Key('add-task-button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('task-title-field')), title);
    await tester.tap(find.byKey(const Key('save-task-button')));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the empty state for a new user', (tester) async {
    await pumpScreen(tester);
    expect(find.text('No tasks yet.'), findsOneWidget);
  });

  testWidgets('creates a task and shows it in the list', (tester) async {
    await pumpScreen(tester);

    await addTask(tester, '  Check release flow  ');

    expect(find.text('Check release flow'), findsOneWidget);
    expect(backend.tasks.single['title'], 'Check release flow');
  });

  testWidgets('a blank title is rejected with a clear message', (tester) async {
    await pumpScreen(tester);

    await addTask(tester, '   ');

    expect(find.text('Enter a title.'), findsOneWidget);
    expect(backend.count('POST', '/api/v1/tasks'), 0);
  });

  // Found in the exploratory session: rapid repeated taps on Save.
  testWidgets('rapid repeated taps on Save create only one task', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(const Key('add-task-button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('task-title-field')), 'Once');
    final save = find.byKey(const Key('save-task-button'));
    await tester.tap(save);
    await tester.tap(save, warnIfMissed: false);
    await tester.tap(save, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(backend.count('POST', '/api/v1/tasks'), 1);
    expect(find.text('Once'), findsOneWidget);
  });

  // Regression for BUG-001: a task disappears after being marked complete.
  testWidgets('a completed task stays visible and says Completed',
      (tester) async {
    backend.seed('Finish report');
    await pumpScreen(tester);

    await tester.tap(find.widgetWithText(ListTile, 'Finish report'));
    await tester.pumpAndSettle();

    expect(find.text('Finish report'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
    expect(backend.tasks.single['completed'], isTrue);
  });

  // Exploratory charter: "Explore task editing to find data-loss problems."
  testWidgets('editing offline keeps the typed text and the old title',
      (tester) async {
    backend.seed('Original title');
    await pumpScreen(tester);

    await tester.tap(find.byTooltip('Edit task'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('task-title-field')), 'Edited offline');
    backend.offline = true;
    await tester.tap(find.byKey(const Key('save-task-button')));
    await tester.pumpAndSettle();

    // The dialog stays open with the error and the user's text.
    expect(find.byKey(const Key('task-save-error')), findsOneWidget);
    expect(find.text('Edited offline'), findsOneWidget);

    await tester.tap(find.byKey(const Key('cancel-task-button')));
    await tester.pumpAndSettle();

    expect(find.text('Original title'), findsOneWidget);
    expect(backend.tasks.single['title'], 'Original title');
  });

  testWidgets('deletes a task after confirmation', (tester) async {
    backend.seed('Temporary');
    await pumpScreen(tester);

    await tester.tap(find.byTooltip('Delete task'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-delete-button')));
    await tester.pumpAndSettle();

    expect(find.text('Temporary'), findsNothing);
    expect(find.text('No tasks yet.'), findsOneWidget);
    expect(backend.tasks, isEmpty);
  });

  testWidgets('cancelling delete keeps the task', (tester) async {
    backend.seed('Keep me');
    await pumpScreen(tester);

    await tester.tap(find.byTooltip('Delete task'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cancel-delete-button')));
    await tester.pumpAndSettle();

    expect(find.text('Keep me'), findsOneWidget);
    expect(backend.tasks, hasLength(1));
  });

  testWidgets('a load error offers retry, and retry recovers', (tester) async {
    backend
      ..seed('Plan tests')
      ..failListWith = 503;
    await pumpScreen(tester);

    expect(find.text('The server had a problem. Try again later.'),
        findsOneWidget);

    backend.failListWith = null;
    await tester.tap(find.byKey(const Key('retry-button')));
    await tester.pumpAndSettle();

    expect(find.text('Plan tests'), findsOneWidget);
  });

  testWidgets('logout calls the API and signs out', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(const Key('logout-button')));
    await tester.pumpAndSettle();

    expect(backend.count('POST', '/api/v1/auth/logout'), 1);
    expect(signedOut, 1);
  });

  testWidgets('markup-like titles are shown as plain text', (tester) async {
    backend.seed('<script>alert(1)</script>');
    await pumpScreen(tester);
    expect(find.text('<script>alert(1)</script>'), findsOneWidget);
  });

  // Regression for BUG-003 (found while capturing evidence): with CheckboxListTile the
  // edit/delete buttons were merged into the tile, so a screen-reader "activate" on
  // Delete toggled the task instead of opening the confirmation.
  testWidgets('delete is its own accessible control (BUG-003)', (tester) async {
    final semantics = tester.ensureSemantics();
    backend.seed('Finish report');
    await pumpScreen(tester);

    final delete = tester.getSemantics(find.byTooltip('Delete task'));
    expect(delete.tooltip, 'Delete task');
    expect(delete.label, isNot(contains('Finish report')));

    delete.owner!.performAction(delete.id, SemanticsAction.tap);
    await tester.pumpAndSettle();

    expect(find.text('Delete task?'), findsOneWidget);
    expect(backend.tasks.single['completed'], isFalse);
    semantics.dispose();
  });

  // Section 11: accessibility checks that can be automated.
  testWidgets('meets tap target, label, and contrast guidelines',
      (tester) async {
    final semantics = tester.ensureSemantics();
    backend
      ..seed('Plan tests')
      ..seed('Write report', completed: true);
    await pumpScreen(tester);

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    semantics.dispose();
  });

  // Sections 11 and 12: larger text and a small screen must not overflow.
  testWidgets('works on a small screen with 2x text', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    backend.seed('A fairly long task title that needs to wrap on small phones');
    await pumpScreen(tester);

    expect(tester.takeException(), isNull);
    expect(find.textContaining('A fairly long task title'), findsOneWidget);
  });
}
