import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskmaster/features/contacts/contacts.dart' as contacts_feature;
import 'package:taskmaster/features/contacts/domain/contact.dart';
import 'package:taskmaster/features/contacts/domain/contact_repository.dart';
import 'package:taskmaster/features/contacts/domain/linked_task.dart';
import 'package:taskmaster/features/contacts/presentation/screens/contact_list_screen.dart';
import 'package:taskmaster/features/contacts/presentation/widgets/contact_expansion.dart';
import 'package:taskmaster/features/contacts/presentation/widgets/contact_tile.dart';
import 'package:taskmaster/l10n/app_localizations.dart';
import 'package:taskmaster/shared/hide_on_scroll_header.dart';

class FakeContactRepository implements ContactRepository {
  FakeContactRepository(this._contacts);

  final List<Contact> _contacts;

  @override
  Stream<List<Contact>> watchAll({String? nameFilter}) {
    final filtered = _contacts.where((c) {
      if (nameFilter == null) return true;
      final name = c.name.toLowerCase();
      return name.contains(nameFilter.toLowerCase());
    }).toList();
    return Stream.value(filtered);
  }

  @override
  Stream<Contact?> watchById(String id) async* {
    for (final c in _contacts) {
      if (c.id == id) yield c;
    }
  }

  @override
  Future<Contact> create({
    required String name,
    String? role,
    String? email,
    String? phone,
  }) async {
    final contact = Contact(
      id: 'new',
      name: name,
      role: role,
      email: email,
      phone: phone,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _contacts.add(contact);
    return contact;
  }

  @override
  Future<void> update(Contact contact) async {}

  @override
  Future<void> delete(String id) async {
    _contacts.removeWhere((c) => c.id == id);
  }

  @override
  Future<List<Contact>> contactsForTask(String taskId) async => const [];

  @override
  Future<Map<String, List<Contact>>> contactsByTaskIds(
    List<String> taskIds,
  ) async {
    return const {};
  }

  @override
  Future<void> replaceContactsForTask(
    String taskId,
    List<String> contactIds,
  ) async {}
}

Contact buildContact({String? id, String name = 'Alex'}) {
  final now = DateTime.now();
  return Contact(id: id ?? 'c1', name: name, createdAt: now, updatedAt: now);
}

Widget buildApp(
  List<Contact> contacts, {
  ValueChanged<String>? onOpenContact,
  List<LinkedTask> linkedTasks = const [],
}) {
  return ProviderScope(
    overrides: [
      contacts_feature.contactRepositoryProvider.overrideWithValue(
        FakeContactRepository(contacts),
      ),
      contacts_feature.activeTasksForContactProvider.overrideWith(
        (ref, contactId) => Stream.value(linkedTasks),
      ),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ContactListScreen(onOpenContact: onOpenContact),
    ),
  );
}

void main() {
  testWidgets('shows empty state when no contacts', (tester) async {
    await tester.pumpWidget(buildApp([]));
    await tester.pumpAndSettle();

    expect(find.text('No contacts yet'), findsOneWidget);
  });

  testWidgets('renders contact names', (tester) async {
    await tester.pumpWidget(
      buildApp([
        buildContact(id: '1', name: 'Alice'),
        buildContact(id: '2', name: 'Bob'),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
  });

  testWidgets('tapping contact expands inline with its active tasks', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildApp(
        [buildContact(id: '1', name: 'Alice')],
        linkedTasks: [
          const LinkedTask(id: 't1', title: 'Ship fix'),
          LinkedTask(
            id: 't2',
            title: 'Plan retro',
            dueAt: DateTime(2026, 9, 10),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(ContactTile).first);
    await tester.pumpAndSettle();

    expect(find.byType(ContactExpansion), findsOneWidget);
    expect(find.text('Ship fix'), findsOneWidget);
    expect(find.text('Plan retro'), findsOneWidget);
    expect(find.text('See all tasks'), findsOneWidget);

    await tester.tap(find.byType(ContactTile).first);
    await tester.pumpAndSettle();
    expect(find.byType(ContactExpansion), findsNothing);
  });

  testWidgets('expanded contact shows hint when no active tasks linked', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp([buildContact(id: '1', name: 'Alice')]));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(ContactTile).first);
    await tester.pumpAndSettle();

    expect(find.text('No active tasks linked'), findsOneWidget);
  });

  testWidgets('edit icon on contact tile invokes onOpenContact', (
    tester,
  ) async {
    String? opened;
    await tester.pumpWidget(
      buildApp([
        buildContact(id: '1', name: 'Alice'),
      ], onOpenContact: (id) => opened = id),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit_outlined).first);
    expect(opened, '1');
  });

  testWidgets('shows Add Contact as footer tile and no Add Task', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp([buildContact(id: '1', name: 'Alice')]));
    await tester.pumpAndSettle();

    expect(find.text('Add Contact'), findsOneWidget);
    expect(find.text('Add Task'), findsNothing);
  });

  testWidgets('does not show FAB when list fits the window', (tester) async {
    await tester.pumpWidget(buildApp([buildContact(id: '1', name: 'Alice')]));
    await tester.pumpAndSettle();

    final fab = find.byType(FloatingActionButton);
    expect(fab, findsOneWidget);
    final wrapper = find.ancestor(
      of: fab,
      matching: find.byType(AnimatedOpacity),
    );
    final opacity = tester.widget<AnimatedOpacity>(wrapper);
    expect(opacity.opacity, 0);
    expect(tester.widget<FloatingActionButton>(fab).onPressed, isNull);
  });

  testWidgets('shows FAB when list overflows the window', (tester) async {
    await tester.pumpWidget(
      buildApp([
        for (var i = 0; i < 40; i++) buildContact(id: '$i', name: 'Contact $i'),
      ]),
    );
    await tester.pumpAndSettle();

    final fab = find.byType(FloatingActionButton);
    expect(fab, findsOneWidget);
    final wrapper = find.ancestor(
      of: fab,
      matching: find.byType(AnimatedOpacity),
    );
    final opacity = tester.widget<AnimatedOpacity>(wrapper);
    expect(opacity.opacity, 1);
    expect(tester.widget<FloatingActionButton>(fab).onPressed, isNotNull);
  });

  testWidgets('filters contacts by initial letter via dropdown', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildApp([
        buildContact(id: '1', name: 'Alice'),
        buildContact(id: '2', name: 'Bob'),
      ]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Filter'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('A').last);
    await tester.pumpAndSettle();

    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsNothing);
    expect(find.widgetWithText(Chip, 'A'), findsOneWidget);
  });

  testWidgets('clearing contact filter via All restores the list', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildApp([
        buildContact(id: '1', name: 'Alice'),
        buildContact(id: '2', name: 'Bob'),
      ]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Filter'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('A').last);
    await tester.pumpAndSettle();

    expect(find.text('Bob'), findsNothing);

    await tester.tap(find.text('Filter'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();

    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
    expect(find.widgetWithText(Chip, 'A'), findsNothing);
  });

  testWidgets('compact mode: AppBar absent, floating search button present', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildApp([buildContact(id: '1', name: 'Alice')]));
    await tester.pumpAndSettle();

    // Compact chrome UNCHANGED: no title row, filter bar static, floating.
    expect(find.byType(AppBar), findsNothing);
    expect(find.byKey(const Key('destination-title')), findsNothing);
    expect(find.byKey(const Key('floating-search-button')), findsOneWidget);
    expect(find.byKey(const Key('global-search-button')), findsOneWidget);
    expect(find.text('Filter'), findsOneWidget);
  });

  testWidgets('portrait: title above toolbar, floating search present, '
      'no AppBar', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildApp([buildContact(id: '1', name: 'Alice')]));
    await tester.pumpAndSettle();

    // Header hierarchy: title row on top, filter toolbar below, no AppBar.
    expect(find.byType(AppBar), findsNothing);
    final title = find.byKey(const Key('destination-title'));
    expect(title, findsOneWidget);
    expect(find.text('Contacts'), findsOneWidget);
    expect(find.text('Filter'), findsOneWidget);
    final titleRect = tester.getRect(title);
    final filterRect = tester.getRect(find.text('Filter'));
    expect(
      titleRect.bottom <= filterRect.top,
      isTrue,
      reason: 'title row must sit above the toolbar',
    );
    // Search trigger = floating button (portrait).
    expect(find.byKey(const Key('floating-search-button')), findsOneWidget);
    expect(find.byKey(const Key('global-search-button')), findsOneWidget);
  });

  testWidgets('portrait: title and filter toolbar hide together on scroll '
      'down and return on scroll up', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      buildApp([
        for (var i = 0; i < 40; i++) buildContact(id: '$i', name: 'Contact $i'),
      ]),
    );
    await tester.pumpAndSettle();

    final title = find.byKey(const Key('destination-title'));
    final filter = find.text('Filter');
    expect(title, findsOneWidget);
    expect(filter, findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(title, findsNothing, reason: 'title must hide on scroll down');
    expect(filter, findsNothing, reason: 'toolbar must hide on scroll down');

    await tester.drag(find.byType(ListView), const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(title, findsOneWidget, reason: 'title must return on scroll up');
    expect(filter, findsOneWidget, reason: 'toolbar must return on scroll up');
  });

  testWidgets('desktop: title above toolbar static, floating search present', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(2000, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildApp([buildContact(id: '1', name: 'Alice')]));
    await tester.pumpAndSettle();

    expect(find.byType(AppBar), findsNothing);
    final title = find.byKey(const Key('destination-title'));
    expect(title, findsOneWidget);
    expect(find.text('Contacts'), findsOneWidget);
    expect(find.text('Filter'), findsOneWidget);
    final titleRect = tester.getRect(title);
    final filterRect = tester.getRect(find.text('Filter'));
    expect(titleRect.bottom <= filterRect.top, isTrue);
    // Desktop: static rows (no hide-on-scroll), floating search present.
    expect(find.byType(HideOnScrollHeader), findsNothing);
    expect(find.byKey(const Key('floating-search-button')), findsOneWidget);
  });
}
