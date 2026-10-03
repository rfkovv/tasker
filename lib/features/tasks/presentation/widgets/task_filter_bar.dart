import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../contacts/contacts.dart' as contacts_feature;
import '../../../../l10n/app_localizations.dart';
import '../../domain/task.dart';
import '../../domain/task_filter.dart';
import '../../domain/task_priority.dart';
import '../../domain/task_status.dart';
import '../providers/task_list_provider.dart';
import 'task_labels.dart';
import 'task_priority_badge.dart';

/// Filter controls for the task list: "Filter" button (dropdown menu)
/// plus active filter/sort badges.
///
/// Used standalone in [TaskListScreen] (desktop / direct usage) and
/// embedded in the unified mobile toolbar on the task board.
class TaskFilterBar extends ConsumerWidget {
  const TaskFilterBar({
    super.key,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    this.embedded = false,
  });

  /// Outer padding. Embedded in the mobile toolbar with
  /// `EdgeInsets.zero` (the toolbar row owns its own padding).
  final EdgeInsetsGeometry padding;

  /// True when placed inside the unified mobile toolbar row next to the
  /// segmented control. The toolbar row lays this widget out with
  /// unbounded main-axis constraints (non-flex slot), so badges must not
  /// use [Expanded] — they are width-capped instead. Desktop / standalone
  /// usage keeps `false` (pixel-identical full-width summary chip).
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final filter = ref.watch(taskFilterStateProvider);
    final allTasks =
        ref.watch(taskListProvider(TaskFilter.none)).value ?? const <Task>[];
    final tags = (allTasks.expand((task) => task.tags)).toSet().toList()
      ..sort();

    String? contactName;
    if (filter.contactId != null) {
      contactName = ref
          .watch(contacts_feature.watchContactByIdProvider(filter.contactId!))
          .value
          ?.name;
    }
    final titleQuery = filter.titleQuery?.trim();
    final hasActiveFilter =
        filter != TaskFilter.none || filter.sort != TaskSort.none;

    final children = <Widget>[
      Builder(
        builder: (buttonContext) => OutlinedButton.icon(
          onPressed: () => _openFilterMenu(buttonContext, ref, filter, tags),
          icon: const Icon(Icons.filter_alt_outlined),
          label: Text(l10n.filter),
        ),
      ),
    ];

    if (filter.sort != TaskSort.none) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: embedded
              ? _compactChip(
                  context,
                  icon: Icons.swap_vert,
                  label: _sortLabel(context, filter.sort),
                  onDeleted: () => ref
                      .read(taskFilterStateProvider.notifier)
                      .setFilter(filter.copyWith(sort: TaskSort.none)),
                )
              : Chip(
                  avatar: const Icon(Icons.swap_vert, size: 16),
                  label: Text(_sortLabel(context, filter.sort)),
                  visualDensity: VisualDensity.compact,
                  onDeleted: () => ref
                      .read(taskFilterStateProvider.notifier)
                      .setFilter(filter.copyWith(sort: TaskSort.none)),
                ),
        ),
      );
    }

    if (hasActiveFilter) {
      final summary = _filterSummary(
        context,
        filter,
        contactName: contactName,
        titleQuery: titleQuery,
      );
      void clearAll() =>
          ref.read(taskFilterStateProvider.notifier).setFilter(TaskFilter.none);
      if (embedded) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: _compactChip(
              context,
              icon: Icons.check,
              label: summary,
              onDeleted: clearAll,
            ),
          ),
        );
      } else {
        // Desktop / standalone: full-width summary chip (direct Expanded
        // child of this Row — pixel-identical to the pre-refactor layout).
        children.add(const SizedBox(width: 12));
        children.add(
          Expanded(
            child: Chip(
              avatar: const Icon(Icons.check, size: 16),
              label: Text(summary),
              visualDensity: VisualDensity.compact,
              onDeleted: clearAll,
            ),
          ),
        );
      }
    }

    return Padding(
      padding: padding,
      child: Row(
        mainAxisSize: embedded ? MainAxisSize.min : MainAxisSize.max,
        children: children,
      ),
    );
  }

  /// Width-capped deletable chip for the embedded (mobile toolbar) case —
  /// never uses [Expanded] because the parent row slot is unbounded.
  Widget _compactChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onDeleted,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 140),
      child: Chip(
        avatar: Icon(icon, size: 16),
        label: Text(label, overflow: TextOverflow.ellipsis, maxLines: 1),
        visualDensity: VisualDensity.compact,
        onDeleted: onDeleted,
      ),
    );
  }
}

sealed class _FilterOption {
  const _FilterOption();
}

final class _StatusFilterOption extends _FilterOption {
  const _StatusFilterOption(this.status);

  final TaskStatus? status;
}

final class _PriorityFilterOption extends _FilterOption {
  const _PriorityFilterOption(this.priority);

  final TaskPriority? priority;
}

final class _TagFilterOption extends _FilterOption {
  const _TagFilterOption(this.tag);

  final String tag;
}

final class _HideDoneFilterOption extends _FilterOption {
  const _HideDoneFilterOption();
}

final class _NoDueDateFilterOption extends _FilterOption {
  const _NoDueDateFilterOption();
}

final class _SortOption extends _FilterOption {
  const _SortOption(this.sort);

  final TaskSort sort;
}

final class _ResetFilterOption extends _FilterOption {
  const _ResetFilterOption();
}

Future<void> _openFilterMenu(
  BuildContext context,
  WidgetRef ref,
  TaskFilter filter,
  List<String> tags,
) async {
  final l10n = AppLocalizations.of(context);
  final sectionStyle = Theme.of(context).textTheme.labelSmall;

  final items = <PopupMenuEntry<_FilterOption>>[
    PopupMenuItem(
      enabled: false,
      child: Text(l10n.filterStatus, style: sectionStyle),
    ),
    for (final status in [null, ...TaskStatus.values])
      PopupMenuItem(
        value: _StatusFilterOption(status),
        child: _MenuValueRow(
          selected: filter.status == status,
          label: status == null
              ? l10n.filterAll
              : taskStatusLabel(context, status),
        ),
      ),
    PopupMenuItem(
      enabled: false,
      child: Text(l10n.filterPriority, style: sectionStyle),
    ),
    for (final priority in [null, ...TaskPriority.values])
      PopupMenuItem(
        value: _PriorityFilterOption(priority),
        child: _MenuValueRow(
          selected: filter.priority == priority,
          label: priority == null
              ? l10n.filterAll
              : taskPriorityLabel(context, priority),
        ),
      ),
    PopupMenuItem(
      enabled: false,
      child: Text(l10n.filterTags, style: sectionStyle),
    ),
    if (tags.isEmpty)
      PopupMenuItem(enabled: false, child: Text(l10n.noTags))
    else
      for (final tag in tags)
        PopupMenuItem(
          value: _TagFilterOption(tag),
          child: _MenuValueRow(selected: filter.tag == tag, label: '#$tag'),
        ),
    const PopupMenuDivider(),
    PopupMenuItem(
      value: const _HideDoneFilterOption(),
      child: _MenuValueRow(selected: filter.hideDone, label: l10n.hideDone),
    ),
    PopupMenuItem(
      value: const _NoDueDateFilterOption(),
      child: _MenuValueRow(
        selected: filter.noDueDate,
        label: l10n.filterNoDueDate,
      ),
    ),
    const PopupMenuDivider(),
    PopupMenuItem(
      enabled: false,
      child: Text(l10n.filterSort, style: sectionStyle),
    ),
    for (final sort in TaskSort.values)
      PopupMenuItem(
        value: _SortOption(sort),
        child: _MenuValueRow(
          selected: filter.sort == sort,
          label: _sortLabel(context, sort),
        ),
      ),
    if (filter != TaskFilter.none || filter.sort != TaskSort.none) ...[
      const PopupMenuDivider(),
      PopupMenuItem(
        value: const _ResetFilterOption(),
        child: Text(l10n.resetFilters),
      ),
    ],
  ];

  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
  final box = context.findRenderObject() as RenderBox;
  final option = await showMenu<_FilterOption>(
    context: context,
    position: RelativeRect.fromRect(
      Rect.fromPoints(
        box.localToGlobal(Offset.zero, ancestor: overlay),
        box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    ),
    items: items,
  );
  if (option != null) {
    _applyFilter(ref, option);
  }
}

void _applyFilter(WidgetRef ref, _FilterOption option) {
  final notifier = ref.read(taskFilterStateProvider.notifier);
  final filter = ref.read(taskFilterStateProvider);
  switch (option) {
    case _StatusFilterOption(:final status):
      notifier.setFilter(
        filter.copyWith(status: filter.status == status ? null : status),
      );
    case _PriorityFilterOption(:final priority):
      notifier.setFilter(
        filter.copyWith(
          priority: filter.priority == priority ? null : priority,
        ),
      );
    case _TagFilterOption(:final tag):
      notifier.setFilter(filter.copyWith(tag: filter.tag == tag ? null : tag));
    case _HideDoneFilterOption():
      notifier.setFilter(filter.copyWith(hideDone: !filter.hideDone));
    case _NoDueDateFilterOption():
      notifier.setFilter(filter.copyWith(noDueDate: !filter.noDueDate));
    case _SortOption(:final sort):
      notifier.setFilter(filter.copyWith(sort: sort));
    case _ResetFilterOption():
      notifier.setFilter(TaskFilter.none);
  }
}

String _sortLabel(BuildContext context, TaskSort sort) {
  final l10n = AppLocalizations.of(context);
  return switch (sort) {
    TaskSort.none => l10n.sortNone,
    TaskSort.dueAsc => l10n.sortDueAsc,
    TaskSort.dueDesc => l10n.sortDueDesc,
    TaskSort.createdDesc => l10n.sortCreatedDesc,
    TaskSort.createdAsc => l10n.sortCreatedAsc,
  };
}

String _filterSummary(
  BuildContext context,
  TaskFilter filter, {
  String? contactName,
  String? titleQuery,
}) {
  final l10n = AppLocalizations.of(context);
  final parts = <String>[
    if (filter.status != null) taskStatusLabel(context, filter.status!),
    if (filter.priority != null) taskPriorityLabel(context, filter.priority!),
    if (filter.tag != null) '#${filter.tag}',
    if (filter.hideDone) l10n.hideDone,
    if (filter.noDueDate) l10n.filterNoDueDate,
    if (filter.contactId != null && contactName != null)
      '${l10n.contactFilter} $contactName',
    if (titleQuery != null && titleQuery.trim().isNotEmpty) '"$titleQuery"',
  ];
  return parts.join(' · ');
}

class _MenuValueRow extends StatelessWidget {
  const _MenuValueRow({required this.selected, required this.label});

  final bool selected;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.check,
          size: 18,
          color: selected
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(label, overflow: TextOverflow.ellipsis, maxLines: 1),
        ),
      ],
    );
  }
}
