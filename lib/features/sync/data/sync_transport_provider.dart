import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/sync_transport.dart';
import 'http_sync_transport.dart';
import 'sync_endpoint_config.dart';

/// Transport boundary for push/pull.
///
/// ## Default: HTTP via compile-time config (8c layer 4)
/// [SyncEndpointConfig.fromEnvironment] reads `--dart-define` values
/// (`SYNC_BASE_URL`, `SYNC_API_KEY`, `SYNC_ALLOW_SELF_SIGNED`). Process
/// environment variables are not a config path.
///
/// ## In-memory fake still available
/// [InMemorySyncTransport] remains exported from the sync barrel and is
/// injected directly in unit tests (push/pull/coordinator) — those
/// suites never read this provider's default.
///
/// ## Offline invariant
/// With no server reachable, [HttpSyncTransport] throws
/// [SyncTransportException]; the coordinator returns to idle and the app
/// behaves identically to today (local-first).
final syncTransportProvider = Provider<SyncTransport>((ref) {
  return createSyncTransport(SyncEndpointConfig.fromEnvironment());
});

/// Builds the production [HttpSyncTransport] from resolved config.
///
/// Extracted so tests can assert wiring without reading the provider,
/// and so the provider stays a one-liner.
SyncTransport createSyncTransport(SyncEndpointConfig config) {
  return HttpSyncTransport(
    baseUrl: config.baseUrl,
    apiKey: config.apiKey,
    allowSelfSigned: config.allowSelfSigned,
  );
}
