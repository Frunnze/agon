import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import '../../support/random_workflows.dart';

WorkflowAgentId _randomMissingId(Random random, Workflow workflow) {
  final Set<WorkflowAgentId> takenIds = <WorkflowAgentId>{
    for (final WorkflowAgent agent in workflow.agents) agent.id,
  };
  WorkflowAgentId candidate = WorkflowAgentId(randomHostileText(random));
  while (takenIds.contains(candidate)) {
    candidate = WorkflowAgentId('${candidate.value}-missing');
  }
  return candidate;
}

WorkflowAgentId _randomAskedId(Random random, Workflow workflow) {
  if (workflow.agents.isNotEmpty && random.nextBool()) {
    return pickOne(random, workflow.agents).id;
  }
  return _randomMissingId(random, workflow);
}

void main() {
  test('test_find_agent_property_returns_each_listed_agent', () {
    final Random random = seededRandom(703931);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomAcyclicWorkflow(random);

      for (final WorkflowAgent agent in workflow.agents) {
        expect(workflow.findAgent(agent.id), same(agent));
      }
    }
  });

  test('test_find_agent_property_missing_id_is_a_state_error', () {
    final Random random = seededRandom(703941);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomAcyclicWorkflow(random);
      final WorkflowAgentId missingId = _randomMissingId(random, workflow);

      expect(() => workflow.findAgent(missingId), throwsStateError);
    }
  });

  test('test_find_agent_property_agrees_with_find_agent_if_present', () {
    final Random random = seededRandom(703951);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomAcyclicWorkflow(random);
      final WorkflowAgentId askedId = _randomAskedId(random, workflow);

      final WorkflowAgent? present = workflow.findAgentIfPresent(askedId);

      if (present == null) {
        expect(() => workflow.findAgent(askedId), throwsStateError);
      } else {
        expect(workflow.findAgent(askedId), same(present));
      }
    }
  });

  test('test_find_agent_if_present_property_null_only_when_absent', () {
    final Random random = seededRandom(703961);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomAcyclicWorkflow(random);
      final WorkflowAgentId askedId = _randomAskedId(random, workflow);
      bool isListed = false;
      for (final WorkflowAgent agent in workflow.agents) {
        isListed = isListed || agent.id == askedId;
      }

      final WorkflowAgent? found = workflow.findAgentIfPresent(askedId);

      expect(found != null, isListed);
      expect(found?.id ?? askedId, askedId);
    }
  });

  test('test_find_agent_if_present_property_returns_a_listed_agent', () {
    final Random random = seededRandom(703971);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomAcyclicWorkflow(random);
      final WorkflowAgentId askedId = _randomAskedId(random, workflow);

      final WorkflowAgent? found = workflow.findAgentIfPresent(askedId);

      if (found != null) {
        expect(workflow.agents, anyElement(same(found)));
      }
    }
  });

  test('test_find_agent_if_present_property_ignores_the_connections', () {
    final Random random = seededRandom(703981);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomAcyclicWorkflow(random);
      final WorkflowAgentId askedId = _randomAskedId(random, workflow);
      final Workflow unconnected = workflow.withGraph(
        agents: workflow.agents,
        connections: const <AgentConnection>[],
      );

      final WorkflowAgent? found = workflow.findAgentIfPresent(askedId);

      expect(unconnected.findAgentIfPresent(askedId), same(found));
    }
  });
}
