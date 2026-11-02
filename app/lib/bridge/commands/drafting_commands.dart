import 'package:agent_orchestration/bridge/codecs/drafting_task_views.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/workflow_views.dart';
import 'package:agent_orchestration/bridge/commands/node_command.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

final class DraftWorkflowCommand
    implements NodeCommand<WorkflowAgentTaskView> {
  const DraftWorkflowCommand({
    required this.workspaceId,
    required this.description,
  });

  final WorkspaceId workspaceId;
  final String description;

  @override
  String get name => 'draft_workflow';

  @override
  JsonObject get arguments {
    return <String, Object?>{
      'workspace_id': workspaceId.value,
      'description': description,
    };
  }

  @override
  WorkflowAgentTaskView decodeReply(Object? okValue) {
    return WorkflowAgentTaskView.fromJson(okValue);
  }
}

final class ChangeWorkflowCommand
    implements NodeCommand<WorkflowAgentTaskView> {
  const ChangeWorkflowCommand({
    required this.workspaceId,
    required this.workflowId,
    required this.request,
  });

  final WorkspaceId workspaceId;
  final WorkflowId workflowId;
  final String request;

  @override
  String get name => 'change_workflow';

  @override
  JsonObject get arguments {
    return <String, Object?>{
      'workspace_id': workspaceId.value,
      'workflow_id': workflowId.value,
      'request': request,
    };
  }

  @override
  WorkflowAgentTaskView decodeReply(Object? okValue) {
    return WorkflowAgentTaskView.fromJson(okValue);
  }
}

final class FillAgentSettingsCommand
    implements NodeCommand<WorkflowAgentTaskView> {
  const FillAgentSettingsCommand({
    required this.workspaceId,
    required this.workflowId,
    required this.agentId,
  });

  final WorkspaceId workspaceId;
  final WorkflowId workflowId;
  final WorkflowAgentId agentId;

  @override
  String get name => 'fill_agent_settings';

  @override
  JsonObject get arguments {
    return <String, Object?>{
      'workspace_id': workspaceId.value,
      'workflow_id': workflowId.value,
      'agent_id': agentId.value,
    };
  }

  @override
  WorkflowAgentTaskView decodeReply(Object? okValue) {
    return WorkflowAgentTaskView.fromJson(okValue);
  }
}

final class WorkflowDraftStatusCommand implements NodeCommand<DraftStatus> {
  const WorkflowDraftStatusCommand({
    required this.workspaceId,
    required this.taskId,
    required this.workflowId,
  });

  final WorkspaceId workspaceId;
  final TaskId taskId;
  final WorkflowId workflowId;

  @override
  String get name => 'workflow_draft_status';

  @override
  JsonObject get arguments {
    return <String, Object?>{
      'workspace_id': workspaceId.value,
      'task_id': taskId.value,
      'workflow_id': workflowId.value,
    };
  }

  @override
  DraftStatus decodeReply(Object? okValue) => DraftStatus.fromJson(okValue);
}
