import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import '../../../contacts/domain/contact.dart';
import '../../data/task_repository_provider.dart';
import '../../domain/task.dart';
import '../../domain/task_priority.dart';
import '../../domain/task_status.dart';

part 'task_form_provider.g.dart';

class TaskFormState {
  const TaskFormState({
    this.title = '',
    this.description = '',
    this.tags = const [],
    this.priority = TaskPriority.medium,
    this.dueDate,
    this.contactIds = const [],
    this.draftContacts = const [],
  });

  factory TaskFormState.initial() => const TaskFormState();

  final String title;
  final String description;
  final List<String> tags;
  final TaskPriority priority;
  final DateTime? dueDate;

  /// Pending contact ids for a task being created.
  final List<String> contactIds;

  /// Contacts created inline during this session (not yet in DB watch).
  final List<Contact> draftContacts;

  TaskFormState copyWith({
    String? title,
    String? description,
    List<String>? tags,
    TaskPriority? priority,
    DateTime? dueDate,
    bool clearDueDate = false,
    List<String>? contactIds,
    List<Contact>? draftContacts,
  }) {
    return TaskFormState(
      title: title ?? this.title,
      description: description ?? this.description,
      tags: tags ?? this.tags,
      priority: priority ?? this.priority,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      contactIds: contactIds ?? this.contactIds,
      draftContacts: draftContacts ?? this.draftContacts,
    );
  }
}

@riverpod
class TaskForm extends _$TaskForm {
  @override
  TaskFormState build(Task? task) {
    if (task == null) return TaskFormState.initial();
    return TaskFormState(
      title: task.title,
      description: task.description ?? '',
      tags: task.tags,
      priority: task.priority,
      dueDate: task.dueDate,
    );
  }

  void setTitle(String value) => state = state.copyWith(title: value);

  void setDescription(String value) =>
      state = state.copyWith(description: value);

  void setDueDate(DateTime? value) =>
      state = state.copyWith(dueDate: value, clearDueDate: value == null);

  void setPriority(TaskPriority value) =>
      state = state.copyWith(priority: value);

  void toggleTag(String tag) {
    final tags = List<String>.from(state.tags);
    if (tags.contains(tag)) {
      tags.remove(tag);
    } else {
      tags.add(tag);
    }
    state = state.copyWith(tags: tags);
  }

  void setTags(List<String> tags) => state = state.copyWith(tags: tags);

  void attachContact(String contactId) async {
    if (state.contactIds.contains(contactId)) return;
    state = state.copyWith(
      contactIds: [...state.contactIds, contactId],
    );
  }

  void detachContact(String contactId) async {
    state = state.copyWith(
      contactIds: state.contactIds.where((id) => id != contactId).toList(),
      draftContacts:
          state.draftContacts.where((c) => c.id != contactId).toList(),
    );
  }

  void linkNewContact(Contact contact) async {
    if (state.contactIds.contains(contact.id)) return;
    state = state.copyWith(
      contactIds: [...state.contactIds, contact.id],
      draftContacts: [...state.draftContacts, contact],
    );
  }

  Future<bool> save() async {
    if (state.title.trim().isEmpty) return false;

    final repository = ref.read(taskRepositoryProvider);
    final now = DateTime.now();
    final task = Task(
      id: this.task?.id ?? const Uuid().v4(),
      title: state.title.trim(),
      description: state.description.isNotEmpty ? state.description : null,
      tags: state.tags,
      priority: state.priority,
      dueDate: state.dueDate,
      status: this.task?.status ?? TaskStatus.todo,
      createdAt: this.task?.createdAt ?? now,
      updatedAt: now,
      deletedAt: this.task?.deletedAt,
    );

    if (this.task == null) {
      if (state.contactIds.isEmpty) {
        await repository.create(task);
      } else {
        await repository.createWithContacts(task, state.contactIds);
      }
    } else {
      await repository.update(task);
    }
    return true;
  }
}
