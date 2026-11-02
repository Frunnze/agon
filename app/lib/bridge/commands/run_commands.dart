import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/run_chat_values.dart';
import 'package:agent_orchestration/bridge/codecs/run_progress_values.dart';
import 'package:agent_orchestration/bridge/codecs/run_values.dart';
import 'package:agent_orchestration/bridge/commands/node_command.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

final class ListRunsCommand implements NodeCommand<List<Run>> {
  const ListRunsCommand({required this.taskId});

  final TaskId taskId;

  @override
  String get name => 'list_runs';

  @override
  JsonObject get arguments => <String, Object?>{'task_id': taskId.value};

  @override
  List<Run> decodeReply(Object? okValue) {
    return decodeList(okValue, Run.fromJson);
  }
}

final class ShowRunCommand implements NodeCommand<RunView> {
  const ShowRunCommand({required this.runId});

  final RunId runId;

  @override
  String get name => 'show_run';

  @override
  JsonObject get arguments => <String, Object?>{'run_id': runId.value};

  @override
  RunView decodeReply(Object? okValue) => RunView.fromJson(okValue);
}

final class CancelRunCommand implements NodeCommand<void> {
  const CancelRunCommand({required this.runId});

  final RunId runId;

  @override
  String get name => 'cancel_run';

  @override
  JsonObject get arguments => <String, Object?>{'run_id': runId.value};

  @override
  void decodeReply(Object? okValue) => decodeNothing(okValue);
}

final class RetryRunCommand implements NodeCommand<void> {
  const RetryRunCommand({required this.runId});

  final RunId runId;

  @override
  String get name => 'retry_run';

  @override
  JsonObject get arguments => <String, Object?>{'run_id': runId.value};

  @override
  void decodeReply(Object? okValue) => decodeNothing(okValue);
}

final class SendChatMessageCommand implements NodeCommand<ChatMessage> {
  const SendChatMessageCommand({
    required this.workspaceId,
    required this.runId,
    required this.text,
  });

  final WorkspaceId workspaceId;
  final RunId runId;
  final String text;

  @override
  String get name => 'send_chat_message';

  @override
  JsonObject get arguments {
    return <String, Object?>{
      'workspace_id': workspaceId.value,
      'run_id': runId.value,
      'text': text,
    };
  }

  @override
  ChatMessage decodeReply(Object? okValue) => ChatMessage.fromJson(okValue);
}
