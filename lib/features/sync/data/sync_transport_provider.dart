import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/sync_transport.dart';
import 'http_sync_transport.dart';

/// Transport boundary for push/pull.
///
/// ## Default: HTTP (8c layer 2)
/// Points at the local dumb server (`http://127.0.0.1:8080`) using
/// `SYNC_API_KEY` from the process environment. This is a **dev
/// default only** — 8c-4 replaces it with app_settings-driven config
/// (server URL, key, `syncEnabled`).
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
  // 8c-4: read serverUrl / apiKey / syncEnabled from app_settings.
  return HttpSyncTransport(
    baseUrl: Platform.environment['SYNC_BASE_URL'] ?? 'http://127.0.0.1:8080',
    apiKey: Platform.environment['SYNC_API_KEY'] ?? '',
    // Explicit and required — never true by accident.
    allowSelfSigned: false,
  );
});
