import 'package:flutter/material.dart';

import '../models/task.dart';
import '../services/api_client.dart';
import '../widgets/task_editor_dialog.dart';
import '../widgets/task_list_panel.dart';

/// Shows and manages the signed-in user's tasks.
class TaskListScreen extends StatefulWidget {
  /// Creates the task list screen.
  const TaskListScreen({super.key, required this.api, required this.onSignedOut});

  /// API used to load and change tasks.
  final ApiClient api;

  /// Called after logout or when the session can no longer be refreshed.
  final VoidCallback onSignedOut;

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  List<Task> _tasks = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final tasks = await widget.api.listTasks();
      if (!mounted) return;
      setState(() {
        _tasks = tasks;
        _loading = false;
      });
    } on UnauthorizedException {
      if (mounted) widget.onSignedOut();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  void _replace(Task updated) {
    setState(() {
      _tasks = [for (final t in _tasks) t.id == updated.id ? updated : t];
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _runSafely(Future<void> Function() action) async {
    try {
      await action();
    } on UnauthorizedException {
      if (mounted) widget.onSignedOut();
    } on ApiException catch (error) {
      if (mounted) _showMessage(error.message);
    }
  }

  Future<void> _openEditor([Task? task]) async {
    await showDialog<bool>(
      context: context,
      builder: (_) => TaskEditorDialog(
        initialTitle: task?.title,
        onSave: (title) async {
          if (task == null) {
            final created = await widget.api.createTask(title);
            if (mounted) setState(() => _tasks = [created, ..._tasks]);
          } else {
            _replace(await widget.api.updateTask(task.id, title: title));
          }
        },
      ),
    );
  }

  Future<void> _toggle(Task task, bool completed) {
    // The task stays in the list either way (regression check for BUG-001).
    return _runSafely(() async {
      _replace(await widget.api.updateTask(task.id, completed: completed));
    });
  }

  Future<void> _delete(Task task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete task?'),
        content: Text('"${task.title}" will be removed permanently.'),
        actions: [
          TextButton(
            key: const Key('cancel-delete-button'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirm-delete-button'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _runSafely(() async {
      await widget.api.deleteTask(task.id);
      if (mounted) {
        setState(() => _tasks = _tasks.where((t) => t.id != task.id).toList());
      }
    });
  }

  Future<void> _logout() async {
    await widget.api.logout();
    if (mounted) widget.onSignedOut();
  }

  Widget _buildTask(BuildContext context, int index) {
    final task = _tasks[index];
    final theme = Theme.of(context);
    return CheckboxListTile(
      key: ValueKey('task-${task.id}'),
      controlAffinity: ListTileControlAffinity.leading,
      value: task.completed,
      onChanged: (value) => _toggle(task, value ?? false),
      title: Text(
        task.title,
        style: task.completed
            ? const TextStyle(decoration: TextDecoration.lineThrough)
            : null,
      ),
      // Status in words, so color/strike-through are not the only signal.
      subtitle: Text(
        task.completed ? 'Completed' : 'Pending',
        style: theme.textTheme.bodySmall
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
      secondary: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: Key('edit-${task.id}'),
            tooltip: 'Edit task',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _openEditor(task),
          ),
          IconButton(
            key: Key('delete-${task.id}'),
            tooltip: 'Delete task',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(task),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My tasks'),
        actions: [
          IconButton(
            key: const Key('logout-button'),
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: TaskListPanel(
        loading: _loading,
        tasks: [for (final t in _tasks) t.title],
        errorMessage: _error,
        onRetry: _load,
        itemBuilder: _buildTask,
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add-task-button'),
        onPressed: _loading ? null : () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('Add task'),
      ),
    );
  }
}
