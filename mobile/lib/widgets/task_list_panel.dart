import 'package:flutter/material.dart';

/// Shows tasks or the current loading, empty, or error state.
class TaskListPanel extends StatelessWidget {
  /// Creates a task list panel.
  const TaskListPanel({
    super.key,
    required this.loading,
    required this.tasks,
    this.errorMessage,
    this.onRetry,
    this.itemBuilder,
  });

  /// Whether tasks are being loaded.
  final bool loading;

  /// Task titles to display.
  final List<String> tasks;

  /// Optional safe error message.
  final String? errorMessage;

  /// Called when the user taps "Try again" in the error state.
  final VoidCallback? onRetry;

  /// Optional custom row builder; defaults to a plain [ListTile] with the title.
  final IndexedWidgetBuilder? itemBuilder;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(semanticsLabel: 'Loading tasks'),
      );
    }
    if (errorMessage != null) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(errorMessage!, textAlign: TextAlign.center),
              if (onRetry != null) ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  key: const Key('retry-button'),
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try again'),
                ),
              ],
            ],
          ),
        ),
      );
    }
    if (tasks.isEmpty) {
      return const Center(child: Text('No tasks yet.'));
    }
    return ListView.builder(
      // Leaves room so the floating "Add task" button never covers the last row.
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: tasks.length,
      itemBuilder: itemBuilder ??
          (context, index) => ListTile(title: Text(tasks[index])),
    );
  }
}
