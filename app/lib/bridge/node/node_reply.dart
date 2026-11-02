import 'dart:convert';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/node/node_command_failure.dart';

const String successReplyField = 'ok';
const String errorReplyField = 'error';

Object? readNodeReply(String replyJson) {
  final JsonObject reply = decodeObject(jsonDecode(replyJson));
  if (reply.containsKey(errorReplyField)) {
    final String message = readField(reply, errorReplyField, decodeText);
    throw NodeCommandFailure(message);
  }
  if (!reply.containsKey(successReplyField)) {
    throw FormatException('the node reply has neither ok nor error: $reply');
  }
  return reply[successReplyField];
}
