enum TaskPriority {
  low('low'),
  medium('medium'),
  high('high'),
  urgent('urgent');

  const TaskPriority(this.dbValue);

  final String dbValue;

  static TaskPriority fromDbValue(String value) {
    return TaskPriority.values.firstWhere(
      (p) => p.dbValue == value,
      orElse: () => TaskPriority.medium,
    );
  }
}
