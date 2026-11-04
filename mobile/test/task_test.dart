import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/models/task.dart';

void main() {
  test('parses a valid task', () {
    final task = Task.fromJson({'id': 'task-1', 'title': 'Plan tests'});

    expect(task.id, 'task-1');
    expect(task.title, 'Plan tests');
    expect(task.completed, isFalse);
  });

  test('rejects an empty title', () {
    expect(
      () => Task.fromJson({'id': 'task-1', 'title': '  '}),
      throwsFormatException,
    );
  });

  // Practice exercise (section 4): missing ID and maximum-length title.
  test('rejects a missing id', () {
    expect(
      () => Task.fromJson({'title': 'Plan tests'}),
      throwsFormatException,
    );
  });

  test('accepts a title at the maximum allowed length (120)', () {
    final title = 'a' * 120;
    final task = Task.fromJson({'id': 'task-1', 'title': title});
    expect(task.title.length, 120);
  });

  test('parses the completed flag', () {
    final task =
        Task.fromJson({'id': 'task-1', 'title': 'Done', 'completed': true});
    expect(task.completed, isTrue);
  });

  test('rejects wrong types from an unexpected API response', () {
    expect(() => Task.fromJson({'id': 1, 'title': 'x'}), throwsFormatException);
    expect(() => Task.fromJson({'id': 'a', 'title': 42}), throwsFormatException);
    expect(
      () => Task.fromJson({'id': 'a', 'title': 'x', 'completed': 'yes'}),
      throwsFormatException,
    );
  });

  test('copyWith keeps the id', () {
    const task = Task(id: 'task-1', title: 'Old');
    final updated = task.copyWith(title: 'New', completed: true);
    expect(updated.id, 'task-1');
    expect(updated.title, 'New');
    expect(updated.completed, isTrue);
  });
}
