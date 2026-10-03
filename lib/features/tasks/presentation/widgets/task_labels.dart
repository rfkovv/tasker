import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/task_status.dart';

/// Human-readable label for a [TaskStatus] (l10n).
String taskStatusLabel(BuildContext context, TaskStatus status) {
  final l10n = AppLocalizations.of(context);
  return switch (status) {
    TaskStatus.todo => l10n.statusTodo,
    TaskStatus.inProgress => l10n.statusInProgress,
    TaskStatus.done => l10n.statusDone,
  };
}
