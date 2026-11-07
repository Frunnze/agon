import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/run_lifecycle.dart';

import '../../support/random_inputs.dart';
import '../../support/random_signature_workflows.dart';
import '../../support/sample_records.dart';
import 'support/notification_counter.dart';
import 'support/refusals.dart';
import 'support/startable_drafts.dart';
import 'support/task_inputs.dart';
import 'support/task_rigs.dart';

typedef _WorkflowTask = ({
  FakeTaskRepository tasks,
  FakeWorkflowRepository flows,
  Task task,
  WorkflowInSignatureState choice,
});

Future<_WorkflowTask> _createRandomWorkflowTask(Random random) async {
  final List<WorkflowInSignatureState> choices =
      randomWorkflowsInSignatureStates(random);
  final FakeWorkflowRepository flows = buildSignatureStateRepository(choices);
  final FakeTaskRepository tasks = buildTaskRepository(
    tasks: const <Task>[],
    runs: const <Run>[],
    workflows: flows,
  );
  final WorkflowInSignatureState choice = pickOne(random, choices);
  final TaskDraft draft = replaceDraftDoer(
    randomTaskDraft(random),
    WorkflowDoer(choice.workflow.id),
  );
  final Task task = await tasks.createTask(draft);
  return (tasks: tasks, flows: flows, task: task, choice: choice);
}

List<String> _listStepNames(Run run) {
  return <String>[for (final RunStep step in run.steps) step.name];
}

List<String> _listAgentNames(Workflow workflow) {
  return <String>[
    for (final WorkflowAgent agent in workflow.agents) agent.name,
  ];
}

void main() {
  test('test_find_signed_workflow_for_property_only_signed_unchanged_'
      'workflows_start', () async {
    final Random random = seededRandom(68201);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _WorkflowTask created = await _createRandomWorkflowTask(random);
      final NotificationCounter counter = NotificationCounter();
      created.tasks.addListener(counter.record);

      final bool wasRefused = await isRefused(
        () => created.tasks.startTask(created.task.id),
        isRefusal: refusesWithStateError,
      );

      expect(wasRefused, !created.choice.isSigned);
      final List<Run> runs = created.tasks.listRuns(created.task.id);
      expect(runs.length, wasRefused ? 0 : 1);
      final TaskStatus status = created.tasks.findTask(created.task.id).status;
      expect(status, wasRefused ? TaskStatus.toDo : TaskStatus.running);
      expect(counter.count, wasRefused ? 0 : 1);
    }
  });

  test('test_find_signed_workflow_for_property_signing_the_change_lets_'
      'it_start', () async {
    final Random random = seededRandom(68202);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _WorkflowTask created = await _createRandomWorkflowTask(random);
      if (created.choice.state != SignatureState.changedNotSigned) {
        continue;
      }

      final Workflow signed = await created.flows.signWorkflow(
        created.choice.workflow.id,
      );
      final Run run = await created.tasks.startTask(created.task.id);

      expect(_listStepNames(run), _listAgentNames(signed));
      expect(isRunActive(run), isTrue);
    }
  });

  test('test_find_signed_workflow_for_property_an_edit_after_signing_'
      'blocks_the_start', () async {
    final Random random = seededRandom(68203);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _WorkflowTask created = await _createRandomWorkflowTask(random);
      if (!created.choice.isSigned) {
        continue;
      }
      final Workflow stored = created.flows.findWorkflow(
        created.choice.workflow.id,
      );
      final List<WorkflowAgent> firstAgentOnly = stored.agents.sublist(0, 1);

      await created.flows.saveWorkflow(
        stored.withGraph(
          agents: firstAgentOnly,
          connections: const <AgentConnection>[],
        ),
      );
      final bool wasRefused = await isRefused(
        () => created.tasks.startTask(created.task.id),
        isRefusal: refusesWithStateError,
      );

      expect(created.flows.findPendingChange(stored.id), isNotNull);
      expect(wasRefused, isTrue);
      expect(created.tasks.listRuns(created.task.id), isEmpty);
    }
  });

  test('test_find_signed_workflow_for_property_startable_drafts_always_'
      'start', () async {
    final Random random = seededRandom(68204);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskRig rig = buildTaskRig(randomTaskSeed(random));
      final Task task = await rig.repository.createTask(
        randomStartableTaskDraft(random, rig.flows),
      );

      final Run run = await rig.repository.startTask(task.id);

      expect(run.taskId, task.id);
      expect(canStartDoer(rig.flows, task.doer), isTrue);
    }
  });
}
