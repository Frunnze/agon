import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/workflow_values.dart';
import 'package:agent_orchestration/bridge/codecs/workspace_values.dart';
import 'package:agent_orchestration/bridge/commands/workflow_commands.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

import '../../support/random_inputs.dart';
import '../codecs/support/codec_rows.dart';
import '../support/hostile_texts.dart';
import '../support/node_json_primitives.dart';
import '../support/random_catalog_json.dart';
import '../support/random_work_json.dart';
import 'support/drafting_and_file_command_properties.dart';
import 'support/library_and_live_reply_properties.dart';

const int _firstMemberSeed = 6262000;
const int _firstObjectReplySeed = 6263000;
const int _firstListReplySeed = 6264000;
const int _copySeed = 6265000;

const List<String> _workflowViewReplyFields = <String>[
  'workflow',
  'agent_names',
  'document',
  'signature_state',
  'changes',
];

const List<ModelledCommandRow> _workflowCommandRows = <ModelledCommandRow>[
  ModelledCommandRow(
    typeName: 'list_workflows_command',
    commandName: 'list_workflows',
    build: _buildListWorkflows,
  ),
  ModelledCommandRow(
    typeName: 'create_workflow_command',
    commandName: 'create_workflow',
    build: _buildCreateWorkflow,
  ),
  ModelledCommandRow(
    typeName: 'save_workflow_command',
    commandName: 'save_workflow',
    build: _buildSaveWorkflow,
  ),
  ModelledCommandRow(
    typeName: 'sign_workflow_command',
    commandName: 'sign_workflow',
    build: _buildSignWorkflow,
  ),
  ModelledCommandRow(
    typeName: 'discard_workflow_change_command',
    commandName: 'discard_workflow_change',
    build: _buildDiscardWorkflowChange,
  ),
];

const List<ReplyRow> _objectReplyRows = <ReplyRow>[
  ReplyRow(
    typeName: 'create_workflow_command',
    commandName: 'create_workflow',
    buildObjectJson: randomWorkflowViewJson,
    requiredFields: _workflowViewReplyFields,
  ),
  ReplyRow(
    typeName: 'save_workflow_command',
    commandName: 'save_workflow',
    buildObjectJson: randomWorkflowViewJson,
    requiredFields: _workflowViewReplyFields,
  ),
  ReplyRow(
    typeName: 'sign_workflow_command',
    commandName: 'sign_workflow',
    buildObjectJson: randomWorkflowViewJson,
    requiredFields: _workflowViewReplyFields,
  ),
  ReplyRow(
    typeName: 'discard_workflow_change_command',
    commandName: 'discard_workflow_change',
    buildObjectJson: randomWorkflowViewJson,
    requiredFields: _workflowViewReplyFields,
  ),
];

const List<ReplyRow> _listReplyRows = <ReplyRow>[
  ReplyRow(
    typeName: 'list_workflows_command',
    commandName: 'list_workflows',
    buildObjectJson: randomWorkflowViewJson,
    requiredFields: _workflowViewReplyFields,
  ),
];

typedef _WorkflowParts = ({
  JsonObject availabilityJson,
  List<Object?> agentJsons,
  List<Object?> connectionJsons,
  List<WorkflowAgent> agents,
  List<AgentConnection> connections,
});

void main() {
  testModelledCommandRows(_workflowCommandRows, _firstMemberSeed);
  testObjectReplyRows(_objectReplyRows, _firstObjectReplySeed);
  testListReplyRows(_listReplyRows, _firstListReplySeed);

  test('test_create_workflow_command_constructor_property_copies_lists', () {
    final Random random = seededRandom(_copySeed);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _WorkflowParts parts = _randomWorkflowParts(random);
      final List<WorkflowAgent> callerAgents = parts.agents.toList();
      final List<AgentConnection> callerConnections = parts.connections
          .toList();
      final CreateWorkflowCommand command = CreateWorkflowCommand(
        workspaceId: WorkspaceId(randomHostileText(random)),
        workflowName: randomHostileText(random),
        availability: WorkspaceScope.fromJson(parts.availabilityJson),
        agents: callerAgents,
        connections: callerConnections,
      );

      callerAgents.clear();
      callerConnections.clear();

      expect(command.arguments['agents'], equals(parts.agentJsons));
      expect(command.arguments['connections'], equals(parts.connectionJsons));
      expect(command.agents.clear, throwsUnsupportedError);
      expect(command.connections.clear, throwsUnsupportedError);
    }
  });
}

_WorkflowParts _randomWorkflowParts(Random random) {
  final List<Object?> agentJsons = randomListOf(
    random,
    randomWorkflowAgentJson,
  );
  final List<Object?> connectionJsons = randomListOf(
    random,
    randomAgentConnectionJson,
  );
  return (
    availabilityJson: randomWorkspaceScopeJson(random),
    agentJsons: agentJsons,
    connectionJsons: connectionJsons,
    agents: decodeList(agentJsons, WorkflowAgent.fromJson),
    connections: decodeList(connectionJsons, AgentConnection.fromJson),
  );
}

ModelledCommand _buildListWorkflows(Random random) {
  final WorkspaceId workspaceId = WorkspaceId(randomHostileText(random));
  final ListWorkflowsCommand command = ListWorkflowsCommand(
    workspaceId: workspaceId,
  );
  return (
    command: command,
    givenFields: <Object?>[workspaceId],
    keptFields: <Object?>[command.workspaceId],
    expectedArguments: <String, Object?>{'workspace_id': workspaceId.value},
  );
}

ModelledCommand _buildCreateWorkflow(Random random) {
  final WorkspaceId workspaceId = WorkspaceId(randomHostileText(random));
  final String workflowName = randomHostileText(random);
  final _WorkflowParts parts = _randomWorkflowParts(random);
  final WorkspaceScope availability = WorkspaceScope.fromJson(
    parts.availabilityJson,
  );
  final CreateWorkflowCommand command = CreateWorkflowCommand(
    workspaceId: workspaceId,
    workflowName: workflowName,
    availability: availability,
    agents: parts.agents,
    connections: parts.connections,
  );
  return (
    command: command,
    givenFields: <Object?>[
      workspaceId,
      workflowName,
      availability,
      parts.agents,
      parts.connections,
    ],
    keptFields: <Object?>[
      command.workspaceId,
      command.workflowName,
      command.availability,
      command.agents,
      command.connections,
    ],
    expectedArguments: <String, Object?>{
      'workspace_id': workspaceId.value,
      'name': workflowName,
      'availability': rereadThroughWire(parts.availabilityJson),
      'agents': rereadThroughWire(parts.agentJsons),
      'connections': rereadThroughWire(parts.connectionJsons),
    },
  );
}

ModelledCommand _buildSaveWorkflow(Random random) {
  final WorkspaceId workspaceId = WorkspaceId(randomHostileText(random));
  final JsonObject workflowJson = randomWorkflowJson(random);
  final Workflow workflow = Workflow.fromJson(workflowJson);
  final SaveWorkflowCommand command = SaveWorkflowCommand(
    workspaceId: workspaceId,
    workflow: workflow,
  );
  return (
    command: command,
    givenFields: <Object?>[workspaceId, workflow],
    keptFields: <Object?>[command.workspaceId, command.workflow],
    expectedArguments: <String, Object?>{
      'workspace_id': workspaceId.value,
      'workflow': rereadThroughWire(workflowJson),
    },
  );
}

ModelledCommand _buildSignWorkflow(Random random) {
  final WorkflowId workflowId = WorkflowId(randomHostileText(random));
  final SignWorkflowCommand command = SignWorkflowCommand(
    workflowId: workflowId,
  );
  return (
    command: command,
    givenFields: <Object?>[workflowId],
    keptFields: <Object?>[command.workflowId],
    expectedArguments: <String, Object?>{'workflow_id': workflowId.value},
  );
}

ModelledCommand _buildDiscardWorkflowChange(Random random) {
  final WorkflowId workflowId = WorkflowId(randomHostileText(random));
  final DiscardWorkflowChangeCommand command = DiscardWorkflowChangeCommand(
    workflowId: workflowId,
  );
  return (
    command: command,
    givenFields: <Object?>[workflowId],
    keptFields: <Object?>[command.workflowId],
    expectedArguments: <String, Object?>{'workflow_id': workflowId.value},
  );
}
