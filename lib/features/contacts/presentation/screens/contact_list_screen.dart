import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../search/search.dart' show GlobalSearchButton;

import '../../domain/contact.dart';
import '../providers/contact_list_provider.dart';
import '../widgets/contact_expansion.dart';
import '../widgets/contact_tile.dart';

class ContactListScreen extends ConsumerStatefulWidget {
  const ContactListScreen({super.key, this.onOpenContact});

  final ValueChanged<String>? onOpenContact;

  @override
  ConsumerState<ContactListScreen> createState() => _ContactListScreenState();
}

class _ContactListScreenState extends ConsumerState<ContactListScreen> {
  bool _showFab = false;
  String? _filterInitial;
  final Set<String> _expandedIds = {};

  void _handleAddContact() => widget.onOpenContact?.call('new');

  void _toggleExpanded(String id) {
    setState(() {
      if (!_expandedIds.add(id)) {
        _expandedIds.remove(id);
      }
    });
  }

  List<Contact> _filteredContacts(List<Contact> all) {
    final initial = _filterInitial;
    if (initial == null) return all;
    return all.where((contact) {
      final name = contact.name.trim();
      return name.isNotEmpty && name[0].toUpperCase() == initial;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final contactsAsync = ref.watch(contactListProvider(null));

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                AppLocalizations.of(context).contacts,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            const GlobalSearchButton(),
          ],
        ),
      ),
      body: Column(
        children: [
          _ContactFilterBar(
            contacts: contactsAsync.value ?? const <Contact>[],
            initial: _filterInitial,
            onChanged: (initial) =>
                setState(() => _filterInitial = initial),
          ),
          const Divider(height: 1),
          Expanded(
            child: contactsAsync.when(
              data: (all) {
                final contacts = _filteredContacts(all);
                return Stack(
                  children: [
                    Positioned.fill(
                      child: NotificationListener<ScrollMetricsNotification>(
                        onNotification: (notification) {
                          final scrollable =
                              notification.metrics.maxScrollExtent > 0;
                          if (scrollable != _showFab && mounted) {
                            setState(() => _showFab = scrollable);
                          }
                          return false;
                        },
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: contacts.isEmpty ? 2 : contacts.length + 1,
                          itemBuilder: (context, index) {
                            if (contacts.isEmpty) {
                              if (index == 0) {
                                return const Padding(
                                  padding: EdgeInsets.all(32),
                                  child: _EmptyState(),
                                );
                              }
                              return _FooterTile(
                                onAddContact: _handleAddContact,
                              );
                            }
                            if (index == contacts.length) {
                              return _FooterTile(
                                onAddContact: _handleAddContact,
                              );
                            }
                            final contact = contacts[index];
                            final expanded = _expandedIds.contains(contact.id);
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                ContactTile(
                                  contact: contact,
                                  expanded: expanded,
                                  onTap: () => _toggleExpanded(contact.id),
                                  onEdit: () => widget.onOpenContact
                                      ?.call(contact.id),
                                ),
                                if (expanded)
                                  ContactExpansion(
                                    contact: contact,
                                    onSeeAllTasks: () => context.go(
                                      '/?contact=${contact.id}',
                                    ),
                                    onOpenTask: (taskId) => context.push(
                                      '/tasks/$taskId',
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                    if (contacts.isNotEmpty)
                      Positioned(
                        right: 16,
                        bottom: 16,
                        child: AnimatedOpacity(
                          opacity: _showFab ? 1 : 0,
                          duration: const Duration(milliseconds: 150),
                          child: FloatingActionButton.small(
                            onPressed: _showFab ? _handleAddContact : null,
                            child: const Icon(Icons.person_add),
                          ),
                        ),
                      ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(
                  AppLocalizations.of(context).errorWithValue(e.toString()),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactFilterBar extends StatelessWidget {
  const _ContactFilterBar({
    required this.contacts,
    required this.initial,
    required this.onChanged,
  });

  final List<Contact> contacts;
  final String? initial;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final initials = contacts
        .map((contact) {
          final name = contact.name.trim();
          if (name.isEmpty) return null;
          return name[0].toUpperCase();
        })
        .whereType<String>()
        .toSet()
        .toList()
      ..sort();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Builder(
            builder: (buttonContext) => OutlinedButton.icon(
              onPressed: () => _openContactFilterMenu(
                buttonContext,
                initials,
                initial,
                onChanged,
              ),
              icon: const Icon(Icons.filter_alt_outlined),
              label: Text(l10n.filter),
            ),
          ),
          if (initial != null) ...[
            const SizedBox(width: 12),
            Expanded(
              child: Chip(
                avatar: const Icon(Icons.check, size: 16),
                label: Text(initial!),
                visualDensity: VisualDensity.compact,
                onDeleted: () => onChanged(null),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

Future<void> _openContactFilterMenu(
  BuildContext context,
  List<String> initials,
  String? current,
  ValueChanged<String?> onChanged,
) async {
  final l10n = AppLocalizations.of(context);

  final items = <PopupMenuEntry<Object>>[
    PopupMenuItem<Object>(
      value: const _ContactFilterAll(),
      child: _MenuValueRow(
        selected: current == null,
        label: l10n.filterAll,
      ),
    ),
    for (final letter in initials)
      PopupMenuItem<Object>(
        value: letter,
        child: _MenuValueRow(
          selected: current == letter,
          label: letter,
        ),
      ),
  ];

  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
  final box = context.findRenderObject() as RenderBox;
  final option = await showMenu<Object>(
    context: context,
    position: RelativeRect.fromRect(
      Rect.fromPoints(
        box.localToGlobal(Offset.zero, ancestor: overlay),
        box.localToGlobal(
          box.size.bottomRight(Offset.zero),
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    ),
    items: items,
  );
  if (option == null) return;
  if (option is _ContactFilterAll) {
    onChanged(null);
    return;
  }
  onChanged(option as String);
}

class _ContactFilterAll {
  const _ContactFilterAll();
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
        Text(label),
      ],
    );
  }
}

class _FooterTile extends StatelessWidget {
  const _FooterTile({required this.onAddContact});

  final VoidCallback onAddContact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      child: Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          leading: Icon(Icons.person_add, color: theme.colorScheme.primary),
          title: Text(AppLocalizations.of(context).addContact),
          onTap: onAddContact,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.contacts,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context).noContactsYet,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            AppLocalizations.of(context).noContactsHint,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ],
      ),
    );
  }
}
