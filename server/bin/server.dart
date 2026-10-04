import 'dart:async';
import 'dart:io';

import 'package:taskmaster_sync_server/server.dart';

Future<void> main(List<String> args) async {
  final config = ServerConfig.fromEnvironment();
  final log = await EventLog.open(config.logPath);
  final server = SyncServer(config: config, log: log);

  await server.start();
  stdout.writeln(
    'taskmaster sync server listening on '
    '${config.useTls ? 'https' : 'http'}://${config.host}:${server.port} '
    '(log: ${config.logPath}, lastSeq: ${log.lastSeq})',
  );

  var stopping = false;
  Future<void> shutdown(String signal) async {
    if (stopping) return;
    stopping = true;
    stdout.writeln('received $signal — draining in-flight requests…');
    await server.stop();
    stdout.writeln('shutdown complete (exit 0)');
    exit(0);
  }

  ProcessSignal.sigterm.watch().listen((_) => shutdown('SIGTERM'));
  ProcessSignal.sigint.watch().listen((_) => shutdown('SIGINT'));

  // Park until a signal triggers shutdown → exit(0).
  final never = Completer<void>();
  await never.future;
}
