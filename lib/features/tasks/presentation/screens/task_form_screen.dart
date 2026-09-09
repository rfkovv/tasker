import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../contacts/contacts.dart' as contacts_feature;
import '../../../contacts/domain/contact.dart';
import '../../../../l10n/app_localizations.dart';

import '../../domain/task.dart';
import '../../domain/task_priority.dart';
import '../providers/task_contacts_provider.dart';
import '../providers/task_form_provider.dart';
import '../providers/task_list_provider.dart';
import '../widgets/task_priority_badge.dart';

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

    final l10n = AppLocalizations.of(context);

    final allContacts = _isNew
        ? ref.watch(contacts_feature.contactListProvider(null)).value ??
            const <Contact>[]
        : const <Contact>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? l10n.newTask : l10n.editTask),
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
                ? Center(
                    child: Text(
                      l10n.errorWithValue(taskAsync.error.toString()),
                    ),
                  )
                : _buildForm(context, form, formNotifier, allContacts),
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
                      try {
                        final saved = await formNotifier.save();
                        if (saved && context.mounted) {
                          widget.onSaved?.call();
                          Navigator.maybePop(context);
                        }
                      } catch (_) {
                        // Persistence failed; keep the form open so the user
                        // can retry. The atomic repository write guarantees no
                        // partial data was committed.
                      }
                    },
                    child: Text(l10n.save),
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
    List<Contact> allContacts,
  ) {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: l10n.titleLabel,
              border: const OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.next,
            onChanged: formController.setTitle,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descriptionController,
            decoration: InputDecoration(
              labelText: l10n.descriptionLabel,
              border: const OutlineInputBorder(),
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
            _ContactsSection(
              contactsAsync:
                  ref.watch(taskContactsManagerProvider(_taskId!)),
              onAttachExisting: (id) => ref
                  .read(taskContactsManagerProvider(_taskId!).notifier)
                  .attach(id),
              onCreateAndLink: (contact) async => ref
                  .read(taskContactsManagerProvider(_taskId!).notifier)
                  .attach(contact.id),
              onDetach: (id) => ref
                  .read(taskContactsManagerProvider(_taskId!).notifier)
                  .detach(id),
            ),
          ] else ...[
            const SizedBox(height: 24),
            _ContactsSection(
              contactsAsync: AsyncData(
                form.contactIds
                    .map((id) {
                      for (final c in form.draftContacts) {
                        if (c.id == id) return c;
                      }
                      for (final c in allContacts) {
                        if (c.id == id) return c;
                      }
                      return null;
                    })
                    .whereType<Contact>()
                    .toList(),
              ),
              onAttachExisting: (id) async => formController.attachContact(id),
              onCreateAndLink: (contact) async =>
                  formController.linkNewContact(contact),
              onDetach: (id) async => formController.detachContact(id),
            ),
          ],
        ],
      ),
    );
  }
}

class _ContactsSection extends StatelessWidget {
  const _ContactsSection({
    required this.contactsAsync,
    required this.onAttachExisting,
    required this.onCreateAndLink,
    required this.onDetach,
  });

  final AsyncValue<List<Contact>> contactsAsync;
  final Future<void> Function(String contactId) onAttachExisting;
  final Future<void> Function(Contact contact) onCreateAndLink;
  final Future<void> Function(String contactId) onDetach;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(l10n.contacts, style: Theme.of(context).textTheme.titleSmall),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.add, size: 20),
              tooltip: l10n.linkContact,
              onPressed: () => _showLinkContactSheet(context),
            ),
          ],
        ),
        const SizedBox(height: 8),
        contactsAsync.when(
          data: (contacts) => contacts.isEmpty
              ? Text(
                  l10n.noContactsLinked,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: Theme.of(context).colorScheme.outline),
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
                        onDeleted: () => onDetach(contact.id),
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

  void _showLinkContactSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _LinkContactSheet(
        linkedIds: contactsAsync.value
                ?.map((c) => c.id)
                .toSet() ??
            const <String>{},
        onAttachExisting: onAttachExisting,
        onCreateAndLink: onCreateAndLink,
      ),
    );
  }
}

class _LinkContactSheet extends ConsumerStatefulWidget {
  const _LinkContactSheet({
    required this.linkedIds,
    required this.onAttachExisting,
    required this.onCreateAndLink,
  });

  final Set<String> linkedIds;
  final Future<void> Function(String contactId) onAttachExisting;
  final Future<void> Function(Contact contact) onCreateAndLink;

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
    final contactsAsync = ref.watch(contacts_feature.contactListProvider(null));
    final l10n = AppLocalizations.of(context);

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
          Text(
            l10n.linkContactTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          if (!_showInlineCreate) ...[
            SizedBox(
              height: 300,
              child: contactsAsync.when(
                data: (contacts) {
                  final available = contacts
                      .where((c) => !widget.linkedIds.contains(c.id))
                      .toList();
                  if (available.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(l10n.noContactsAvailable),
                          const SizedBox(height: 12),
                          TextButton.icon(
                            onPressed: () =>
                                setState(() => _showInlineCreate = true),
                            icon: const Icon(Icons.add),
                            label: Text(l10n.createNewContact),
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
                          label: Text(l10n.createNewContact),
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
                        onTap: () async {
                          await widget.onAttachExisting(contact.id);
                          if (context.mounted) Navigator.pop(context);
                        },
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) =>
                    Center(child: Text(l10n.errorWithValue(e.toString()))),
              ),
            ),
          ] else ...[
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: l10n.nameLabel,
                border: const OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _roleController,
              decoration: InputDecoration(
                labelText: l10n.roleOptional,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: l10n.emailOptional,
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              decoration: InputDecoration(
                labelText: l10n.phoneOptional,
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                TextButton(
                  onPressed: () => setState(() => _showInlineCreate = false),
                  child: Text(l10n.back),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () async {
                    final name = _nameController.text.trim();
                    if (name.isEmpty) return;

                    final repo = ref.read(
                      contacts_feature.contactRepositoryProvider,
                    );
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
                    await widget.onCreateAndLink(contact);
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: Text(l10n.createAndLink),
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
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.filterPriority,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        SegmentedButton<TaskPriority>(
          segments: [
            for (final p in TaskPriority.values)
              ButtonSegment(
                value: p,
                label: Text(taskPriorityLabel(context, p)),
              ),
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
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.dueDate, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Row(
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today),
              label: Text(
                value == null
                    ? l10n.noDueDate
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
              OutlinedButton.icon(
                icon: const Icon(Icons.access_time),
                label: Text(
                  '${value!.hour.toString().padLeft(2, '0')}:${value!.minute.toString().padLeft(2, '0')}',
                ),
                onPressed: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(value!),
                  );
                  if (picked != null) {
                    onChanged(
                      DateTime(
                        value!.year,
                        value!.month,
                        value!.day,
                        picked.hour,
                        picked.minute,
                      ),
                    );
                  }
                },
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.clear),
                tooltip: l10n.noDueDate,
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
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.tags, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final tag in tags)
              InputChip(label: Text(tag), onDeleted: () => onAdd(tag)),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: l10n.tagsHint,
            border: const OutlineInputBorder(),
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
