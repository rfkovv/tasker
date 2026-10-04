import 'dart:io';

/// Runtime configuration from environment variables.
///
/// | Variable         | Default              | Notes                                      |
/// |------------------|----------------------|--------------------------------------------|
/// | SYNC_HOST        | 0.0.0.0              | Bind address                               |
/// | SYNC_PORT        | 8080                 | TCP port                                   |
/// | SYNC_API_KEY     | (unset)              | Bearer key; missing → all /events 401      |
/// | SYNC_LOG_PATH    | ./sync_events.ndjson | Append-only NDJSON log                     |
/// | SYNC_CERT_PATH   | (unset)              | TLS cert; with key → HTTPS                 |
/// | SYNC_KEY_PATH    | (unset)              | TLS private key                            |
class ServerConfig {
  const ServerConfig({
    required this.port,
    required this.host,
    required this.apiKey,
    required this.logPath,
    this.certPath,
    this.keyPath,
  });

  factory ServerConfig.fromEnvironment() {
    final env = Platform.environment;
    return ServerConfig(
      port: int.tryParse(env['SYNC_PORT'] ?? '') ?? 8080,
      host: env['SYNC_HOST'] ?? '0.0.0.0',
      apiKey: env['SYNC_API_KEY'] ?? '',
      logPath: env['SYNC_LOG_PATH'] ?? 'sync_events.ndjson',
      certPath: _nonEmpty(env['SYNC_CERT_PATH']),
      keyPath: _nonEmpty(env['SYNC_KEY_PATH']),
    );
  }

  final int port;
  final String host;
  final String apiKey;
  final String logPath;
  final String? certPath;
  final String? keyPath;

  bool get useTls =>
      certPath != null &&
      certPath!.isNotEmpty &&
      keyPath != null &&
      keyPath!.isNotEmpty;

  static String? _nonEmpty(String? value) {
    if (value == null || value.isEmpty) return null;
    return value;
  }
}
