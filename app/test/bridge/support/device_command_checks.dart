import 'dart:convert';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/commands/node_command.dart';

const List<Object?> emptyLookingReplies = <Object?>[
  false,
  0,
  0.0,
  -0.0,
  '',
  ' ',
  'null',
  <Object?>[],
  <String, Object?>{},
  <Object?>[null],
  <String, Object?>{'ok': null},
];

Object? rereadJsonThroughText(Object? json) {
  final String jsonText = jsonEncode(json);
  return jsonDecode(jsonText);
}

JsonObject rereadCommandThroughText(NodeCommand<Object?> command) {
  final Object? rereadCommand = rereadJsonThroughText(
    encodeNodeCommand(command),
  );
  return decodeObject(rereadCommand);
}
