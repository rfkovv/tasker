import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/contact.dart';

class ContactTile extends StatelessWidget {
  const ContactTile({
    super.key,
    required this.contact,
    this.onTap,
    this.onEdit,
    this.expanded = false,
  });

  final Contact contact;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    child: Text(
                      contact.name.isNotEmpty
                          ? contact.name[0].toUpperCase()
                          : '?',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          contact.name,
                          style: theme.textTheme.titleMedium,
                        ),
                        if (contact.role != null && contact.role!.isNotEmpty)
                          Text(
                            contact.role!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        if (contact.email != null &&
                            contact.email!.isNotEmpty)
                          Text(
                            contact.email!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (onEdit != null)
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: AppLocalizations.of(context).editContact,
                      onPressed: onEdit,
                    ),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 150),
                    child: Icon(
                      Icons.expand_more,
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}