import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../contacts/contacts.dart' as contacts_feature;
import '../../tasks/tasks.dart' as tasks_feature;
import '../domain/search_models.dart';
import '../domain/search_ranker.dart';

part 'search_provider.g.dart';

/// Per-section cap for the overlay's ranking; results tell the UI how many
/// records matched overall so it can offer "show all".
const int defaultSearchSectionLimit = 10;

/// Global search over every registered section.
///
/// Consumes tasks and contacts exclusively through their public barrels
/// ([tasks_feature], [contacts_feature]). Adding a new section means adding a
/// new [SearchSectionType] and folding its hits into [searchResults].
@riverpod
Future<SearchResults> searchResults(Ref ref, String query) async {
  final q = query.trim();
  if (q.isEmpty) return const SearchResults([]);

  final tasks = await ref.watch(
    tasks_feature.taskListProvider(
      tasks_feature.TaskFilter(titleQuery: q),
    ).future,
  );
  final contacts = await ref.watch(
    contacts_feature.contactListProvider(q).future,
  );

  return SearchResults([
    buildSectionResult(
      type: SearchSectionType.tasks,
      hits: tasks.map((t) => SearchHit(
            id: t.id,
            type: SearchHitType.task,
            title: t.title,
            subtitle: _taskSubtitle(t),
          )),
      query: q,
      limit: defaultSearchSectionLimit,
    ),
    buildSectionResult(
      type: SearchSectionType.contacts,
      hits: contacts.map((c) => SearchHit(
            id: c.id,
            type: SearchHitType.contact,
            title: c.name,
            subtitle: (c.role?.isNotEmpty ?? false) ? c.role : null,
          )),
      query: q,
      limit: defaultSearchSectionLimit,
    ),
  ]);
}

String? _taskSubtitle(tasks_feature.Task task) {
  if (task.tags.isNotEmpty) return task.tags.map((t) => '#$t').join(', ');
  return null;
}