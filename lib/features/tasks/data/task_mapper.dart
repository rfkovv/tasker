import 'package:drift/drift.dart';

import '../../../local_db/database.dart' as db;
import '../domain/task.dart' as domain;
import '../domain/task_priority.dart';
import '../domain/task_status.dart';

class TaskMapper {
  domain.Task toDomain(db.Task row, List<db.Tag> tags) {
    return domain.Task(
      id: row.id,
      title: row.title,
      description: row.description,
      tags: tags.map((t) => t.name).toList(),
      priority: TaskPriority.fromDbValue(row.priority),
      dueDate: row.dueDate != null
          ? DateTime.fromMillisecondsSinceEpoch(row.dueDate!)
          : null,
      status: TaskStatus.fromDbValue(row.status),
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
      deletedAt: row.deletedAt != null
          ? DateTime.fromMillisecondsSinceEpoch(row.deletedAt!)
          : null,
    );
  }

  db.TasksCompanion toCompanion(
    domain.Task task, {
    required String ownerId,
  }) {
    return db.TasksCompanion(
      id: Value(task.id),
      title: Value(task.title),
      description: Value(task.description),
      priority: Value(task.priority.dbValue),
      status: Value(task.status.dbValue),
      dueDate: Value(task.dueDate?.millisecondsSinceEpoch),
      startDate: const Value(null),
      ownerId: Value(ownerId),
      createdAt: Value(task.createdAt.millisecondsSinceEpoch),
      updatedAt: Value(task.updatedAt.millisecondsSinceEpoch),
      deletedAt: Value(task.deletedAt?.millisecondsSinceEpoch),
    );
  }
}
