import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/workflow_graph.dart';

import '../../support/random_inputs.dart';
import '../../support/random_workflows.dart';
import 'support/workflow_run_planning.dart';

const List<String> _crowdedNames = <String>['plan', 'build', 'plan'];
const List<double> _crowdedCoordinates = <double>[0, 1, -0.0];
const int _largestCrowdSize = 7;

Workflow _randomCrowdedWorkflow(Random random) {
  final Workflow base = randomAcyclicWorkflow(random);
  final int crowdSize = 1 + random.nextInt(_largestCrowdSize);
  final List<WorkflowAgent> agents = <WorkflowAgent>[];
  for (int index = 0; index < crowdSize; index += 1) {
    final WorkflowAgent agent = randomAgent(random, index);
    agents.add(
      agent.copyWith(
        name: pickOne(random, _crowdedNames),
        position: CanvasPosition(
          horizontal: pickOne(random, _crowdedCoordinates),
          vertical: pickOne(random, _crowdedCoordinates),
        ),
      ),
    );
  }
  return base.withGraph(
    agents: agents,
    connections: const <AgentConnection>[],
  );
}

List<WorkflowAgentId> _listOrderedIds(Workflow workflow) {
  return <WorkflowAgentId>[
    for (final WorkflowAgent agent in orderAgents(workflow)) agent.id,
  ];
}

void main() {
  test('test_order_agents_property_ties_ignore_storage_order', () {
    final Random random = seededRandom(47201);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = _randomCrowdedWorkflow(random);
      final Workflow reordered = shuffleStorageOrder(random, workflow);

      expect(_listOrderedIds(reordered), _listOrderedIds(workflow));
    }
  });

  test('test_order_agents_property_full_ties_follow_the_identifier', () {
    final Random random = seededRandom(47202);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow crowded = _randomCrowdedWorkflow(random);
      final List<WorkflowAgent> twins = <WorkflowAgent>[
        for (final WorkflowAgent agent in crowded.agents)
          agent.copyWith(
            name: 'twin',
            position: const CanvasPosition(horizontal: 3, vertical: 3),
          ),
      ];
      final Workflow workflow = shuffleStorageOrder(
        random,
        crowded.withGraph(agents: twins, connections: crowded.connections),
      );

      final List<String> orderedIds = <String>[
        for (final WorkflowAgentId agentId in _listOrderedIds(workflow))
          agentId.value,
      ];
      final List<String> sortedIds = List<String>.of(orderedIds);
      sortedIds.sort();
      expect(orderedIds, sortedIds);
    }
  });

  test('test_order_agents_property_lists_every_agent_once', () {
    final Random random = seededRandom(47203);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = random.nextBool()
          ? _randomCrowdedWorkflow(random)
          : randomAcyclicWorkflow(random);

      final List<WorkflowAgentId> orderedIds = _listOrderedIds(workflow);

      expect(orderedIds.length, workflow.agents.length);
      expect(orderedIds.toSet(), <WorkflowAgentId>{
        for (final WorkflowAgent agent in workflow.agents) agent.id,
      });
    }
  });
}
