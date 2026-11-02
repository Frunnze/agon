import 'package:agent_orchestration/bridge/commands/node_command.dart';
import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/bridge/node/node_command_failure.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

const String _notFoundSuffix = ' was not found';
const String _wordSeparator = ' ';

Object translateNodeFailure(NodeCommandFailure failure) {
  final String message = failure.message;
  if (!message.endsWith(_notFoundSuffix)) {
    return StateError(message);
  }

  final String subject = message.substring(
    0,
    message.length - _notFoundSuffix.length,
  );
  final int identifierStart = subject.lastIndexOf(_wordSeparator);
  if (identifierStart <= 0) {
    return StateError(message);
  }

  return RecordNotFound(
    kind: subject.substring(0, identifierStart),
    identifier: subject.substring(identifierStart + _wordSeparator.length),
  );
}

Future<Result> executeNodeCommand<Result>(
  NodeCommandChannel channel,
  NodeCommand<Result> command,
) async {
  try {
    return await channel.execute(command);
  } on NodeCommandFailure catch (failure, stackTrace) {
    Error.throwWithStackTrace(translateNodeFailure(failure), stackTrace);
  }
}
