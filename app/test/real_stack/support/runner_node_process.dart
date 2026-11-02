import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';

import '../../bridge/support/host_node_files.dart';

const String _successKey = 'ok';
const String _failureKey = 'error';

final class RunnerNodeFailure implements Exception {
  const RunnerNodeFailure(this.message);

  final String message;

  @override
  String toString() => 'RunnerNodeFailure: $message';
}

final class RunnerNodeProcess {
  RunnerNodeProcess._({
    required Process process,
    required StreamIterator<String> replies,
  }) : _process = process,
       _replies = replies;

  final Process _process;
  final StreamIterator<String> _replies;

  static Future<RunnerNodeProcess> start({
    required JsonObject configuration,
    required Map<String, String> environment,
  }) async {
    final Process process = await Process.start(
      nodeHostProgramPath(),
      const <String>[],
      environment: environment,
    );
    unawaited(process.stderr.drain<void>());
    final Stream<String> replyLines = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter());
    final RunnerNodeProcess node = RunnerNodeProcess._(
      process: process,
      replies: StreamIterator<String>(replyLines),
    );

    await node.run(configuration);
    return node;
  }

  Future<Object?> run(JsonObject command) async {
    final JsonObject reply = await _exchange(command);
    if (reply.containsKey(_failureKey)) {
      throw RunnerNodeFailure('${reply[_failureKey]}');
    }
    return reply[_successKey];
  }

  Future<String?> readProblem(JsonObject command) async {
    final JsonObject reply = await _exchange(command);
    final Object? problem = reply[_failureKey];
    if (problem == null) {
      return null;
    }
    return '$problem';
  }

  Future<void> stop() async {
    await _process.stdin.close();
    _process.kill();
    await _process.exitCode;
  }

  Future<JsonObject> _exchange(JsonObject command) async {
    _process.stdin.writeln(jsonEncode(command));
    await _process.stdin.flush();

    final bool hasReply = await _replies.moveNext();
    if (!hasReply) {
      throw const RunnerNodeFailure('the runner node process ended');
    }
    final Object? reply = jsonDecode(_replies.current);
    if (reply is! JsonObject) {
      throw RunnerNodeFailure('the runner node replied $reply');
    }
    return reply;
  }
}
