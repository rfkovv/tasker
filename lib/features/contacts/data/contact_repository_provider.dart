import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../local_db/providers/database_provider.dart';
import '../domain/contact_repository.dart';
import 'contact_repository_impl.dart';

final contactRepositoryProvider = Provider<ContactRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return ContactRepositoryImpl(dao: db.contactsDao);
});
