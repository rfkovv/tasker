import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskmaster/features/sync/sync.dart';
import 'package:taskmaster/local_db/database.dart' as db;
import 'package:taskmaster/local_db/providers/database_provider.dart';
import 'package:drift/native.dart';

void main() {
  group('SyncEndpointConfig.resolve', () {
    test('present defines → used verbatim', () {
      final config = SyncEndpointConfig.resolve(
        baseUrlDefine: 'https://sync.example.com',
        apiKeyDefine: 'prod-key-123',
        allowSelfSignedDefine: 'false',
      );

      expect(config.baseUrl, 'https://sync.example.com');
      expect(config.apiKey, 'prod-key-123');
      expect(config.allowSelfSigned, isFalse);
    });

    test('absent defines → dev fallbacks', () {
      final config = SyncEndpointConfig.resolve(
        baseUrlDefine: '',
        apiKeyDefine: '',
        allowSelfSignedDefine: '',
      );

      expect(config.baseUrl, SyncEndpointConfig.defaultBaseUrl);
      expect(config.baseUrl, 'http://127.0.0.1:8080');
      expect(config.apiKey, SyncEndpointConfig.defaultApiKey);
      expect(config.apiKey, 'dev-placeholder-key');
      expect(config.allowSelfSigned, isTrue,
          reason: 'dev fallback is true (temporary; see class doc)');
    });

    test('null defines treated as absent → dev fallbacks', () {
      final config = SyncEndpointConfig.resolve(
        baseUrlDefine: null,
        apiKeyDefine: null,
        allowSelfSignedDefine: null,
      );

      expect(config.baseUrl, SyncEndpointConfig.defaultBaseUrl);
      expect(config.apiKey, SyncEndpointConfig.defaultApiKey);
      expect(config.allowSelfSigned, isTrue);
    });

    test('release-mode missing SYNC_BASE_URL → loud warning naming the define',
        () {
      final warnings = <String>[];

      final config = SyncEndpointConfig.resolve(
        baseUrlDefine: '',
        apiKeyDefine: 'k',
        allowSelfSignedDefine: 'false',
        releaseMode: true,
        logger: warnings.add,
      );

      expect(warnings, hasLength(1));
      expect(warnings.single, contains(SyncEndpointConfig.baseUrlDefine));
      expect(warnings.single, contains('SYNC_BASE_URL'));
      expect(warnings.single, contains('WARNING'));
      expect(config.baseUrl, SyncEndpointConfig.defaultBaseUrl,
          reason: 'fallback still applied after warning');
    });

    test('dev-mode missing SYNC_BASE_URL → no warning', () {
      final warnings = <String>[];

      SyncEndpointConfig.resolve(
        baseUrlDefine: '',
        apiKeyDefine: '',
        allowSelfSignedDefine: '',
        releaseMode: false,
        logger: warnings.add,
      );

      expect(warnings, isEmpty);
    });

    test('release-mode with SYNC_BASE_URL present → no warning', () {
      final warnings = <String>[];

      final config = SyncEndpointConfig.resolve(
        baseUrlDefine: 'https://sync.example.com',
        apiKeyDefine: 'k',
        allowSelfSignedDefine: 'false',
        releaseMode: true,
        logger: warnings.add,
      );

      expect(warnings, isEmpty);
      expect(config.baseUrl, 'https://sync.example.com');
    });

    test('SYNC_ALLOW_SELF_SIGNED parses case-insensitively', () {
      expect(
        SyncEndpointConfig.resolve(
          baseUrlDefine: 'https://x',
          apiKeyDefine: 'k',
          allowSelfSignedDefine: 'TRUE',
        ).allowSelfSigned,
        isTrue,
      );
      expect(
        SyncEndpointConfig.resolve(
          baseUrlDefine: 'https://x',
          apiKeyDefine: 'k',
          allowSelfSignedDefine: 'False',
        ).allowSelfSigned,
        isFalse,
      );
      expect(
        SyncEndpointConfig.resolve(
          baseUrlDefine: 'https://x',
          apiKeyDefine: 'k',
          allowSelfSignedDefine: '1',
        ).allowSelfSigned,
        isFalse,
        reason: 'only the literal true enables self-signed',
      );
    });
  });

  group('SyncEndpointConfig.fromEnvironment', () {
    test('test build (no --dart-define) → dev fallbacks, no release warning',
        () {
      final warnings = <String>[];
      final config = SyncEndpointConfig.fromEnvironment(
        releaseMode: false,
        logger: warnings.add,
      );

      expect(config.baseUrl, SyncEndpointConfig.defaultBaseUrl);
      expect(config.apiKey, SyncEndpointConfig.defaultApiKey);
      expect(config.allowSelfSigned, SyncEndpointConfig.defaultAllowSelfSigned);
      expect(warnings, isEmpty);
    });

    test('injected releaseMode + empty env → warning path exercised', () {
      final warnings = <String>[];
      final config = SyncEndpointConfig.fromEnvironment(
        releaseMode: true,
        logger: warnings.add,
      );

      expect(warnings, hasLength(1));
      expect(warnings.single, contains('SYNC_BASE_URL'));
      expect(config.baseUrl, isNotEmpty);
    });
  });

  group('createSyncTransport / syncTransportProvider', () {
    test('createSyncTransport wires config values into HttpSyncTransport', () {
      const config = SyncEndpointConfig(
        baseUrl: 'https://sync.example.com',
        apiKey: 'key-abc',
        allowSelfSigned: false,
      );

      final transport = createSyncTransport(config);

      expect(transport, isA<HttpSyncTransport>());
      final http = transport as HttpSyncTransport;
      expect(http.baseUrl, 'https://sync.example.com');
      expect(http.apiKey, 'key-abc');
      expect(http.allowSelfSigned, isFalse);
    });

    test('provider returns HttpSyncTransport wired with fromEnvironment()',
        () async {
      final dbOverride = db.AppDatabase(NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(dbOverride)],
      );
      addTearDown(() async {
        container.dispose();
        await dbOverride.close();
      });

      final transport = container.read(syncTransportProvider);
      final expected = SyncEndpointConfig.fromEnvironment();

      expect(transport, isA<HttpSyncTransport>());
      final http = transport as HttpSyncTransport;
      expect(http.baseUrl, expected.baseUrl);
      expect(http.apiKey, expected.apiKey);
      expect(http.allowSelfSigned, expected.allowSelfSigned);
    });

    test('provider default is NOT InMemory (constructor injection stays for '
        'unit tests)', () async {
      final dbOverride = db.AppDatabase(NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(dbOverride)],
      );
      addTearDown(() async {
        container.dispose();
        await dbOverride.close();
      });

      expect(
        container.read(syncTransportProvider),
        isNot(isA<InMemorySyncTransport>()),
        reason: 'InMemory remains a direct-injection test fake only',
      );
    });
  });
}
