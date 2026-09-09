import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../local_db/daos/contacts_dao.dart';
import '../../../local_db/daos/tasks_dao.dart';
import '../../../local_db/providers/database_provider.dart';
import '../domain/linked_task.dart';

part 'active_tasks_for_contact_provider.g.dart';

/// ACTIVE (not done) tasks linked to [contactId], newest first.
///
/// Lives in the contacts feature (not tasks) so the two features stay acyclic:
/// it reads the shared DAOs directly and surfaces only a small [LinkedTask]
/// projection.
@riverpod
Stream<List<LinkedTask>> activeTasksForContact(Ref ref, String contactId) {
  final database = ref.watch(databaseProvider);
  return _activeTasksForContact(database.tasksDao, database.contactsDao, contactId);
}

Stream<List<LinkedTask>> _activeTasksForContact(
  TasksDao tasksDao,
  ContactsDao contactsDao,
  String contactId,
) async* {
  yield* tasksDao.watchAllTasks().asyncMap((rows) async {
    final linked = await contactsDao.taskIdsForContact(contactId);
    if (linked.isEmpty || rows.isEmpty) return const <LinkedTask>[];
    final linkedSet = linked.toSet();
    final active = <LinkedTask>[];
    for (final row in rows) {
      if (!linkedSet.contains(row.id)) continue;
      if (row.status == doneStatus) continue;
      active.add(
        LinkedTask(
          id: row.id,
          title: row.title,
          dueAt: row.dueDate == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(row.dueDate!),
        ),
      );
    }
    active.sort((a, b) {
      final ad = a.dueAt;
      final bd = b.dueAt;
      if (ad == null && bd == null) return 0;
      if (ad == null) return 1;
      if (bd == null) return -1;
      return bd.compareTo(ad);
    });
    return active;
  });
}

const String doneStatus = 'done';