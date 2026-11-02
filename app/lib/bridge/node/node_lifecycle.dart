import 'dart:convert';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/native/node_entry_point.dart';
import 'package:agent_orchestration/bridge/node/node_reply.dart';
import 'package:agent_orchestration/bridge/node/node_start_configuration.dart';
import 'package:agent_orchestration/bridge/node/node_transport.dart';

Future<void> startNode({
  required NodeTransport transport,
  required NodeStartConfiguration configuration,
}) async {
  final String replyJson = await transport.exchange(
    entryPoint: NodeEntryPoint.start,
    inputJson: jsonEncode(configuration.toJson()),
  );
  decodeNothing(readNodeReply(replyJson));
}

Future<void> stopNode(NodeTransport transport) async {
  final String replyJson = await transport.stop();
  decodeNothing(readNodeReply(replyJson));
}
