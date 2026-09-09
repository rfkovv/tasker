import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskmaster/features/contacts/contacts.dart' as contacts_feature;
import 'package:taskmaster/features/contacts/domain/contact.dart';
import 'package:taskmaster/features/contacts/domain/contact_repository.dart';
import 'package:taskmaster/features/tasks/data/comment_repository_provider.dart';
import 'package:taskmaster/features/tasks/data/subtask_repository_provider.dart';
import 'package:taskmaster/features/tasks/data/task_repository_provider.dart';
import 'package:taskmaster/features/tasks/domain/comment.dart';
import 'package:taskmaster/features/tasks/domain/comment_repository.dart';
import 'package:taskmaster/features/tasks/domain/subtask.dart';
import 'package:taskmaster/features/tasks/domain/subtask_repository.dart';
import 'package:taskmaster/features/tasks/domain/task.dart';
import 'package:taskmaster/features/tasks/domain/task_filter.dart';
import 'package:taskmaster/features/tasks/domain/task_priority.dart';
import 'package:taskmaster/features/tasks/domain/task_repository.dart';
import 'package:taskmaster/features/tasks/domain/task_status.dart';
import 'package:taskmaster/features/tasks/presentation/screens/task_detail_screen.dart';
import 'package:taskmaster/l10n/app_localizations.dart';

class _ChangeStream<T> {
  _ChangeStream(this._current);

  T _current;
  late final StreamController<T> _controller =
      StreamController<T>.broadcast(onListen: _emitInitial);

  void _emitInitial() {
    if (!_controller.isClosed) _controller.add(_current);
  }

  void update(T value) {
    _current = value;
    if (!_controller.isClosed) _controller.add(value);
  }

  Stream<T> get stream => _controller.stream;

  void close() => _controller.close();
}

class FakeTaskRepository implements TaskRepository {
  FakeTaskRepository(List<Task> tasks)
      : _tasks = List.of(tasks),
        _tracker = _ChangeStream<List<Task>>(List.of(tasks));

  final List<Task> _tasks;
  final _ChangeStream<List<Task>> _tracker;

  @override
  Stream<List<Task>> watchAll({TaskFilter filter = TaskFilter.none}) {
    return _tracker.stream.map(
      (all) => all
          .where((t) => filter.status == null || t.status == filter.status)
          .toList(),
    );
  }

  @override
  Stream<Task?> watchById(String id) {
    return _tracker.stream.map(
      (all) {
        for (final t in all) {
          if (t.id == id) return t;
        }
        return null;
      },
    );
  }

  @override
  Future<Task> create(Task task) async {
    _tasks.add(task);
    _tracker.update(List.of(_tasks));
    return task;
  }

  @override
  Future<Task> createWithContacts(Task task, List<String> contactIds) async {
    _tasks.add(task);
    _tracker.update(List.of(_tasks));
    return task;
  }

  @override
  Future<void> update(Task task) async {
    final index = _tasks.indexWhere((t) => t.id == task.id);
    if (index != -1) _tasks[index] = task;
    _tracker.update(List.of(_tasks));
  }

  @override
  Future<void> updateStatus(String id, TaskStatus status) async {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index != -1) {
      _tasks[index] = _tasks[index].copyWith(status: status);
    }
    _tracker.update(List.of(_tasks));
  }

  @override
  Future<void> delete(String id) async {
    _tasks.removeWhere((t) => t.id == id);
    _tracker.update(List.of(_tasks));
  }
}

class FakeSubtaskRepository implements SubtaskRepository {
  FakeSubtaskRepository([List<Subtask>? initial])
      : _subtasks = Map.fromEntries(
          (initial ?? const [])
              .map((s) => MapEntry(s.id, s))
              .toList(),
        ),
        _tracker = _ChangeStream<List<Subtask>>(initial ?? const []);

  final Map<String, Subtask> _subtasks;
  final _ChangeStream<List<Subtask>> _tracker;
  final createdTitles = <String>[];
  final toggled = <(String, bool)>[];
  final deletedIds = <String>[];

  void _currentSnapshot() {
    _tracker.update(_subtasks.values.toList());
  }

  @override
  Stream<List<Subtask>> watchByTask(String taskId) {
    return _tracker.stream.map(
      (all) => all.where((s) => s.taskId == taskId).toList(),
    );
  }

  @override
  Future<Subtask> create({required String taskId, required String title}) async {
    createdTitles.add(title);
    final now = DateTime.now();
    final subtask = Subtask(
      id: 'new-$title',
      taskId: taskId,
      title: title,
      createdAt: now,
      updatedAt: now,
    );
    _subtasks[subtask.id] = subtask;
    _currentSnapshot();
    return subtask;
  }

  @override
  Future<void> toggle(String id, {required bool isCompleted}) async {
    toggled.add((id, isCompleted));
    final current = _subtasks[id];
    if (current != null) {
      _subtasks[id] = current.copyWith(isCompleted: isCompleted);
    }
    _currentSnapshot();
  }

  @override
  Future<void> delete(String id) async {
    deletedIds.add(id);
    _subtasks.remove(id);
    _currentSnapshot();
  }
}

class FakeCommentRepository implements CommentRepository {
  FakeCommentRepository([List<Comment>? initial])
      : _comments = Map.fromEntries(
          (initial ?? const [])
              .map((c) => MapEntry(c.id, c))
              .toList(),
        ),
        _tracker = _ChangeStream<List<Comment>>(initial ?? const []);

  final Map<String, Comment> _comments;
  final _ChangeStream<List<Comment>> _tracker;
  final createdBodies = <String>[];
  final deletedIds = <String>[];

  void _currentSnapshot() {
    _tracker.update(_comments.values.toList());
  }

  @override
  Stream<List<Comment>> watchByTask(String taskId) {
    return _tracker.stream.map(
      (all) => all.where((c) => c.taskId == taskId).toList(),
    );
  }

  @override
  Future<Comment> create({required String taskId, required String body}) async {
    createdBodies.add(body);
    final comment = Comment(
      id: 'new-$body',
      taskId: taskId,
      body: body,
      createdAt: DateTime.now(),
    );
    _comments[comment.id] = comment;
    _currentSnapshot();
    return comment;
  }

  @override
  Future<void> delete(String id) async {
    deletedIds.add(id);
    _comments.remove(id);
    _currentSnapshot();
  }
}

class FakeContactRepository implements ContactRepository {
  @override
  Stream<List<Contact>> watchAll({String? nameFilter}) => const Stream.empty();

  @override
  Stream<Contact?> watchById(String id) async* {}

  @override
  Future<Contact> create({
    required String name,
    String? role,
    String? email,
    String? phone,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> update(Contact contact) async {}

  @override
  Future<void> delete(String id) async {}

  @override
  Future<List<Contact>> contactsForTask(String taskId) async => const [];

  @override
  Future<Map<String, List<Contact>>> contactsByTaskIds(
      List<String> taskIds) async {
    return const {};
  }

  @override
  Future<void> replaceContactsForTask(
      String taskId, List<String> contactIds) async {}
}

Task buildTask({
  String? id,
  String title = 'Task',
  String? description,
  TaskStatus status = TaskStatus.todo,
  DateTime? dueDate,
}) {
  final now = DateTime.now();
  return Task(
    id: id ?? 'id',
    title: title,
    description: description,
    priority: TaskPriority.medium,
    status: status,
    dueDate: dueDate,
    createdAt: now,
    updatedAt: now,
  );
}

Subtask buildSubtask({
  required String id,
  required String taskId,
  required String title,
  bool isCompleted = false,
}) {
  final now = DateTime.now();
  return Subtask(
    id: id,
    taskId: taskId,
    title: title,
    isCompleted: isCompleted,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  late FakeTaskRepository taskRepo;
  late FakeSubtaskRepository subtaskRepo;
  late FakeCommentRepository commentRepo;
  String? editedId;

  Widget buildApp(String taskId, {List<Subtask>? subtasks}) {
    return ProviderScope(
      overrides: [
        taskRepositoryProvider.overrideWithValue(taskRepo),
        subtaskRepositoryProvider.overrideWithValue(subtaskRepo),
        commentRepositoryProvider.overrideWithValue(commentRepo),
        contacts_feature.contactRepositoryProvider
            .overrideWithValue(FakeContactRepository()),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TaskDetailScreen(
          taskId: taskId,
          onEdit: (id) => editedId = id,
        ),
      ),
    );
  }

  const taskId = 't1';

  setUp(() {
    editedId = null;
    taskRepo = FakeTaskRepository([
      buildTask(id: taskId, title: 'My Task', description: 'Some details'),
    ]);
    subtaskRepo = FakeSubtaskRepository();
    commentRepo = FakeCommentRepository();
  });

  testWidgets('renders task header, description, status and priority',
      (tester) async {
    await tester.pumpWidget(buildApp(taskId));
    await tester.pumpAndSettle();

    expect(find.text('My Task'), findsWidgets);
    expect(find.text('Some details'), findsOneWidget);
    expect(find.text('To Do'), findsOneWidget);
    expect(find.text('Medium'), findsOneWidget);
  });

  testWidgets('shows subtasks with progress and checkboxes', (tester) async {
    subtaskRepo = FakeSubtaskRepository([
      buildSubtask(id: 's1', taskId: taskId, title: 'First', isCompleted: true),
      buildSubtask(id: 's2', taskId: taskId, title: 'Second'),
    ]);

    await tester.pumpWidget(buildApp(taskId));
    await tester.pumpAndSettle();

    expect(find.text('Subtasks'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);
    expect(find.text('First'), findsOneWidget);
    expect(find.text('Second'), findsOneWidget);
  });

  testWidgets('adding a subtask calls the repository', (tester) async {
    await tester.pumpWidget(buildApp(taskId));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Type a subtask and press Enter...'),
      'New subtask',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(subtaskRepo.createdTitles, ['New subtask']);
    expect(find.text('New subtask'), findsOneWidget);
  });

  testWidgets('toggling a subtask checkbox calls toggle', (tester) async {
    subtaskRepo = FakeSubtaskRepository([
      buildSubtask(id: 's1', taskId: taskId, title: 'First'),
    ]);

    await tester.pumpWidget(buildApp(taskId));
    await tester.pumpAndSettle();

    final checkbox = find.byType(Checkbox);
    await tester.tap(checkbox);
    await tester.pumpAndSettle();

    expect(subtaskRepo.toggled, [('s1', true)]);
  });

  testWidgets('deleting a subtask calls delete', (tester) async {
    subtaskRepo = FakeSubtaskRepository([
      buildSubtask(id: 's1', taskId: taskId, title: 'First'),
    ]);

    await tester.pumpWidget(buildApp(taskId));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();

    expect(subtaskRepo.deletedIds, ['s1']);
  });

  testWidgets('shows comments with timestamps', (tester) async {
    commentRepo = FakeCommentRepository([
      Comment(
        id: 'c1',
        taskId: taskId,
        body: 'Looks good',
        createdAt: DateTime(2026, 9, 9, 14, 30),
      ),
    ]);

    await tester.pumpWidget(buildApp(taskId));
    await tester.pumpAndSettle();

    expect(find.text('Comments'), findsOneWidget);
    expect(find.text('Looks good'), findsOneWidget);
    expect(find.textContaining('14:30'), findsOneWidget);
  });

  testWidgets('adding a comment calls the repository', (tester) async {
    await tester.pumpWidget(buildApp(taskId));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Write a comment...'),
      'Nice work',
    );
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();

    expect(commentRepo.createdBodies, ['Nice work']);
    expect(find.text('Nice work'), findsOneWidget);
  });

  testWidgets('deleting a comment calls delete', (tester) async {
    commentRepo = FakeCommentRepository([
      Comment(
        id: 'c1',
        taskId: taskId,
        body: 'Remove me',
        createdAt: DateTime(2026, 9, 9, 9, 0),
      ),
    ]);

    await tester.pumpWidget(buildApp(taskId));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();

    expect(commentRepo.deletedIds, ['c1']);
  });

  testWidgets('edit button invokes onEdit', (tester) async {
    await tester.pumpWidget(buildApp(taskId));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    expect(editedId, taskId);
  });

  testWidgets('status toggle marks task done and back', (tester) async {
    await tester.pumpWidget(buildApp(taskId));
    await tester.pumpAndSettle();
    await tester.pump();

    expect(find.text('Mark done'), findsOneWidget);
    await tester.tap(find.text('Mark done'));
    await tester.pumpAndSettle();

    expect(taskRepo._tasks.single.status, TaskStatus.done);
    expect(find.text('Back to to-do'), findsOneWidget);

    await tester.tap(find.text('Back to to-do'));
    await tester.pumpAndSettle();

    expect(taskRepo._tasks.single.status, TaskStatus.todo);
  });

  testWidgets('shows relevant persons label when none linked', (tester) async {
    await tester.pumpWidget(buildApp(taskId));
    await tester.pumpAndSettle();

    expect(find.text('Relevant Persons'), findsOneWidget);
    expect(find.text('No contacts linked'), findsOneWidget);
  });
}