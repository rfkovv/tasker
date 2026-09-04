import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/task.dart';
import '../../domain/task_priority.dart';
import '../providers/task_form_provider.dart';
import '../providers/task_list_provider.dart';

class TaskFormScreen extends ConsumerStatefulWidget {
  const TaskFormScreen({super.key, this.taskId, this.onSaved});

  final String? taskId;
  final VoidCallback? onSaved;

  @override
  ConsumerState<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends ConsumerState<TaskFormScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _tagController;
  bool _controllersSeeded = false;

  bool get _isNew => widget.taskId == null || widget.taskId == 'new';

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
    _tagController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final taskAsync = _isNew
        ? const AsyncValue<Task?>.data(null)
        : ref.watch(watchTaskByIdProvider(widget.taskId!));
    final task = taskAsync is AsyncData<Task?> ? taskAsync.value : null;
    final form = ref.watch(taskFormProvider(task));
    final formNotifier = ref.read(taskFormProvider(task).notifier);

    if (task != null && !_controllersSeeded) {
      _controllersSeeded = true;
      _titleController.text = task.title;
      _descriptionController.text = task.description ?? '';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'New Task' : 'Edit Task'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: taskAsync is AsyncLoading
                ? const Center(child: CircularProgressIndicator())
                : taskAsync is AsyncError
                    ? Center(child: Text('Error: ${taskAsync.error}'))
                    : _buildForm(context, form, formNotifier),
          ),
          const Divider(height: 1),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Spacer(),
                  FilledButton(
                    onPressed: () async {
                      final saved = await formNotifier.save();
                      if (saved && context.mounted) {
                        widget.onSaved?.call();
                        Navigator.maybePop(context);
                      }
                    },
                    child: const Text('Save'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(
    BuildContext context,
    TaskFormState form,
    TaskForm formController,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Title',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.next,
            onChanged: formController.setTitle,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            maxLines: 4,
            onChanged: formController.setDescription,
          ),
          const SizedBox(height: 16),
          _PrioritySelector(
            value: form.priority,
            onChanged: formController.setPriority,
          ),
          const SizedBox(height: 16),
          _DueDateField(
            value: form.dueDate,
            onChanged: formController.setDueDate,
          ),
          const SizedBox(height: 16),
          _TagsField(
            controller: _tagController,
            tags: form.tags,
            onAdd: (tag) {
              formController.toggleTag(tag);
              _tagController.clear();
            },
          ),
        ],
      ),
    );
  }
}

class _PrioritySelector extends StatelessWidget {
  const _PrioritySelector({required this.value, required this.onChanged});

  final TaskPriority value;
  final ValueChanged<TaskPriority> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Priority', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        SegmentedButton<TaskPriority>(
          segments: [
            for (final p in TaskPriority.values)
              ButtonSegment(value: p, label: Text(p.name)),
          ],
          selected: {value},
          onSelectionChanged: (s) => onChanged(s.first),
        ),
      ],
    );
  }
}

class _DueDateField extends StatelessWidget {
  const _DueDateField({required this.value, required this.onChanged});

  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Due date', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Row(
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today),
              label: Text(
                value == null
                    ? 'No due date'
                    : '${value!.year}-${value!.month.toString().padLeft(2, '0')}-${value!.day.toString().padLeft(2, '0')}',
              ),
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: value ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (picked != null) onChanged(picked);
              },
            ),
            if (value != null) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () => onChanged(null),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _TagsField extends StatelessWidget {
  const _TagsField({
    required this.controller,
    required this.tags,
    required this.onAdd,
  });

  final TextEditingController controller;
  final List<String> tags;
  final ValueChanged<String> onAdd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tags', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final tag in tags)
              InputChip(
                label: Text(tag),
                onDeleted: () => onAdd(tag),
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Type a tag and press enter...',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onSubmitted: (value) {
            final tag = value.trim();
            if (tag.isNotEmpty) onAdd(tag);
          },
        ),
      ],
    );
  }
}
