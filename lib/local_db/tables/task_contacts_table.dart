import 'package:drift/drift.dart';

import 'tasks_table.dart';
import 'contacts_table.dart';

class TaskContacts extends Table {
  TextColumn get taskId => text().references(Tasks, #id)();
  TextColumn get contactId => text().references(Contacts, #id)();

  @override
  Set<Column> get primaryKey => {taskId, contactId};
}
