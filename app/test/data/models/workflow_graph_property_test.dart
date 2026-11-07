import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/models/workflow.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../bridge/support/list_copy_properties.dart';
import '../../bridge/support/node_json_primitives.dart';
import '../../bridge/support/random_moments.dart';
import '../../bridge/support/random_typed_values.dart';
import '../../support/random_inputs.dart';
import '../../support/random_workflows.dart';
import '../../support/sample_scopes.dart';
import 'support/domain_model_properties.dart';

const int _agentIndexSpan = 9;

WorkflowSignature? _randomOptionalSignature(Random random) {
  if (random.nextBool()) {
    return null;
  }
  return WorkflowSignature(
    signedBy: randomDeviceId(random),
    signature: randomBytes(random),
    signedDocument: randomHostileText(random),
    signedAt: randomPreciseMoment(random),
  );
}

ModelFieldValues _randomWorkflowFields(Random random) {
  final Workflow graph = randomAcyclicWorkflow(random);

  return <Object?>[
    randomWorkflowId(random),
    randomHostileText(random),
    randomWorkspaceScope(random),
    graph.agents,
    graph.connections,
    _randomOptionalSignature(random),
  ];
}

Workflow _buildWorkflow(ModelFieldValues fieldValues) {
  return Workflow(
    id: fieldValues[0]! as WorkflowId,
    name: fieldValues[1]! as String,
    availability: fieldValues[2]! as WorkspaceScope,
    agents: fieldValues[3]! as List<WorkflowAgent>,
    connections: fieldValues[4]! as List<AgentConnection>,
    signature: fieldValues[5] as WorkflowSignature?,
  );
}

ModelFieldValues _readWorkflowFields(Workflow workflow) {
  return <Object?>[
    workflow.id,
    workflow.name,
    workflow.availability,
    workflow.agents,
    workflow.connections,
    workflow.signature,
  ];
}

ModelFieldValues _readIdentityFields(Workflow workflow) {
  return <Object?>[
    workflow.id,
    workflow.name,
    workflow.availability,
    workflow.signature,
  ];
}

Workflow _randomWorkflow(Random random) {
  return _buildWorkflow(_randomWorkflowFields(random));
}

Workflow _buildWorkflowWithAgents(Random random, List<WorkflowAgent> agents) {
  return _randomWorkflow(random)
      .withGraph(agents: agents, connections: const <AgentConnection>[]);
}

Workflow _buildWorkflowWithConnections(
  Random random,
  List<AgentConnection> connections,
) {
  return _randomWorkflow(random)
      .withGraph(agents: const <WorkflowAgent>[], connections: connections);
}

AgentConnection _randomConnection(Random random) {
  return AgentConnection(
    from: WorkflowAgentId(randomHostileText(random)),
    to: WorkflowAgentId(randomHostileText(random)),
    condition: null,
    roundLimit: null,
  );
}

void main() {
  testModelConstructorProperties(
    const ModelConstructor<Workflow>(
      testNamePrefix: 'test_workflow_constructor_property',
      seed: 703901,
      randomFieldValues: _randomWorkflowFields,
      construct: _buildWorkflow,
      readFieldValues: _readWorkflowFields,
    ),
  );

  testListCopyProperties(
    ListCopy<Workflow, WorkflowAgent>(
      testNamePrefix: 'test_workflow_constructor_property_agents',
      seed: 703911,
      buildElement: (Random random) =>
          randomAgent(random, random.nextInt(_agentIndexSpan)),
      construct: _buildWorkflowWithAgents,
      readList: (Workflow workflow) => workflow.agents,
    ),
  );

  testListCopyProperties(
    ListCopy<Workflow, AgentConnection>(
      testNamePrefix: 'test_workflow_constructor_property_connections',
      seed: 703921,
      buildElement: _randomConnection,
      construct: _buildWorkflowWithConnections,
      readList: (Workflow workflow) => workflow.connections,
    ),
  );

  testModelCopyProperties(
    ModelCopy<Workflow, String>(
      testNamePrefix: 'test_workflow_with_name_property',
      seed: 703991,
      randomModel: _randomWorkflow,
      randomChange: randomHostileText,
      applyChange: (Workflow workflow, String name) => workflow.withName(name),
      readChangedField: (Workflow workflow) => workflow.name,
      readOtherFields: (Workflow workflow) => <Object?>[
        workflow.id,
        workflow.availability,
        workflow.agents,
        workflow.connections,
        workflow.signature,
      ],
    ),
  );

  test('test_with_graph_property_replaces_agents_and_connections', () {
    final Random random = seededRandom(704001);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = _randomWorkflow(random);
      final Workflow graph = randomAcyclicWorkflow(random);

      final Workflow changed = workflow.withGraph(
        agents: graph.agents,
        connections: graph.connections,
      );

      expect(changed.agents, orderedEquals(graph.agents));
      expect(changed.connections, orderedEquals(graph.connections));
      expect(_readIdentityFields(changed), _readIdentityFields(workflow));
    }
  });

  test('test_with_graph_property_freezes_the_given_lists', () {
    final Random random = seededRandom(704011);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow graph = randomAcyclicWorkflow(random);
      final List<WorkflowAgent> agents = List<WorkflowAgent>.of(graph.agents);
      final List<AgentConnection> connections = List<AgentConnection>.of(
        graph.connections,
      );

      final Workflow changed = _randomWorkflow(random)
          .withGraph(agents: agents, connections: connections);
      agents.clear();
      connections.add(_randomConnection(random));

      expect(changed.agents, orderedEquals(graph.agents));
      expect(changed.connections, orderedEquals(graph.connections));
      expect(changed.agents.clear, throwsUnsupportedError);
      expect(changed.connections.clear, throwsUnsupportedError);
    }
  });

  test('test_with_graph_property_last_graph_wins', () {
    final Random random = seededRandom(704021);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = _randomWorkflow(random);
      final ModelFieldValues fieldsBefore = _readWorkflowFields(workflow);
      final Workflow firstGraph = randomAcyclicWorkflow(random);
      final Workflow lastGraph = randomAcyclicWorkflow(random);

      final Workflow changed = workflow
          .withGraph(
            agents: firstGraph.agents,
            connections: firstGraph.connections,
          )
          .withGraph(
            agents: lastGraph.agents,
            connections: lastGraph.connections,
          );

      expect(changed.agents, orderedEquals(lastGraph.agents));
      expect(changed.connections, orderedEquals(lastGraph.connections));
      expect(_readIdentityFields(changed), _readIdentityFields(workflow));
      expect(_readWorkflowFields(workflow), fieldsBefore);
    }
  });
}
