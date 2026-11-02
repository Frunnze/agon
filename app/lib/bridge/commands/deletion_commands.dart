import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/commands/node_command.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

final class DeleteProjectCommand implements NodeCommand<void> {
  const DeleteProjectCommand({required this.projectId});

  final ProjectId projectId;

  @override
  String get name => 'delete_project';

  @override
  JsonObject get arguments {
    return <String, Object?>{'project_id': projectId.value};
  }

  @override
  void decodeReply(Object? okValue) => decodeNothing(okValue);
}

final class DeleteWorkflowCommand implements NodeCommand<void> {
  const DeleteWorkflowCommand({required this.workflowId});

  final WorkflowId workflowId;

  @override
  String get name => 'delete_workflow';

  @override
  JsonObject get arguments {
    return <String, Object?>{'workflow_id': workflowId.value};
  }

  @override
  void decodeReply(Object? okValue) => decodeNothing(okValue);
}

final class DeleteTaskCommand implements NodeCommand<void> {
  const DeleteTaskCommand({required this.taskId});

  final TaskId taskId;

  @override
  String get name => 'delete_task';

  @override
  JsonObject get arguments => <String, Object?>{'task_id': taskId.value};

  @override
  void decodeReply(Object? okValue) => decodeNothing(okValue);
}

final class DeleteWorkspaceCommand implements NodeCommand<void> {
  const DeleteWorkspaceCommand({required this.workspaceId});

  final WorkspaceId workspaceId;

  @override
  String get name => 'delete_workspace';

  @override
  JsonObject get arguments {
    return <String, Object?>{'workspace_id': workspaceId.value};
  }

  @override
  void decodeReply(Object? okValue) => decodeNothing(okValue);
}
