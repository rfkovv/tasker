import 'package:drift/drift.dart';

import '../../../local_db/database.dart' as db;
import '../domain/contact.dart' as domain;

class ContactMapper {
  domain.Contact toDomain(db.Contact row) {
    return domain.Contact(
      id: row.id,
      name: row.name,
      role: row.role,
      email: row.email,
      phone: row.phone,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
      deletedAt: row.deletedAt != null
          ? DateTime.fromMillisecondsSinceEpoch(row.deletedAt!)
          : null,
    );
  }

  db.ContactsCompanion toCompanion(domain.Contact contact) {
    return db.ContactsCompanion(
      id: Value(contact.id),
      name: Value(contact.name),
      role: Value(contact.role),
      email: Value(contact.email),
      phone: Value(contact.phone),
      createdAt: Value(contact.createdAt.millisecondsSinceEpoch),
      updatedAt: Value(contact.updatedAt.millisecondsSinceEpoch),
      deletedAt: Value(contact.deletedAt?.millisecondsSinceEpoch),
    );
  }
}
