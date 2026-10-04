import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/sync_transport.dart';
import 'in_memory_sync_transport.dart';

/// Transport boundary for push/pull.
///
/// Layer 4 ships the in-process fake. The 8c HTTP adapter overrides this
/// provider — engines and the coordinator are unchanged.
final syncTransportProvider = Provider<SyncTransport>((ref) {
  return InMemorySyncTransport();
});
