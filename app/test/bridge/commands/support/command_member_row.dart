import 'dart:math';

import 'package:agent_orchestration/bridge/commands/node_command.dart';

typedef CommandConstruction = ({
  NodeCommand<Object?> command,
  List<Object?> givenFields,
  List<Object?> keptFields,
});

typedef CommandConstructor = CommandConstruction Function(Random random);

final class CommandMemberRow {
  const CommandMemberRow({
    required this.typeName,
    required this.commandName,
    required this.construct,
  });

  final String typeName;
  final String commandName;
  final CommandConstructor construct;
}

CommandConstruction constructWithoutFields(NodeCommand<Object?> command) {
  return (
    command: command,
    givenFields: const <Object?>[],
    keptFields: const <Object?>[],
  );
}
