import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/workflow_values.dart';
import 'package:agent_orchestration/bridge/codecs/workflow_views.dart';
import 'package:agent_orchestration/bridge/codecs/workspace_values.dart';
import 'package:agent_orchestration/bridge/commands/node_command.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

final class ListWorkflowsCommand implements NodeCommand<List<WorkflowView>> {
  const ListWorkflowsCommand({required this.workspaceId});

  final WorkspaceId workspaceId;

  @override
  String get name => 'list_workflows';

  @override
  JsonObject get arguments {
    return <String, Object?>{'workspace_id': workspaceId.value};
  }

  @override
  List<WorkflowView> decodeReply(Object? okValue) {
    return decodeList(okValue, WorkflowView.fromJson);
  }
}

final class CreateWorkflowCommand implements NodeCommand<WorkflowView> {
  CreateWorkflowCommand({
    required this.workspaceId,
    required this.workflowName,
    required this.availability,
    required List<WorkflowAgent> agents,
    required List<AgentConnection> connections,
  }) : agents = List<WorkflowAgent>.unmodifiable(agents),
       connections = List<AgentConnection>.unmodifiable(connections);

  final WorkspaceId workspaceId;
  final String workflowName;
  final WorkspaceScope availability;
  final List<WorkflowAgent> agents;
  final List<AgentConnection> connections;

  @override
  String get name => 'create_workflow';

  @override
  JsonObject get arguments {
    return <String, Object?>{
      'workspace_id': workspaceId.value,
      'name': workflowName,
      'availability': availability.toJson(),
      'agents': encodeList(agents),
      'connections': encodeList(connections),
    };
  }

  @override
  WorkflowView decodeReply(Object? okValue) {
    return WorkflowView.fromJson(okValue);
  }
}

final class SaveWorkflowCommand implements NodeCommand<WorkflowView> {
  const SaveWorkflowCommand({
    required this.workspaceId,
    required this.workflow,
  });

  final WorkspaceId workspaceId;
  final Workflow workflow;

  @override
  String get name => 'save_workflow';

  @override
  JsonObject get arguments {
    return <String, Object?>{
      'workspace_id': workspaceId.value,
      'workflow': workflow.toJson(),
    };
  }

  @override
  WorkflowView decodeReply(Object? okValue) {
    return WorkflowView.fromJson(okValue);
  }
}

final class SignWorkflowCommand implements NodeCommand<WorkflowView> {
  const SignWorkflowCommand({required this.workflowId});

  final WorkflowId workflowId;

  @override
  String get name => 'sign_workflow';

  @override
  JsonObject get arguments {
    return <String, Object?>{'workflow_id': workflowId.value};
  }

  @override
  WorkflowView decodeReply(Object? okValue) {
    return WorkflowView.fromJson(okValue);
  }
}

final class DiscardWorkflowChangeCommand implements NodeCommand<WorkflowView> {
  const DiscardWorkflowChangeCommand({required this.workflowId});

  final WorkflowId workflowId;

  @override
  String get name => 'discard_workflow_change';

  @override
  JsonObject get arguments {
    return <String, Object?>{'workflow_id': workflowId.value};
  }

  @override
  WorkflowView decodeReply(Object? okValue) {
    return WorkflowView.fromJson(okValue);
  }
}
