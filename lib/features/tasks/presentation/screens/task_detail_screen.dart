import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../contacts/contacts.dart' as contacts_feature;
import '../../../../l10n/app_localizations.dart';

import '../../data/comment_repository_provider.dart';
import '../../data/subtask_repository_provider.dart';
import '../../data/task_repository_provider.dart';
import '../../domain/comment.dart';
import '../../domain/subtask.dart';
import '../../domain/task.dart';
import '../../domain/task_status.dart';
import '../providers/comment_list_provider.dart';
import '../providers/subtask_list_provider.dart';
import '../providers/task_contacts_provider.dart';
import '../providers/task_list_provider.dart';
import '../widgets/task_priority_badge.dart';
import 'task_list_screen.dart' show taskStatusLabel;

class TaskDetailScreen extends ConsumerStatefulWidget {
  const TaskDetailScreen({super.key, required this.taskId, this.onEdit});

  final String taskId;
  final ValueChanged<String>? onEdit;

  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen> {
  final _subtaskController = TextEditingController();
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _subtaskController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _addSubtask() async {
    final title = _subtaskController.text.trim();
    if (title.isEmpty) return;
    final repo = ref.read(subtaskRepositoryProvider);
    await repo.create(taskId: widget.taskId, title: title);
    _subtaskController.clear();
  }

  Future<void> _addComment() async {
    final body = _commentController.text.trim();
    if (body.isEmpty) return;
    final repo = ref.read(commentRepositoryProvider);
    await repo.create(taskId: widget.taskId, body: body);
    _commentController.clear();
  }

  Future<void> _toggleStatus(Task task) async {
    final next = task.isDone ? TaskStatus.todo : TaskStatus.done;
    await ref
        .read(taskRepositoryProvider)
        .updateStatus(widget.taskId, next);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final taskAsync = ref.watch(watchTaskByIdProvider(widget.taskId));
    final subtasksAsync = ref.watch(subtaskListProvider(widget.taskId));
    final commentsAsync = ref.watch(commentListProvider(widget.taskId));
    final contactsAsync =
        ref.watch(taskContactsManagerProvider(widget.taskId));

    return Scaffold(
      appBar: AppBar(
        title: taskAsync.value?.title != null
            ? Text(taskAsync.value!.title)
            : const SizedBox.shrink(),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: taskAsync.when(
              data: (task) {
                if (task == null) {
                  return Center(child: Text(l10n.taskNotFound));
                }
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TaskHeader(task: task),
                      if (task.description?.isNotEmpty ?? false) ...[
                        const SizedBox(height: 16),
                        Text(
                          task.description!,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                      if (task.dueDate != null) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 16,
                              color: task.isOverdue
                                  ? Theme.of(context).colorScheme.error
                                  : Theme.of(context).colorScheme.outline,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _formatDateTime(context, task.dueDate!),
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                color: task.isOverdue
                                    ? Theme.of(context).colorScheme.error
                                    : null,
                                fontWeight: task.isOverdue
                                    ? FontWeight.w600
                                    : null,
                              ),
                            ),
                            if (task.isOverdue) ...[
                              const SizedBox(width: 8),
                              Text(
                                l10n.overdue,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .error,
                                    ),
                              ),
                            ],
                          ],
                        ),
                      ],
                      if (task.tags.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            for (final tag in task.tags)
                              Chip(label: Text(tag)),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      const Divider(),
                      _SubtasksSection(
                        taskId: widget.taskId,
                        subtasksAsync: subtasksAsync,
                        controller: _subtaskController,
                        onAdd: _addSubtask,
                        onToggle: (id, done) async =>
                            ref
                                .read(subtaskRepositoryProvider)
                                .toggle(id, isCompleted: done),
                        onDelete: (id) async =>
                            ref.read(subtaskRepositoryProvider).delete(id),
                      ),
                      const Divider(),
                      _CommentsSection(
                        taskId: widget.taskId,
                        commentsAsync: commentsAsync,
                        controller: _commentController,
                        onAdd: _addComment,
                        onDelete: (id) async =>
                            ref.read(commentRepositoryProvider).delete(id),
                      ),
                      const Divider(),
                      _RelevantPersonsSection(contactsAsync: contactsAsync),
                    ],
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(l10n.errorWithValue(e.toString())),
              ),
            ),
          ),
          const Divider(height: 1),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: taskAsync.value == null
                        ? null
                        : () => _toggleStatus(taskAsync.value!),
                    icon: Icon(
                      taskAsync.value?.isDone == true
                          ? Icons.replay
                          : Icons.check,
                    ),
                    label: Text(
                      taskAsync.value?.isDone == true
                          ? l10n.markTodo
                          : l10n.markDone,
                    ),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: () => widget.onEdit?.call(widget.taskId),
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(l10n.edit),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(BuildContext context, DateTime date) {
    final l10n = AppLocalizations.of(context);
    final local = date.toLocal();
    final months = [
      l10n.monthJan,
      l10n.monthFeb,
      l10n.monthMar,
      l10n.monthApr,
      l10n.monthMay,
      l10n.monthJun,
      l10n.monthJul,
      l10n.monthAug,
      l10n.monthSep,
      l10n.monthOct,
      l10n.monthNov,
      l10n.monthDec,
    ];
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '${months[local.month - 1]} ${local.day}, $hh:$mm';
  }
}

class _TaskHeader extends StatelessWidget {
  const _TaskHeader({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          child: Text(
            task.title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        const SizedBox(width: 12),
        TaskPriorityBadge(priority: task.priority),
        const SizedBox(width: 8),
        _StatusBadge(status: task.status),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final TaskStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (status) {
      TaskStatus.todo => scheme.outline,
      TaskStatus.inProgress => scheme.tertiary,
      TaskStatus.done => scheme.primary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        taskStatusLabel(context, status),
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _SubtasksSection extends StatelessWidget {
  const _SubtasksSection({
    required this.taskId,
    required this.subtasksAsync,
    required this.controller,
    required this.onAdd,
    required this.onToggle,
    required this.onDelete,
  });

  final String taskId;
  final AsyncValue<List<Subtask>> subtasksAsync;
  final TextEditingController controller;
  final Future<void> Function() onAdd;
  final Future<void> Function(String id, bool done) onToggle;
  final Future<void> Function(String id) onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        subtasksAsync.when(
          data: (subtasks) {
            final progress = SubtaskProgress.fromSubtasks(subtasks);
            return Row(
              children: [
                Text(l10n.subtasks, style: theme.textTheme.titleSmall),
                if (subtasks.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    l10n.subtaskProgress(progress.done, progress.total),
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
                ],
              ],
            );
          },
          loading: () => Text(l10n.subtasks, style: theme.textTheme.titleSmall),
          error: (e, _) => Text(l10n.errorWithValue(e.toString())),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: l10n.subtaskHint,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          onSubmitted: (_) => onAdd(),
        ),
        const SizedBox(height: 8),
        subtasksAsync.when(
          data: (subtasks) => subtasks.isEmpty
              ? Text(
                  l10n.noSubtasks,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.outline),
                )
              : Column(
                  children: [
                    for (final subtask in subtasks)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        leading: Checkbox(
                          value: subtask.isCompleted,
                          onChanged: (v) => onToggle(subtask.id, v ?? false),
                        ),
                        title: Text(
                          subtask.title,
                          style: subtask.isCompleted
                              ? theme.textTheme.bodyMedium?.copyWith(
                                  decoration: TextDecoration.lineThrough,
                                  color: theme.colorScheme.outline,
                                )
                              : theme.textTheme.bodyMedium,
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          tooltip: l10n.delete,
                          onPressed: () => onDelete(subtask.id),
                        ),
                      ),
                  ],
                ),
          loading: () => const SizedBox(
            height: 40,
            child: Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          error: (e, _) => Text(l10n.errorWithValue(e.toString())),
        ),
      ],
    );
  }
}

class _CommentsSection extends StatefulWidget {
  const _CommentsSection({
    required this.taskId,
    required this.commentsAsync,
    required this.controller,
    required this.onAdd,
    required this.onDelete,
  });

  final String taskId;
  final AsyncValue<List<Comment>> commentsAsync;
  final TextEditingController controller;
  final Future<void> Function() onAdd;
  final Future<void> Function(String id) onDelete;

  @override
  State<_CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends State<_CommentsSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.comments, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        widget.commentsAsync.when(
          data: (comments) {
            if (comments.isEmpty) {
              return Text(
                l10n.noComments,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.outline),
              );
            }
            final visible = _visibleComments(comments);
            final commentTiles = [
              for (final comment in visible)
                _CommentTile(
                  key: ValueKey(comment.id),
                  comment: comment,
                  onDelete: widget.onDelete,
                ),
            ];
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_expanded)
                  SizedBox(
                    height: 300,
                    child: ListView(
                      shrinkWrap: true,
                      children: commentTiles,
                    ),
                  )
                else
                  ...commentTiles,
                if (comments.length > 3)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () =>
                          setState(() => _expanded = !_expanded),
                      child: Text(
                        _expanded
                            ? l10n.showRecentOnly
                            : l10n.showAllComments(
                                comments.length.toString()),
                      ),
                    ),
                  ),
              ],
            );
          },
          loading: () => const SizedBox(
            height: 40,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (e, _) => Text(l10n.errorWithValue(e.toString())),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: widget.controller,
                decoration: InputDecoration(
                  hintText: l10n.commentHint,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => widget.onAdd(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              icon: const Icon(Icons.send),
              tooltip: l10n.addComment,
              onPressed: widget.onAdd,
            ),
          ],
        ),
      ],
    );
  }

  List<Comment> _visibleComments(List<Comment> all) {
    if (_expanded || all.length <= 3) return all;
    return all.sublist(all.length - 3);
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({super.key, required this.comment, required this.onDelete});

  final Comment comment;
  final Future<void> Function(String id) onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final local = comment.createdAt.toLocal();
    final months = [
      l10n.monthJan,
      l10n.monthFeb,
      l10n.monthMar,
      l10n.monthApr,
      l10n.monthMay,
      l10n.monthJun,
      l10n.monthJul,
      l10n.monthAug,
      l10n.monthSep,
      l10n.monthOct,
      l10n.monthNov,
      l10n.monthDec,
    ];
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(comment.body, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 2),
                Text(
                  '${months[local.month - 1]} ${local.day}, $hh:$mm',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            tooltip: l10n.delete,
            onPressed: () => onDelete(comment.id),
          ),
        ],
      ),
    );
  }
}

class _RelevantPersonsSection extends StatelessWidget {
  const _RelevantPersonsSection({required this.contactsAsync});

  final AsyncValue<List<contacts_feature.Contact>> contactsAsync;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.relevantPersons, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        contactsAsync.when(
          data: (contacts) => contacts.isEmpty
              ? Text(
                  l10n.noContactsLinked,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.outline),
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final contact in contacts)
                      InputChip(
                        avatar: CircleAvatar(
                          child: Text(
                            contact.name.isNotEmpty
                                ? contact.name[0].toUpperCase()
                                : '?',
                          ),
                        ),
                        label: Text(contact.name),
                      ),
                  ],
                ),
          loading: () => const SizedBox(
            height: 24,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (e, _) => Text(l10n.errorWithValue(e.toString())),
        ),
      ],
    );
  }
}