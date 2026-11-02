import 'package:agent_orchestration/bridge/codecs/json_values.dart';

const String commandNameField = 'command';

const JsonObject noArguments = <String, Object?>{};

abstract interface class NodeCommand<Result> {
  String get name;

  JsonObject get arguments;

  Result decodeReply(Object? okValue);
}

JsonObject encodeNodeCommand(NodeCommand<Object?> command) {
  return <String, Object?>{
    commandNameField: command.name,
    ...command.arguments,
  };
}
