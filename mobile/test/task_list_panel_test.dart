import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/widgets/task_list_panel.dart';

void main() {
  testWidgets('shows loading state', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TaskListPanel(loading: true, tasks: []),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows empty state', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TaskListPanel(loading: false, tasks: []),
      ),
    );

    expect(find.text('No tasks yet.'), findsOneWidget);
  });

  testWidgets('shows error state', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TaskListPanel(
          loading: false,
          tasks: [],
          errorMessage: 'Could not load tasks.',
        ),
      ),
    );

    expect(find.text('Could not load tasks.'), findsOneWidget);
  });

  testWidgets('shows task data', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TaskListPanel(loading: false, tasks: ['Plan tests']),
      ),
    );

    expect(find.text('Plan tests'), findsOneWidget);
  });

  // Practice exercise (section 5): retry button invokes the callback exactly once.
  testWidgets('tapping retry invokes the callback exactly once', (tester) async {
    var retries = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: TaskListPanel(
          loading: false,
          tasks: const [],
          errorMessage: 'Could not load tasks.',
          onRetry: () => retries++,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('retry-button')));
    await tester.pump();

    expect(retries, 1);
  });

  testWidgets('hides the retry button when no callback is given',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TaskListPanel(
          loading: false,
          tasks: [],
          errorMessage: 'Could not load tasks.',
        ),
      ),
    );

    expect(find.byKey(const Key('retry-button')), findsNothing);
  });

  testWidgets('loading wins over error and data', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TaskListPanel(
          loading: true,
          tasks: ['Plan tests'],
          errorMessage: 'Could not load tasks.',
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Plan tests'), findsNothing);
    expect(find.text('Could not load tasks.'), findsNothing);
  });
}
