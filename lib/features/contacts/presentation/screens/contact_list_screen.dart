import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/contact_list_provider.dart';
import '../widgets/contact_tile.dart';

class ContactListScreen extends ConsumerStatefulWidget {
  const ContactListScreen({super.key, this.onOpenContact});

  final ValueChanged<String>? onOpenContact;

  @override
  ConsumerState<ContactListScreen> createState() => _ContactListScreenState();
}

class _ContactListScreenState extends ConsumerState<ContactListScreen> {
  bool _showFab = false;

  void _handleAddContact() => widget.onOpenContact?.call('new');

  @override
  Widget build(BuildContext context) {
    final contactsAsync = ref.watch(contactListProvider(null));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacts'),
      ),
      body: contactsAsync.when(
        data: (contacts) => Stack(
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
                      return _FooterTile(onAddContact: _handleAddContact);
                    }
                    if (index == contacts.length) {
                      return _FooterTile(onAddContact: _handleAddContact);
                    }
                    final contact = contacts[index];
                    return ContactTile(
                      contact: contact,
                      onTap: () => widget.onOpenContact?.call(contact.id),
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
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
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
          title: const Text('Add Contact'),
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
          Text('No contacts yet',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Tap "Add Contact" to create your first contact',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ],
      ),
    );
  }
}
