import 'package:flutter/foundation.dart';

/// Compile-time sync endpoint configuration (8c layer 4).
///
/// Values are read exclusively from `--dart-define` at build time via
/// [String.fromEnvironment]:
/// - `SYNC_BASE_URL`
/// - `SYNC_API_KEY`
/// - `SYNC_ALLOW_SELF_SIGNED`
///
/// Architectural invariant: the endpoint is part of the app release, not
/// user data. One fixed sync server. No runtime configuration UI or
/// storage. Process environment variables are NOT a config path — they
/// die with this layer.
///
/// ## Dev fallbacks (used when a define is absent)
/// - [defaultBaseUrl] — local dumb server
/// - [defaultApiKey] — documented placeholder; replace before any shared
///   environment
/// - [defaultAllowSelfSigned] — `true` TEMPORARY until the sync domain
///   has a real certificate (Let's Encrypt). Backlog item: must be
///   `false` in release builds that point at a real endpoint.
///
/// ## Release warning
/// When [SyncEndpointConfig.fromEnvironment] resolves with an empty
/// `SYNC_BASE_URL` in a release build, a loud warning naming the missing
/// define is logged. Dev builds stay silent (fallback is intentional).
class SyncEndpointConfig {
  const SyncEndpointConfig({
    required this.baseUrl,
    required this.apiKey,
    required this.allowSelfSigned,
  });

  /// Resolves config from compile-time `--dart-define` values.
  ///
  /// [releaseMode] defaults to [kReleaseMode]; tests inject `true` to
  /// exercise the missing-define warning without a release build.
  /// [logger] defaults to `debugPrint` — tests capture the warning.
  factory SyncEndpointConfig.fromEnvironment({
    bool? releaseMode,
    void Function(String message)? logger,
  }) {
    return SyncEndpointConfig.resolve(
      baseUrlDefine: const String.fromEnvironment(baseUrlDefine),
      apiKeyDefine: const String.fromEnvironment(apiKeyDefine),
      allowSelfSignedDefine:
          const String.fromEnvironment(allowSelfSignedDefine),
      releaseMode: releaseMode ?? kReleaseMode,
      logger: logger,
    );
  }

  /// Pure resolution of define strings → config. Testable without
  /// `--dart-define`.
  ///
  /// Empty/absent defines fall back to the dev defaults. When
  /// [releaseMode] is true and [baseUrlDefine] is empty, a warning naming
  /// [baseUrlDefine] is emitted via [logger].
  factory SyncEndpointConfig.resolve({
    required String? baseUrlDefine,
    required String? apiKeyDefine,
    required String? allowSelfSignedDefine,
    bool releaseMode = false,
    void Function(String message)? logger,
  }) {
    final rawBaseUrl = baseUrlDefine ?? '';
    final rawApiKey = apiKeyDefine ?? '';
    final rawAllowSelfSigned = allowSelfSignedDefine ?? '';

    if (releaseMode && rawBaseUrl.isEmpty) {
      // Name the DEFINE (static const), not the empty parameter value.
      const defineName = SyncEndpointConfig.baseUrlDefine;
      (logger ?? _defaultLogger)(
        'WARNING: $defineName is not defined via --dart-define. '
        'This release build will sync against the dev fallback '
        '$defaultBaseUrl. Define $defineName at build time '
        '(flutter build --dart-define=$defineName=https://...).',
      );
    }

    return SyncEndpointConfig(
      baseUrl: rawBaseUrl.isEmpty ? defaultBaseUrl : rawBaseUrl,
      apiKey: rawApiKey.isEmpty ? defaultApiKey : rawApiKey,
      allowSelfSigned: rawAllowSelfSigned.isEmpty
          ? defaultAllowSelfSigned
          : rawAllowSelfSigned.toLowerCase() == 'true',
    );
  }

  static const String baseUrlDefine = 'SYNC_BASE_URL';
  static const String apiKeyDefine = 'SYNC_API_KEY';
  static const String allowSelfSignedDefine = 'SYNC_ALLOW_SELF_SIGNED';

  /// Dev fallback base URL — local dumb 8c server.
  static const String defaultBaseUrl = 'http://127.0.0.1:8080';

  /// Documented placeholder API key for dev builds.
  ///
  /// Not a secret. Replace via `--dart-define=SYNC_API_KEY=...` for any
  /// shared or production server.
  static const String defaultApiKey = 'dev-placeholder-key';

  /// Dev fallback for TLS certificate verification.
  ///
  /// TEMPORARY until domain + Let's Encrypt (backlog). Intentionally
  /// `true` only as the absent-define fallback for local dev.
  static const bool defaultAllowSelfSigned = true;

  /// Resolved server base URL (never empty).
  final String baseUrl;

  /// Resolved Bearer API key (never empty).
  final String apiKey;

  /// Whether TLS certificate verification is disabled.
  final bool allowSelfSigned;

  static void _defaultLogger(String message) {
    // Loud by design — release builds missing SYNC_BASE_URL must be seen.
    debugPrint(message);
  }

  @override
  bool operator ==(Object other) {
    return other is SyncEndpointConfig &&
        other.baseUrl == baseUrl &&
        other.apiKey == apiKey &&
        other.allowSelfSigned == allowSelfSigned;
  }

  @override
  int get hashCode => Object.hash(baseUrl, apiKey, allowSelfSigned);

  @override
  String toString() =>
      'SyncEndpointConfig(baseUrl: $baseUrl, apiKey: ***, '
      'allowSelfSigned: $allowSelfSigned)';
}
