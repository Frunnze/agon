import 'dart:math';

import 'package:agent_orchestration/bridge/codecs/workflow_values.dart';
import 'package:agent_orchestration/bridge/commands/node_command.dart';
import 'package:agent_orchestration/bridge/commands/drafting_commands.dart';
import 'package:agent_orchestration/bridge/commands/workflow_commands.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

import '../../support/random_inputs.dart';
import 'command_shape.dart';
import 'node_json_primitives.dart';
import 'random_typed_values.dart';
import 'random_work_json.dart';

const List<CommandShape> workflowCommandShapes = <CommandShape>[
  CommandShape(
    commandName: 'list_workflows',
    argumentFields: <String>{'workspace_id'},
    buildCommand: _buildListWorkflows,
    buildReplyJson: _randomWorkflowViewsJson,
    encodeReply: encodeListReply,
  ),
  CommandShape(
    commandName: 'create_workflow',
    argumentFields: <String>{
      'workspace_id',
      'name',
      'availability',
      'agents',
      'connections',
    },
    buildCommand: _buildCreateWorkflow,
    buildReplyJson: randomWorkflowViewJson,
    encodeReply: encodeValueReply,
  ),
  CommandShape(
    commandName: 'save_workflow',
    argumentFields: <String>{'workspace_id', 'workflow'},
    buildCommand: _buildSaveWorkflow,
    buildReplyJson: randomWorkflowViewJson,
    encodeReply: encodeValueReply,
  ),
  CommandShape(
    commandName: 'sign_workflow',
    argumentFields: <String>{'workflow_id'},
    buildCommand: _buildSignWorkflow,
    buildReplyJson: randomWorkflowViewJson,
    encodeReply: encodeValueReply,
  ),
  CommandShape(
    commandName: 'discard_workflow_change',
    argumentFields: <String>{'workflow_id'},
    buildCommand: _buildDiscardWorkflowChange,
    buildReplyJson: randomWorkflowViewJson,
    encodeReply: encodeValueReply,
  ),
  CommandShape(
    commandName: 'draft_workflow',
    argumentFields: <String>{'workspace_id', 'description'},
    buildCommand: _buildDraftWorkflow,
    buildReplyJson: randomWorkflowAgentTaskJson,
    encodeReply: encodeValueReply,
  ),
  CommandShape(
    commandName: 'change_workflow',
    argumentFields: <String>{
      'workspace_id',
      'workflow_id',
      'request',
      'agent',
    },
    buildCommand: _buildChangeWorkflow,
    buildReplyJson: randomWorkflowAgentTaskJson,
    encodeReply: encodeValueReply,
  ),
  CommandShape(
    commandName: 'fill_agent_settings',
    argumentFields: <String>{'workspace_id', 'workflow_id', 'agent_id'},
    buildCommand: _buildFillAgentSettings,
    buildReplyJson: randomWorkflowAgentTaskJson,
    encodeReply: encodeValueReply,
  ),
  CommandShape(
    commandName: 'workflow_draft_status',
    argumentFields: <String>{'workspace_id', 'task_id', 'workflow_id'},
    buildCommand: _buildWorkflowDraftStatus,
    buildReplyJson: randomDraftStatusJson,
    encodeReply: encodeValueReply,
  ),
];

NodeCommand<Object?> _buildListWorkflows(Random random) {
  return ListWorkflowsCommand(workspaceId: randomWorkspaceId(random));
}

NodeCommand<Object?> _buildCreateWorkflow(Random random) {
  final Workflow workflow = Workflow.fromJson(randomWorkflowJson(random));
  return CreateWorkflowCommand(
    workspaceId: randomWorkspaceId(random),
    workflowName: workflow.name,
    availability: workflow.availability,
    agents: workflow.agents,
    connections: workflow.connections,
  );
}

NodeCommand<Object?> _buildSaveWorkflow(Random random) {
  return SaveWorkflowCommand(
    workspaceId: randomWorkspaceId(random),
    workflow: Workflow.fromJson(randomWorkflowJson(random)),
  );
}

NodeCommand<Object?> _buildSignWorkflow(Random random) {
  return SignWorkflowCommand(workflowId: randomWorkflowId(random));
}

NodeCommand<Object?> _buildDiscardWorkflowChange(Random random) {
  return DiscardWorkflowChangeCommand(workflowId: randomWorkflowId(random));
}

NodeCommand<Object?> _buildDraftWorkflow(Random random) {
  return DraftWorkflowCommand(
    workspaceId: randomWorkspaceId(random),
    description: randomText(random),
  );
}

NodeCommand<Object?> _buildChangeWorkflow(Random random) {
  return ChangeWorkflowCommand(
    workspaceId: randomWorkspaceId(random),
    workflowId: randomWorkflowId(random),
    request: randomText(random),
    agent: pickOne(random, AgentKind.values),
  );
}

NodeCommand<Object?> _buildFillAgentSettings(Random random) {
  return FillAgentSettingsCommand(
    workspaceId: randomWorkspaceId(random),
    workflowId: randomWorkflowId(random),
    agentId: WorkflowAgentId(randomUuidText(random)),
  );
}

NodeCommand<Object?> _buildWorkflowDraftStatus(Random random) {
  return WorkflowDraftStatusCommand(
    workspaceId: randomWorkspaceId(random),
    taskId: randomTaskId(random),
    workflowId: randomWorkflowId(random),
  );
}

List<Object?> _randomWorkflowViewsJson(Random random) {
  return randomListOf(random, randomWorkflowViewJson);
}
