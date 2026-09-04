import 'package:drift/drift.dart';

class TaskDependencies extends Table {
  TextColumn get predecessorId => text()();
  TextColumn get successorId => text()();

  @override
  Set<Column> get primaryKey => {predecessorId, successorId};
}
