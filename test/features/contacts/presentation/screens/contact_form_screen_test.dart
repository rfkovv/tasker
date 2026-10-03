import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskmaster/features/contacts/data/contact_repository_provider.dart';
import 'package:taskmaster/features/contacts/domain/contact.dart';
import 'package:taskmaster/features/contacts/domain/contact_repository.dart';
import 'package:taskmaster/features/contacts/presentation/screens/contact_form_screen.dart';
import 'package:taskmaster/l10n/app_localizations.dart';

class _ChangeStream<T> {
  _ChangeStream(this._current);

  T _current;
  late final StreamController<T> _controller =
      StreamController<T>.broadcast(onListen: _emitInitial);

  void _emitInitial() {
    if (!_controller.isClosed) _controller.add(_current);
  }

  void update(T value) {
    _current = value;
    if (!_controller.isClosed) _controller.add(value);
  }

  Stream<T> get stream => _controller.stream;

  void close() => _controller.close();
}

class FakeContactRepository implements ContactRepository {
  FakeContactRepository(List<Contact> contacts)
      : _contacts = List.of(contacts),
        _tracker = _ChangeStream<List<Contact>>(List.of(contacts));

  final List<Contact> _contacts;
  final _ChangeStream<List<Contact>> _tracker;
  final deletedIds = <String>[];

  @override
  Stream<List<Contact>> watchAll({String? nameFilter}) => _tracker.stream;

  @override
  Stream<Contact?> watchById(String id) {
    return _tracker.stream.map((all) {
      for (final c in all) {
        if (c.id == id) return c;
      }
      return null;
    });
  }

  @override
  Future<Contact> create({
    required String name,
    String? role,
    String? email,
    String? phone,
  }) async {
    final now = DateTime.now();
    final contact = Contact(
      id: 'new',
      name: name,
      role: role,
      email: email,
      phone: phone,
      createdAt: now,
      updatedAt: now,
    );
    _contacts.add(contact);
    _tracker.update(List.of(_contacts));
    return contact;
  }

  @override
  Future<void> update(Contact contact) async {}

  @override
  Future<void> delete(String id) async {
    deletedIds.add(id);
    _contacts.removeWhere((c) => c.id == id);
    _tracker.update(List.of(_contacts));
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

Contact buildContact({String? id, String name = 'Alice'}) {
  final now = DateTime.now();
  return Contact(id: id ?? 'c1', name: name, createdAt: now, updatedAt: now);
}

Widget buildApp({
  String? contactId,
  required FakeContactRepository repo,
}) {
  return ProviderScope(
    overrides: [
      contactRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ContactFormScreen(contactId: contactId),
    ),
  );
}

void main() {
  testWidgets(
      'delete contact: confirm dialog → soft-delete called + SnackBar shown',
      (tester) async {
    final repo = FakeContactRepository([buildContact(id: 'c1')]);
    await tester.pumpWidget(buildApp(contactId: 'c1', repo: repo));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('contact-delete-button')), findsOneWidget);

    await tester
        .tap(find.byKey(const ValueKey('contact-delete-button')));
    await tester.pumpAndSettle();

    expect(find.text('Delete contact?'), findsOneWidget);
    expect(
      find.text('The contact will be moved to Trash'),
      findsOneWidget,
    );
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(repo.deletedIds, ['c1']);
    expect(find.text('Moved to Trash'), findsOneWidget);
  });

  testWidgets('delete contact: cancel dismisses without calling delete',
      (tester) async {
    final repo = FakeContactRepository([buildContact(id: 'c1')]);
    await tester.pumpWidget(buildApp(contactId: 'c1', repo: repo));
    await tester.pumpAndSettle();

    await tester
        .tap(find.byKey(const ValueKey('contact-delete-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(repo.deletedIds, isEmpty);
    expect(find.text('Delete contact?'), findsNothing);
    expect(find.text('Alice'), findsOneWidget);
  });

  testWidgets('new contact: delete button is not shown', (tester) async {
    final repo = FakeContactRepository([]);
    await tester.pumpWidget(buildApp(contactId: 'new', repo: repo));
    await tester.pumpAndSettle();

    expect(find.text('New Contact'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('contact-delete-button')),
      findsNothing,
    );
  });
}
