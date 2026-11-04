import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../validation.dart';

/// Dialog to create or rename a task. It performs the save itself so it can:
/// * ignore rapid repeated taps (no duplicate tasks), and
/// * stay open with the typed text when saving fails (no data loss offline).
class TaskEditorDialog extends StatefulWidget {
  /// Creates the dialog.
  const TaskEditorDialog({super.key, this.initialTitle, required this.onSave});

  /// Current title when editing; `null` when creating.
  final String? initialTitle;

  /// Persists the validated, trimmed title. Throw [ApiException] to show an error.
  final Future<void> Function(String title) onSave;

  @override
  State<TaskEditorDialog> createState() => _TaskEditorDialogState();
}

class _TaskEditorDialogState extends State<TaskEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialTitle);
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    // Set synchronously so a second tap in the same frame is ignored.
    if (_saving) {
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    _saving = true;
    setState(() => _error = null);

    try {
      await widget.onSave(_controller.text.trim());
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.initialTitle != null;
    return AlertDialog(
      title: Text(editing ? 'Edit task' : 'New task'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              key: const Key('task-title-field'),
              controller: _controller,
              autofocus: true,
              maxLength: titleMaxLength,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(labelText: 'Title'),
              validator: validateTitle,
              onFieldSubmitted: (_) => _save(),
            ),
            if (_error != null)
              Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  key: const Key('task-save-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('cancel-task-button'),
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('save-task-button'),
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    semanticsLabel: 'Saving',
                  ),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
