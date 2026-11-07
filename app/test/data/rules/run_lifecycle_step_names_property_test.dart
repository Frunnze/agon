import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_workflows.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/run_lifecycle.dart';

import '../../support/random_inputs.dart';
import '../../support/sample_records.dart';
import '../fakes/support/startable_drafts.dart';
import '../gallery/support/node_run_rules.dart';

Task _randomTaskWithDoer(Random random, TaskDoer doer) {
  return Task.fromDraft(
    id: TaskId('task-${randomText(random)}'),
    draft: replaceDraftDoer(randomTaskDraft(random), doer),
    schedule: random.nextBool() ? randomJobSchedule(random) : null,
    status: TaskStatus.toDo,
    createdAt: randomUtcMoment(random),
  );
}

Run _createRandomRun(Random random, Task task, Workflow? workflow) {
  return createRun(
    runId: RunId('run-${randomText(random)}'),
    task: task,
    workflow: workflow,
    number: 1 + random.nextInt(500),
    startedBy: GalleryDeviceIds.airLaptop,
    at: randomUtcMoment(random),
  );
}

void main() {
  test('test_plan_steps_property_one_agent_step_is_named_after_the_'
      'agent', () {
    final Random random = seededRandom(73201);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AgentKind agent = pickOne(random, AgentKind.values);
      final Task task = _randomTaskWithDoer(random, OneAgentDoer(agent));

      final Run run = _createRandomRun(random, task, null);

      expect(run.steps.single.name, nodeOneAgentStepNames[agent]);
      expect(run.steps.single.agentId, isNull);
    }
  });

  test('test_plan_steps_property_first_log_line_names_the_first_step', () {
    final Random random = seededRandom(73202);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AgentKind agent = pickOne(random, AgentKind.values);
      final Workflow workflow = pickOne(random, galleryWorkflows);
      final bool isOneAgentTask = random.nextBool();
      final TaskDoer doer = isOneAgentTask
          ? OneAgentDoer(agent)
          : WorkflowDoer(workflow.id);
      final Task task = _randomTaskWithDoer(random, doer);

      final Run run = isOneAgentTask
          ? _createRandomRun(random, task, null)
          : _createRandomRun(random, task, workflow);

      final String expectedFirstStepName = isOneAgentTask
          ? nodeOneAgentStepNames[agent]!
          : workflow.agents.first.name;
      expect(run.steps.first.name, expectedFirstStepName);
      expect(run.log.single.stepName, expectedFirstStepName);
    }
  });

  test('test_plan_steps_property_workflow_steps_keep_the_agent_names', () {
    final Random random = seededRandom(73203);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = pickOne(random, galleryWorkflows);
      final Task task = _randomTaskWithDoer(random, WorkflowDoer(workflow.id));

      final Run run = _createRandomRun(random, task, workflow);

      final List<String> stepNames = <String>[];
      final List<WorkflowAgentId?> stepAgentIds = <WorkflowAgentId?>[];
      for (final RunStep step in run.steps) {
        stepNames.add(step.name);
        stepAgentIds.add(step.agentId);
      }
      final List<String> agentNames = <String>[];
      final List<WorkflowAgentId?> agentIds = <WorkflowAgentId?>[];
      for (final WorkflowAgent workflowAgent in workflow.agents) {
        agentNames.add(workflowAgent.name);
        agentIds.add(workflowAgent.id);
      }
      expect(stepNames, agentNames);
      expect(stepAgentIds, agentIds);
    }
  });

  test('test_plan_steps_property_workflow_task_without_a_workflow_is_'
      'refused', () {
    final Random random = seededRandom(73204);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = pickOne(random, galleryWorkflows);
      final Task task = _randomTaskWithDoer(random, WorkflowDoer(workflow.id));

      expect(() => _createRandomRun(random, task, null), throwsArgumentError);
    }
  });
}
