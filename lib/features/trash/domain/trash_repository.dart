import 'dart:async';

import '../../contacts/domain/contact.dart';
import '../../tasks/domain/task.dart';

/// Recoverable-deletion surface for the Kosz destination.
///
/// Trash is NOT a separate physical table — it is the set of rows whose
/// `deletedAt != null`. This repository exposes those rows and the two
/// manual operations allowed in the app:
/// - [restoreTask] / [restoreContact] — clear `deletedAt` (restore).
/// - [emptyTrash] — hard-DELETE every soft-deleted row (the only
///   irreversible action in the app; manual only, never automatic).
abstract class TrashRepository {
  /// Soft-deleted tasks, newest first.
  Stream<List<Task>> watchDeletedTasks();

  /// Soft-deleted contacts, newest first.
  Stream<List<Contact>> watchDeletedContacts();

  /// Restores [id] and every currently-deleted row referencing it
  /// (comments). Clears `deletedAt` and bumps `updatedAt` on all
  /// restored rows in one transaction.
  Future<void> restoreTask(String id);

  /// Restores the contact [id] (clears `deletedAt`, bumps `updatedAt`).
  /// task_contacts links are untouched — linked tasks are NOT resurrected.
  Future<void> restoreContact(String id);

  /// Hard-DELETEs all soft-deleted rows (tasks, contacts, comments) and
  /// their dangling references in one transaction. Manual only.
  Future<void> emptyTrash();
}
