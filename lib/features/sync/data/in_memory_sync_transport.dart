import '../domain/sync_event.dart';
import '../domain/sync_transport.dart';

/// In-process fake transport for tests and local development.
///
/// Records every attempted and every successful batch. Failure injection
/// via [failNextCalls]: the next N `pushBatch` calls throw
/// [SyncTransportException] and are NOT recorded as delivered.
class InMemorySyncTransport implements SyncTransport {
  InMemorySyncTransport({this.failNextCalls = 0});

  /// Number of upcoming [pushBatch] calls that should fail.
  int failNextCalls;

  /// Every [pushBatch] invocation, including ones that failed.
  final List<List<SyncEvent>> attemptedBatches = [];

  /// Batches that completed successfully (i.e. were "delivered").
  final List<List<SyncEvent>> deliveredBatches = [];

  /// Flat view of all successfully delivered events, in order.
  List<SyncEvent> get deliveredEvents => [
        for (final batch in deliveredBatches) ...batch,
      ];

  @override
  Future<void> pushBatch(List<SyncEvent> events) async {
    attemptedBatches.add(List<SyncEvent>.of(events));
    if (failNextCalls > 0) {
      failNextCalls--;
      throw SyncTransportException('injected failure');
    }
    deliveredBatches.add(List<SyncEvent>.of(events));
  }
}
