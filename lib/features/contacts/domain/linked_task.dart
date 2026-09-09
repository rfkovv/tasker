/// A task linked to a contact, as surfaced by contact expansion. A deliberately
/// small projection of the tasks domain so the contacts feature never imports
/// the tasks feature (the features must stay acyclic).
class LinkedTask {
  const LinkedTask({required this.id, required this.title, this.dueAt});

  final String id;
  final String title;
  final DateTime? dueAt;
}