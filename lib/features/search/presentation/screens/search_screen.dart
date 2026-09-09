import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/search_provider.dart';
import '../../domain/search_models.dart';

/// Shared global search overlay. A single instance of this screen is the one
/// search UI in the app; tasks and contacts screens just open it.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.onOpenTask, this.onOpenContact});

  final ValueChanged<String>? onOpenTask;
  final ValueChanged<String>? onOpenContact;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() => _query = value);
    });
  }

  void _openTask(String id) {
    final onOpenTask = widget.onOpenTask;
    if (onOpenTask != null) {
      onOpenTask(id);
      return;
    }
    context.pushReplacement('/tasks/$id');
  }

  void _openContact(String id) {
    final onOpenContact = widget.onOpenContact;
    if (onOpenContact != null) {
      onOpenContact(id);
      return;
    }
    context.pushReplacement('/contacts/$id');
  }

  void _showAllTasks(String query) {
    // Seed through the route so the task board applies the text filter while
    // it is mounted and watching the (autoDispose) filter state.
    context.pushReplacement('/?q=${Uri.encodeQueryComponent(query.trim())}');
  }

  void _showAllContacts() {
    context.pushReplacement('/contacts');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          key: const Key('search-back-button'),
          icon: const Icon(Icons.arrow_back),
          tooltip: l10n.back,
          onPressed: () {
            if (context.canPop()) context.pop();
          },
        ),
        titleSpacing: 8,
        title: TextField(
          controller: _controller,
          autofocus: true,
          onChanged: _onChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: l10n.searchHint,
            isDense: true,
            border: InputBorder.none,
          ),
        ),
      ),
      body: _SearchBody(
        query: _query,
        onOpenTask: _openTask,
        onOpenContact: _openContact,
        onShowAllTasks: _showAllTasks,
        onShowAllContacts: _showAllContacts,
      ),
    );
  }
}

class _SearchBody extends ConsumerWidget {
  const _SearchBody({
    required this.query,
    required this.onOpenTask,
    required this.onOpenContact,
    required this.onShowAllTasks,
    required this.onShowAllContacts,
  });

  final String query;
  final ValueChanged<String> onOpenTask;
  final ValueChanged<String> onOpenContact;
  final ValueChanged<String> onShowAllTasks;
  final VoidCallback onShowAllContacts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    if (query.isEmpty) {
      return _IdleHint(hint: l10n.searchHint);
    }

    final resultsAsync = ref.watch(searchResultsProvider(query));
    return resultsAsync.when(
      data: (results) {
        final sections = results.sections
            .where((s) => s.hits.isNotEmpty)
            .toList();
        if (sections.isEmpty) {
          return _IdleHint(hint: l10n.searchNoResults(query));
        }
        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            for (var i = 0; i < sections.length; i++) ...[
              if (i > 0) const Divider(height: 24),
              _SectionHeader(
                title: _sectionTitle(context, sections[i].type),
                total: sections[i].total,
              ),
              for (final hit in sections[i].hits)
                _SearchHitTile(
                  hit: hit,
                  onTap: hit.type == SearchHitType.task
                      ? () => onOpenTask(hit.id)
                      : () => onOpenContact(hit.id),
                ),
              if (sections[i].hasMore)
                Padding(
                  padding: const EdgeInsets.only(left: 8, right: 8),
                  child: TextButton.icon(
                    onPressed: sections[i].type == SearchSectionType.tasks
                        ? () => onShowAllTasks(query)
                        : onShowAllContacts,
                    icon: const Icon(Icons.expand_more, size: 18),
                    label: Text(
                      l10n.searchShowAll(
                        sections[i].total.toString(),
                      ),
                    ),
                  ),
                ),
            ],
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(l10n.errorWithValue(e.toString())),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.total});

  final String title;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
      child: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _SearchHitTile extends StatelessWidget {
  const _SearchHitTile({required this.hit, required this.onTap});

  final SearchHit hit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(
        hit.type == SearchHitType.task ? Icons.checklist : Icons.person,
        color: theme.colorScheme.primary,
      ),
      title: Text(hit.title),
      subtitle: hit.subtitle == null ? null : Text(hit.subtitle!),
      onTap: onTap,
    );
  }
}

class _IdleHint extends StatelessWidget {
  const _IdleHint({required this.hint});

  final String hint;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          hint,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
        ),
      ),
    );
  }
}

String _sectionTitle(BuildContext context, SearchSectionType type) {
  final l10n = AppLocalizations.of(context);
  return switch (type) {
    SearchSectionType.tasks => l10n.searchSectionTasks,
    SearchSectionType.contacts => l10n.searchSectionContacts,
  };
}