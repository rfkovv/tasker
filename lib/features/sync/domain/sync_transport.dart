import 'sync_event.dart';

/// Transport boundary for push and pull.
///
/// Layer 2 ships only an in-process fake ([InMemorySyncTransport] in
/// data/). The 8c HTTP adapter implements this same interface against
/// `POST /sync/push` and `GET /sync/pull` — no protocol changes at the
/// engine boundary.
abstract class SyncTransport {
  /// Uploads [events] as one batch.
  ///
  /// Throws [SyncTransportException] (or any error) on failure. The push
  /// engine leaves the outbox untouched when this throws — there are no
  /// partial sends.
  Future<void> pushBatch(List<SyncEvent> events);

  /// Fetches server-log events with sequence strictly after [cursor].
  ///
  /// [cursor] null means "never pulled" — return the full log (8c will
  /// replace this with an explicit full-sync strategy). [nextCursor] is
  /// the sequence to pass on the following pull; null when no new events.
  Future<SyncPullResponse> pullSince(String? cursor);
}

class SyncPullResponse {
  const SyncPullResponse({required this.events, required this.nextCursor});

  final List<SyncEvent> events;

  /// Cursor for the next pull; unchanged/null when [events] is empty.
  final String? nextCursor;
}

class SyncTransportException implements Exception {
  SyncTransportException(this.message);

  final String message;

  @override
  String toString() => 'SyncTransportException: $message';
}
