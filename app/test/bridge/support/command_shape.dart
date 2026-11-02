import 'dart:math';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/commands/node_command.dart';

import 'node_json_primitives.dart';

typedef CommandBuilder = NodeCommand<Object?> Function(Random random);

typedef ReplyEncoder = Object? Function(Object? decodedReply);

final class CommandShape {
  const CommandShape({
    required this.commandName,
    required this.argumentFields,
    required this.buildCommand,
    required this.buildReplyJson,
    required this.encodeReply,
  });

  final String commandName;
  final Set<String> argumentFields;
  final CommandBuilder buildCommand;
  final NodeJsonBuilder buildReplyJson;
  final ReplyEncoder encodeReply;
}

Object? buildNoReply(Random random) => null;

Object? encodeNoReply(Object? decodedReply) => decodedReply;

Object? encodeValueReply(Object? decodedReply) {
  final JsonEncodable value = decodedReply! as JsonEncodable;
  return value.toJson();
}

Object? encodeListReply(Object? decodedReply) {
  final List<JsonEncodable> values = decodedReply! as List<JsonEncodable>;
  return encodeList(values);
}
