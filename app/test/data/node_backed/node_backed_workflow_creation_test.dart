import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/rules/workflow_edits.dart';

import '../../support/random_inputs.dart';
import 'support/node_backed_harness.dart'
    show buildSingleWorkspaceRepository, harnessWorkspaceId;
import 'support/simulated_node_replies.dart';
import 'support/simulated_workflow_node.dart';
import 'support/simulated_workflow_views.dart';

const WorkflowId _unsavedWorkflowId = WorkflowId('unsaved');

final class _CreatingNode {
  final List<SimulatedCommand> createCommands = <SimulatedCommand>[];

  late final NodeCommandChannel channel = buildSimulatedChannel(_answer);

  String _answer(String inputJson) {
    return answerSimulatedCommand(
      inputJson: inputJson,
      handlers: <String, SimulatedHandler>{
        'list_workflows': (SimulatedCommand command) => <Object?>[],
        'create_workflow': _createWorkflow,
      },
      failingCommands: const <String>{},
    );
  }

  Object? _createWorkflow(SimulatedCommand command) {
    createCommands.add(command);
    final Map<String, Object?> workflow = <String, Object?>{
      'id': 'node-workflow-${createCommands.length}',
      'name': command['name'],
      'availability': command['availability'],
      'agents': command['agents'],
      'connections': command['connections'],
      'signature': null,
    };
    return buildSimulatedWorkflowView(workflow, unsignedState);
  }
}

Workflow _buildUnsavedWorkflow(Random random) {
  Workflow unsaved = Workflow(
    id: _unsavedWorkflowId,
    name: 'flow-${random.nextInt(1000)}',
    availability: OnlyWorkspaces(const <WorkspaceId>[harnessWorkspaceId]),
    agents: const <WorkflowAgent>[],
    connections: const <AgentConnection>[],
    signature: null,
  );
  final int agentCount = 1 + random.nextInt(4);
  for (int i = 0; i < agentCount; i += 1) {
    unsaved = addAgent(unsaved, buildBlankAgent(unsaved));
  }
  return unsaved;
}

List<Object?> _readAgentNames(SimulatedCommand command) {
  final List<Object?> agentNames = <Object?>[];
  for (final Object? agent in command['agents'] as List<Object?>) {
    agentNames.add((agent as Map<String, Object?>)['name']);
  }
  return agentNames;
}

void main() {
  test(
    'test_create_workflow_property_sends_graph_and_keeps_node_id',
    () async {
      final Random random = seededRandom(9921);
      final _CreatingNode creatingNode = _CreatingNode();
      final NodeBackedWorkflowRepository repository =
          NodeBackedWorkflowRepository(
            channel: creatingNode.channel,
            workspaceRepository: buildSingleWorkspaceRepository(),
            draftPollInterval: Duration.zero,
          );

      for (int i = 0; i < propertyIterations; i += 1) {
        final Workflow unsaved = _buildUnsavedWorkflow(random);

        final Workflow created = await repository.createWorkflow(unsaved);

        final SimulatedCommand sent = creatingNode.createCommands.last;
        expect(sent['workspace_id'], harnessWorkspaceId.value);
        expect(sent['name'], unsaved.name);
        expect(_readAgentNames(sent), <Object?>[
          for (final WorkflowAgent agent in unsaved.agents) agent.name,
        ]);
        expect(created.id.value, 'node-workflow-${i + 1}');
        expect(repository.findWorkflow(created.id).name, unsaved.name);
      }
      expect(repository.listWorkflows().length, propertyIterations);
      repository.dispose();
    },
  );
}
