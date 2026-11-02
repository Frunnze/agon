import 'dart:convert';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/commands/node_command.dart';
import 'package:agent_orchestration/bridge/native/node_entry_point.dart';
import 'package:agent_orchestration/bridge/node/node_reply.dart';
import 'package:agent_orchestration/bridge/node/node_transport.dart';

final class NodeCommandChannel {
  const NodeCommandChannel({required this.transport});

  final NodeTransport transport;

  Future<Object?> send(JsonObject command) async {
    final String replyJson = await transport.exchange(
      entryPoint: NodeEntryPoint.handleCommand,
      inputJson: jsonEncode(command),
    );
    return readNodeReply(replyJson);
  }

  Future<Result> execute<Result>(NodeCommand<Result> command) async {
    final Object? okValue = await send(encodeNodeCommand(command));
    return command.decodeReply(okValue);
  }
}
