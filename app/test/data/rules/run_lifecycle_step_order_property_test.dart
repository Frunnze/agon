import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/workflow_graph.dart';

import '../../support/random_inputs.dart';
import '../../support/random_workflows.dart';
import 'support/workflow_run_planning.dart';

Workflow _randomRunnableWorkflow(Random random) {
  final Workflow workflow = randomAcyclicWorkflow(random);
  if (workflow.agents.isNotEmpty) {
    return workflow;
  }
  return workflow.withGraph(
    agents: <WorkflowAgent>[randomAgent(random, 0)],
    connections: const <AgentConnection>[],
  );
}

int _findStepIndex(Run run, WorkflowAgentId agentId) {
  return run.steps.indexWhere((RunStep step) => step.agentId == agentId);
}

void main() {
  test('test_plan_steps_property_steps_follow_the_graph_order', () {
    final Random random = seededRandom(47101);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = _randomRunnableWorkflow(random);

      final Run run = planWorkflowRun(random, workflow);

      final List<WorkflowAgent> ordered = orderAgents(workflow);
      expect(listRunStepNames(run), <String>[
        for (final WorkflowAgent agent in ordered) agent.name,
      ]);
      expect(
        <WorkflowAgentId?>[for (final RunStep step in run.steps) step.agentId],
        <WorkflowAgentId>[for (final WorkflowAgent agent in ordered) agent.id],
      );
    }
  });

  test('test_plan_steps_property_storage_order_does_not_change_the_plan', () {
    final Random random = seededRandom(47102);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = _randomRunnableWorkflow(random);
      final Workflow reordered = shuffleStorageOrder(random, workflow);

      final Run run = planWorkflowRun(random, workflow);
      final Run reorderedRun = planWorkflowRun(random, reordered);

      expect(listRunStepNames(reorderedRun), listRunStepNames(run));
    }
  });

  test('test_plan_steps_property_every_step_comes_after_its_inputs', () {
    final Random random = seededRandom(47103);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = shuffleStorageOrder(
        random,
        _randomRunnableWorkflow(random),
      );

      final Run run = planWorkflowRun(random, workflow);

      for (final AgentConnection connection in workflow.connections) {
        expect(
          _findStepIndex(run, connection.from),
          lessThan(_findStepIndex(run, connection.to)),
        );
      }
    }
  });

  test('test_plan_steps_property_the_running_step_waits_for_no_input', () {
    final Random random = seededRandom(47104);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = shuffleStorageOrder(
        random,
        _randomRunnableWorkflow(random),
      );

      final Run run = planWorkflowRun(random, workflow);

      final RunStep running = run.steps.singleWhere(
        (RunStep step) => step.status == StepStatus.running,
      );
      final bool hasInput = workflow.connections.any(
        (AgentConnection connection) => connection.to == running.agentId,
      );
      expect(hasInput, isFalse);
      expect(run.log.single.stepName, running.name);
    }
  });
}
