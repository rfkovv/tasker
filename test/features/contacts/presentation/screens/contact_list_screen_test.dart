import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskmaster/features/contacts/contacts.dart' as contacts_feature;
import 'package:taskmaster/features/contacts/domain/contact.dart';
import 'package:taskmaster/features/contacts/domain/contact_repository.dart';
import 'package:taskmaster/features/contacts/presentation/screens/contact_list_screen.dart';
import 'package:taskmaster/features/contacts/presentation/widgets/contact_tile.dart';
import 'package:taskmaster/l10n/app_localizations.dart';

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
      List<String> taskIds) async {
    return const {};
  }

  @override
  Future<void> replaceContactsForTask(
      String taskId, List<String> contactIds) async {}
}

Contact buildContact({String? id, String name = 'Alex'}) {
  final now = DateTime.now();
  return Contact(
    id: id ?? 'c1',
    name: name,
    createdAt: now,
    updatedAt: now,
  );
}

Widget buildApp(
  List<Contact> contacts, {
  ValueChanged<String>? onOpenContact,
}) {
  return ProviderScope(
    overrides: [
      contacts_feature.contactRepositoryProvider
          .overrideWithValue(FakeContactRepository(contacts)),
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
    await tester.pumpWidget(buildApp([
      buildContact(id: '1', name: 'Alice'),
      buildContact(id: '2', name: 'Bob'),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
  });

  testWidgets('tapping contact invokes onOpenContact', (tester) async {
    String? opened;
    await tester.pumpWidget(buildApp(
      [buildContact(id: '1', name: 'Alice')],
      onOpenContact: (id) => opened = id,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(ContactTile).first);
    expect(opened, '1');
  });

  testWidgets('shows Add Contact as footer tile and no Add Task',
      (tester) async {
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
    await tester.pumpWidget(buildApp([
      for (var i = 0; i < 40; i++) buildContact(id: '$i', name: 'Contact $i'),
    ]));
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

  testWidgets('filters contacts by initial letter via dropdown', (tester) async {
    await tester.pumpWidget(buildApp([
      buildContact(id: '1', name: 'Alice'),
      buildContact(id: '2', name: 'Bob'),
    ]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Filter'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('A').last);
    await tester.pumpAndSettle();

    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsNothing);
    expect(find.widgetWithText(Chip, 'A'), findsOneWidget);
  });

  testWidgets('clearing contact filter via All restores the list',
      (tester) async {
    await tester.pumpWidget(buildApp([
      buildContact(id: '1', name: 'Alice'),
      buildContact(id: '2', name: 'Bob'),
    ]));
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
}
