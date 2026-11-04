/// A task owned by the signed-in user.
class Task {
  /// Creates a task.
  const Task({required this.id, required this.title, this.completed = false});

  /// Unique server identifier.
  final String id;

  /// User-visible task title.
  final String title;

  /// Whether the task has been marked complete.
  final bool completed;

  /// Parses a task from JSON.
  ///
  /// Throws [FormatException] when required fields are missing or invalid, so a
  /// malformed server response is never shown as if it were real data.
  factory Task.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final title = json['title'];
    final completed = json['completed'] ?? false;

    if (id is! String ||
        id.isEmpty ||
        title is! String ||
        title.trim().isEmpty ||
        completed is! bool) {
      throw const FormatException('Invalid task data.');
    }

    return Task(id: id, title: title, completed: completed);
  }

  /// Returns a copy with the given fields replaced.
  Task copyWith({String? title, bool? completed}) {
    return Task(
      id: id,
      title: title ?? this.title,
      completed: completed ?? this.completed,
    );
  }
}
