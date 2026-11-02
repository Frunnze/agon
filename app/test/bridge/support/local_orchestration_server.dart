import 'dart:async';
import 'dart:io';

const String _loopbackHost = '127.0.0.1';
const String _setupCodeFileName = 'setup-code';
const Duration _readinessPause = Duration(milliseconds: 50);
const Duration _readinessLimit = Duration(seconds: 20);

final class LocalOrchestrationServer {
  LocalOrchestrationServer._({
    required this.process,
    required this.programPath,
    required this.port,
    required this.dataDirectory,
  });

  final Process process;
  final String programPath;
  final int port;
  final Directory dataDirectory;

  String get address => 'http://$_loopbackHost:$port';

  static Future<LocalOrchestrationServer> start({
    required String programPath,
    required Directory dataDirectory,
  }) async {
    final int port = await findFreePort();
    return startOnPort(
      programPath: programPath,
      dataDirectory: dataDirectory,
      port: port,
    );
  }

  static Future<LocalOrchestrationServer> startOnPort({
    required String programPath,
    required Directory dataDirectory,
    required int port,
  }) async {
    final Process process = await Process.start(programPath, <String>[
      '--listen',
      '$_loopbackHost:$port',
      '--data-directory',
      dataDirectory.path,
    ]);
    unawaited(process.stdout.drain<void>());
    unawaited(process.stderr.drain<void>());

    final LocalOrchestrationServer server = LocalOrchestrationServer._(
      process: process,
      programPath: programPath,
      port: port,
      dataDirectory: dataDirectory,
    );
    await server._waitUntilListening();
    return server;
  }

  String readSetupCode() {
    final File setupCodeFile = File(
      '${dataDirectory.path}/$_setupCodeFileName',
    );
    return setupCodeFile.readAsStringSync().trim();
  }

  Future<void> stop() async {
    process.kill();
    await process.exitCode;
  }

  Future<LocalOrchestrationServer> restart() async {
    await stop();
    return startOnPort(
      programPath: programPath,
      dataDirectory: dataDirectory,
      port: port,
    );
  }

  Future<void> _waitUntilListening() async {
    final DateTime deadline = DateTime.now().add(_readinessLimit);
    while (DateTime.now().isBefore(deadline)) {
      final bool isListening = await _acceptsConnections();
      if (isListening) {
        return;
      }
      await Future<void>.delayed(_readinessPause);
    }
    await stop();
    throw StateError('the orchestration server did not start on $port');
  }

  Future<bool> _acceptsConnections() async {
    try {
      final Socket socket = await Socket.connect(_loopbackHost, port);
      socket.destroy();
      return true;
    } on SocketException {
      return false;
    }
  }
}

Future<int> findFreePort() async {
  final ServerSocket probe = await ServerSocket.bind(_loopbackHost, 0);
  final int port = probe.port;
  await probe.close();
  return port;
}
