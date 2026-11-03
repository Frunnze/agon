import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/workflow_edits.dart';

import '../../support/random_branching_workflows.dart';
import '../../support/random_inputs.dart';

void _expectLoopsPointBack(Workflow workflow) {
  for (final AgentConnection connection in workflow.connections) {
    if (connection.isLoop) {
      expect(
        hasForwardPath(workflow, from: connection.to, to: connection.from),
        isTrue,
      );
    }
  }
}

void main() {
  test('test_build_blank_person_step_property_a_person_with_a_free_name', () {
    final Random random = seededRandom(9601);

    for (int i = 0; i < propertyIterations; i += 1) {
      Workflow workflow = randomBranchingWorkflow(random);
      final int additions = 1 + random.nextInt(3);

      for (int step = 0; step < additions; step += 1) {
        final WorkflowAgent blank = buildBlankPersonStep(workflow);
        final bool isKnownName = workflow.agents.any(
          (WorkflowAgent agent) => agent.name == blank.name,
        );

        expect(isKnownName, isFalse);
        expect(blank.stepKind, StepKind.person);
        expect(blank.name, startsWith(blankPersonStepName));
        expect(blank.task, isEmpty);
        workflow = addAgent(workflow, blank);
      }
    }
  });

  test('test_build_blank_agent_property_is_an_agent_step', () {
    final Random random = seededRandom(9602);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkflowAgent blank = buildBlankAgent(
        randomBranchingWorkflow(random),
      );

      expect(blank.stepKind, StepKind.agent);
    }
  });

  test('test_replace_connection_property_changes_only_that_connection', () {
    final Random random = seededRandom(9603);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomBranchingWorkflow(random);
      if (workflow.connections.isEmpty) {
        continue;
      }
      final AgentConnection original = pickOne(random, workflow.connections);
      final AgentConnection replacement = original.withCondition(
        pickOne(random, sampleOutcomes),
      );

      final Workflow changed = replaceConnection(workflow, replacement);

      expect(changed.connections.length, workflow.connections.length);
      for (int index = 0; index < changed.connections.length; index += 1) {
        final AgentConnection before = workflow.connections[index];
        final AgentConnection after = changed.connections[index];
        final AgentConnection expected = before.joinsSameSteps(original)
            ? replacement
            : before;
        expect(after, expected);
      }
    }
  });

  test('test_remove_connection_property_keeps_every_loop_pointing_back', () {
    final Random random = seededRandom(9604);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomBranchingWorkflow(random);
      if (workflow.connections.isEmpty) {
        continue;
      }
      final AgentConnection removed = pickOne(random, workflow.connections);

      final Workflow changed = removeConnection(workflow, removed);

      expect(changed.connections, isNot(contains(removed)));
      for (final AgentConnection connection in changed.connections) {
        expect(workflow.connections, contains(connection));
      }
      for (final AgentConnection connection in workflow.connections) {
        if (connection != removed && !connection.isLoop) {
          expect(changed.connections, contains(connection));
        }
      }
      _expectLoopsPointBack(changed);
    }
  });

  test('test_remove_agent_property_keeps_every_loop_pointing_back', () {
    final Random random = seededRandom(9605);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomBranchingWorkflow(random);
      if (workflow.agents.isEmpty) {
        continue;
      }
      final WorkflowAgent removed = pickOne(random, workflow.agents);

      final Workflow changed = removeAgent(workflow, removed.id);

      for (final AgentConnection connection in changed.connections) {
        expect(connection.from, isNot(removed.id));
        expect(connection.to, isNot(removed.id));
      }
      _expectLoopsPointBack(changed);
    }
  });

  test('replacing or removing a connection the workflow lacks fails', () {
    final Random random = seededRandom(9606);
    final Workflow workflow = randomBranchingWorkflow(random);
    final WorkflowAgent first = buildBlankAgent(workflow);
    final AgentConnection missing = AgentConnection(
      from: first.id,
      to: first.id,
      condition: null,
      roundLimit: null,
    );

    expect(() => replaceConnection(workflow, missing), throwsStateError);
    expect(() => removeConnection(workflow, missing), throwsStateError);
  });
}
