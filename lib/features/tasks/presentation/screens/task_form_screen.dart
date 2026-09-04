import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../contacts/data/contact_repository_provider.dart';
import '../../../contacts/presentation/providers/contact_list_provider.dart';
import '../../domain/task.dart';
import '../../domain/task_priority.dart';
import '../providers/task_contacts_provider.dart';
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
  String? get _taskId => _isNew ? null : widget.taskId;

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
          if (_taskId != null) ...[
            const SizedBox(height: 24),
            _ContactsSection(taskId: _taskId!),
          ],
        ],
      ),
    );
  }
}

class _ContactsSection extends ConsumerWidget {
  const _ContactsSection({required this.taskId});

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contactsAsync = ref.watch(taskContactsManagerProvider(taskId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Contacts', style: Theme.of(context).textTheme.titleSmall),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.add, size: 20),
              tooltip: 'Link contact',
              onPressed: () => _showLinkContactSheet(context, ref),
            ),
          ],
        ),
        const SizedBox(height: 8),
        contactsAsync.when(
          data: (contacts) => contacts.isEmpty
              ? Text(
                  'No contacts linked',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
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
                        onDeleted: () {
                          ref
                              .read(
                                  taskContactsManagerProvider(taskId).notifier)
                              .detach(contact.id);
                        },
                      ),
                  ],
                ),
          loading: () => const SizedBox(
            height: 24,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (e, _) => Text('Error: $e'),
        ),
      ],
    );
  }

  void _showLinkContactSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _LinkContactSheet(taskId: taskId),
    );
  }
}

class _LinkContactSheet extends ConsumerStatefulWidget {
  const _LinkContactSheet({required this.taskId});

  final String taskId;

  @override
  ConsumerState<_LinkContactSheet> createState() => _LinkContactSheetState();
}

class _LinkContactSheetState extends ConsumerState<_LinkContactSheet> {
  bool _showInlineCreate = false;
  final _nameController = TextEditingController();
  final _roleController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _roleController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contactsAsync = ref.watch(contactListProvider(null));
    final linkedAsync = ref.watch(taskContactsManagerProvider(widget.taskId));
    final linkedIds = linkedAsync.hasValue
        ? linkedAsync.value!.map((c) => c.id).toSet()
        : <String>{};

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Link Contact',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          if (!_showInlineCreate) ...[
            SizedBox(
              height: 300,
              child: contactsAsync.when(
                data: (contacts) {
                  final available =
                      contacts.where((c) => !linkedIds.contains(c.id)).toList();
                  if (available.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('No contacts available'),
                          const SizedBox(height: 12),
                          TextButton.icon(
                            onPressed: () =>
                                setState(() => _showInlineCreate = true),
                            icon: const Icon(Icons.add),
                            label: const Text('Create new contact'),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: available.length + 1,
                    itemBuilder: (context, index) {
                      if (index == available.length) {
                        return TextButton.icon(
                          onPressed: () =>
                              setState(() => _showInlineCreate = true),
                          icon: const Icon(Icons.add),
                          label: const Text('Create new contact'),
                        );
                      }
                      final contact = available[index];
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            contact.name.isNotEmpty
                                ? contact.name[0].toUpperCase()
                                : '?',
                          ),
                        ),
                        title: Text(contact.name),
                        subtitle: contact.role != null
                            ? Text(contact.role!)
                            : null,
                        trailing: const Icon(Icons.add_link),
                        onTap: () {
                          ref
                              .read(taskContactsManagerProvider(widget.taskId)
                                  .notifier)
                              .attach(contact.id);
                          Navigator.pop(context);
                        },
                      );
                    },
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
          ] else ...[
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _roleController,
              decoration: const InputDecoration(
                labelText: 'Role (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email (optional)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone (optional)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                TextButton(
                  onPressed: () =>
                      setState(() => _showInlineCreate = false),
                  child: const Text('Back'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () async {
                    final name = _nameController.text.trim();
                    if (name.isEmpty) return;

                    final repo = ref.read(contactRepositoryProvider);
                    final contact = await repo.create(
                      name: name,
                      role: _roleController.text.trim().isNotEmpty
                          ? _roleController.text.trim()
                          : null,
                      email: _emailController.text.trim().isNotEmpty
                          ? _emailController.text.trim()
                          : null,
                      phone: _phoneController.text.trim().isNotEmpty
                          ? _phoneController.text.trim()
                          : null,
                    );
                    await ref
                        .read(
                            taskContactsManagerProvider(widget.taskId).notifier)
                        .attach(contact.id);
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Create & Link'),
                ),
              ],
            ),
          ],
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
