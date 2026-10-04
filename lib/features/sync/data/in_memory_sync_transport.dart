import '../domain/sync_event.dart';
import '../domain/sync_transport.dart';

/// In-process fake transport for tests and local development.
///
/// Simulates a dumb server log: [pushBatch] appends events with
/// monotonically increasing sequence numbers; [pullSince] serves events
/// with seq > cursor. Push and pull share one log.
///
/// Failure injection: [failNextCalls] for push, [failNextPullCalls] for
/// pull. Failed calls are not recorded as delivered / do not advance
/// anything server-side beyond what was already logged.
class InMemorySyncTransport implements SyncTransport {
  InMemorySyncTransport({this.failNextCalls = 0});

  /// Number of upcoming [pushBatch] calls that should fail.
  int failNextCalls;

  /// Number of upcoming [pullSince] calls that should fail.
  int failNextPullCalls = 0;

  /// How many times [pullSince] was invoked (tests / diagnostics).
  int pullCallCount = 0;

  /// Every [pushBatch] invocation, including ones that failed.
  final List<List<SyncEvent>> attemptedBatches = [];

  /// Batches that completed successfully (i.e. were "delivered").
  final List<List<SyncEvent>> deliveredBatches = [];

  /// Flat view of all successfully delivered events, in order.
  List<SyncEvent> get deliveredEvents => [
        for (final batch in deliveredBatches) ...batch,
      ];

  final List<({int seq, SyncEvent event})> _serverLog = [];
  int _nextSeq = 1;

  /// Server log contents (seq, event) for assertions.
  List<({int seq, SyncEvent event})> get serverLog =>
      List.unmodifiable(_serverLog);

  @override
  Future<void> pushBatch(List<SyncEvent> events) async {
    attemptedBatches.add(List<SyncEvent>.of(events));
    if (failNextCalls > 0) {
      failNextCalls--;
      throw SyncTransportException('injected push failure');
    }
    for (final event in events) {
      _serverLog.add((seq: _nextSeq++, event: event));
    }
    deliveredBatches.add(List<SyncEvent>.of(events));
  }

  @override
  Future<SyncPullResponse> pullSince(String? cursor) async {
    pullCallCount++;
    if (failNextPullCalls > 0) {
      failNextPullCalls--;
      throw SyncTransportException('injected pull failure');
    }
    final after = cursor == null ? 0 : (int.tryParse(cursor) ?? 0);
    final matching =
        _serverLog.where((r) => r.seq > after).toList(growable: false);
    if (matching.isEmpty) {
      return SyncPullResponse(events: const [], nextCursor: cursor);
    }
    return SyncPullResponse(
      events: [for (final r in matching) r.event],
      nextCursor: matching.last.seq.toString(),
    );
  }
}
