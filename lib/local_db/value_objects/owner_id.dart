import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../providers/database_provider.dart';

const _ownerIdKey = 'owner_id';

class OwnerId {
  const OwnerId._();

  static String generate() => const Uuid().v4();
}

final ownerIdProvider = FutureProvider<String>((ref) async {
  final db = ref.watch(databaseProvider);
  final existing = await db.lookupSettings(_ownerIdKey);
  if (existing != null) return existing;
  final id = OwnerId.generate();
  await db.storeSetting(_ownerIdKey, id);
  return id;
});
