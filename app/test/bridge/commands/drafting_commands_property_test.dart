import 'dart:math';

import 'package:agent_orchestration/bridge/codecs/workflow_values.dart';
import 'package:agent_orchestration/bridge/commands/drafting_commands.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

import '../../support/random_inputs.dart';
import '../support/hostile_texts.dart';
import 'support/drafting_and_file_command_properties.dart';

const int _firstMemberSeed = 9810000;
const int _firstReplySeed = 9811000;

const List<ModelledCommandRow> _draftingCommandRows = <ModelledCommandRow>[
  ModelledCommandRow(
    typeName: 'draft_workflow_command',
    commandName: 'draft_workflow',
    build: _buildDraftWorkflow,
  ),
  ModelledCommandRow(
    typeName: 'change_workflow_command',
    commandName: 'change_workflow',
    build: _buildChangeWorkflow,
  ),
  ModelledCommandRow(
    typeName: 'fill_agent_settings_command',
    commandName: 'fill_agent_settings',
    build: _buildFillAgentSettings,
  ),
  ModelledCommandRow(
    typeName: 'workflow_draft_status_command',
    commandName: 'workflow_draft_status',
    build: _buildWorkflowDraftStatus,
  ),
];

const Map<AgentKind, String> _rustAgentKindNames = <AgentKind, String>{
  AgentKind.claudeCode: 'claude_code',
  AgentKind.codex: 'codex',
  AgentKind.geminiCli: 'gemini_cli',
};

void main() {
  testModelledCommandRows(_draftingCommandRows, _firstMemberSeed);
  testCommandReplyRows(_draftingCommandRows, _firstReplySeed);
}

ModelledCommand _buildDraftWorkflow(Random random) {
  final WorkspaceId workspaceId = WorkspaceId(randomHostileText(random));
  final String description = randomHostileText(random);
  final DraftWorkflowCommand command = DraftWorkflowCommand(
    workspaceId: workspaceId,
    description: description,
  );
  return (
    command: command,
    givenFields: <Object?>[workspaceId, description],
    keptFields: <Object?>[command.workspaceId, command.description],
    expectedArguments: <String, Object?>{
      'workspace_id': workspaceId.value,
      'description': description,
    },
  );
}

ModelledCommand _buildChangeWorkflow(Random random) {
  final WorkspaceId workspaceId = WorkspaceId(randomHostileText(random));
  final WorkflowId workflowId = WorkflowId(randomHostileText(random));
  final String request = randomHostileText(random);
  final AgentKind agent = pickOne(random, AgentKind.values);
  final ChangeWorkflowCommand command = ChangeWorkflowCommand(
    workspaceId: workspaceId,
    workflowId: workflowId,
    request: request,
    agent: agent,
  );
  return (
    command: command,
    givenFields: <Object?>[workspaceId, workflowId, request, agent],
    keptFields: <Object?>[
      command.workspaceId,
      command.workflowId,
      command.request,
      command.agent,
    ],
    expectedArguments: <String, Object?>{
      'workspace_id': workspaceId.value,
      'workflow_id': workflowId.value,
      'request': request,
      'agent': _rustAgentKindNames[agent],
    },
  );
}

ModelledCommand _buildFillAgentSettings(Random random) {
  final WorkspaceId workspaceId = WorkspaceId(randomHostileText(random));
  final WorkflowId workflowId = WorkflowId(randomHostileText(random));
  final WorkflowAgentId agentId = WorkflowAgentId(randomHostileText(random));
  final FillAgentSettingsCommand command = FillAgentSettingsCommand(
    workspaceId: workspaceId,
    workflowId: workflowId,
    agentId: agentId,
  );
  return (
    command: command,
    givenFields: <Object?>[workspaceId, workflowId, agentId],
    keptFields: <Object?>[
      command.workspaceId,
      command.workflowId,
      command.agentId,
    ],
    expectedArguments: <String, Object?>{
      'workspace_id': workspaceId.value,
      'workflow_id': workflowId.value,
      'agent_id': agentId.value,
    },
  );
}

ModelledCommand _buildWorkflowDraftStatus(Random random) {
  final WorkspaceId workspaceId = WorkspaceId(randomHostileText(random));
  final TaskId taskId = TaskId(randomHostileText(random));
  final WorkflowId workflowId = WorkflowId(randomHostileText(random));
  final WorkflowDraftStatusCommand command = WorkflowDraftStatusCommand(
    workspaceId: workspaceId,
    taskId: taskId,
    workflowId: workflowId,
  );
  return (
    command: command,
    givenFields: <Object?>[workspaceId, taskId, workflowId],
    keptFields: <Object?>[
      command.workspaceId,
      command.taskId,
      command.workflowId,
    ],
    expectedArguments: <String, Object?>{
      'workspace_id': workspaceId.value,
      'task_id': taskId.value,
      'workflow_id': workflowId.value,
    },
  );
}
