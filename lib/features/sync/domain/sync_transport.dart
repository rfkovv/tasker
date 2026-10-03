import 'sync_event.dart';

/// Transport boundary for the push path.
///
/// Layer 2 ships only an in-process fake ([InMemorySyncTransport] in
/// data/). The 8c HTTP adapter implements this same interface against
/// `POST /sync/push` — no protocol changes at the engine boundary.
abstract class SyncTransport {
  /// Uploads [events] as one batch.
  ///
  /// Throws [SyncTransportException] (or any error) on failure. The push
  /// engine leaves the outbox untouched when this throws — there are no
  /// partial sends.
  Future<void> pushBatch(List<SyncEvent> events);
}

class SyncTransportException implements Exception {
  SyncTransportException(this.message);

  final String message;

  @override
  String toString() => 'SyncTransportException: $message';
}
