enum TaskStatus {
  todo('todo'),
  inProgress('inProgress'),
  done('done');

  const TaskStatus(this.dbValue);

  final String dbValue;

  static TaskStatus fromDbValue(String value) {
    return TaskStatus.values.firstWhere(
      (s) => s.dbValue == value,
      orElse: () => TaskStatus.todo,
    );
  }
}
