import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';

import '../../support/random_inputs.dart';
import '../../support/workflow_repositories.dart';
import '../gallery/support/node_run_rules.dart' show nodeOneAgentStepNames;
import 'support/refusals.dart';
import 'support/task_inputs.dart';
import 'support/task_rigs.dart';

const int _longestSequence = 12;
const int _largestTakenRunIdCount = 4;

bool _refusesWithAnyError(Object error) => true;

Task _seedTaskWithDoer(Random random, TaskDoer doer) {
  final Task shape = randomSeededTask(random, 0);
  final TaskDraft draft = shape.toDraft();
  return Task.fromDraft(
    id: shape.id,
    draft: TaskDraft(
      title: draft.title,
      details: draft.details,
      projectId: draft.projectId,
      doer: doer,
      runsOn: draft.runsOn,
      agentPlace: draft.agentPlace,
      skills: draft.skills,
      usesAutomaticSkills: draft.usesAutomaticSkills,
      approvalPolicy: draft.approvalPolicy,
    ),
    schedule: shape.schedule,
    status: TaskStatus.toDo,
    createdAt: shape.createdAt,
  );
}

Future<List<Run>> _runRandomSequence(Random random, TaskRig rig) async {
  final List<Run> returned = <Run>[];
  final int stepCount = random.nextInt(_longestSequence);
  for (int step = 0; step < stepCount; step += 1) {
    final List<Task> startable = listStartableTasks(rig);
    if (startable.isEmpty) {
      return returned;
    }
    final Task task = pickOne(random, startable);
    final Run started = await rig.repository.startTask(task.id);
    returned.add(started);
    final Run cancelled = await rig.repository.cancelRun(started.id);
    returned.add(cancelled);
    if (random.nextBool()) {
      returned.add(await rig.repository.retryRun(cancelled.id));
    }
  }
  return returned;
}

void main() {
  test('test_find_signed_workflow_for_property_one_agent_'
      'runs_one_step', () async {
    final Random random = seededRandom(67001);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AgentKind agent = pickOne(random, AgentKind.values);
      final Task task = _seedTaskWithDoer(random, OneAgentDoer(agent));
      final TaskRig rig = buildTaskRig((tasks: <Task>[task], runs: <Run>[]));

      final Run run = await rig.repository.startTask(task.id);

      expect(run.steps.length, 1);
      expect(run.steps.single.name, nodeOneAgentStepNames[agent]);
      final RunnerTarget target = task.runsOn;
      final DeviceId? pinned = target is SpecificRunner
          ? target.deviceId
          : null;
      expect(run.steps.single.runner, pinned);
    }
  });

  test('test_find_signed_workflow_for_property_steps_follow_'
      'the_agents', () async {
    final Random random = seededRandom(67002);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeWorkflowRepository flows = buildGalleryWorkflowRepository();
      final List<Workflow> signed = <Workflow>[
        for (final Workflow workflow in flows.listWorkflows())
          if (canStartDoer(flows, WorkflowDoer(workflow.id))) workflow,
      ];
      final Workflow workflow = pickOne(random, signed);
      final Task task = _seedTaskWithDoer(random, WorkflowDoer(workflow.id));
      final FakeTaskRepository repository = buildTaskRepository(
        tasks: <Task>[task],
        runs: const <Run>[],
        workflows: flows,
      );

      final Run run = await repository.startTask(task.id);

      final List<String> stepNames = <String>[
        for (final RunStep step in run.steps) step.name,
      ];
      final List<String> agentNames = <String>[
        for (final WorkflowAgent agent in workflow.agents) agent.name,
      ];
      expect(stepNames, agentNames);
    }
  });

  test(
    'test_find_signed_workflow_for_property_missing_workflows_store_nothing',
    () async {
      final Random random = seededRandom(67003);

      for (int i = 0; i < propertyIterations; i += 1) {
        final WorkflowId missing = WorkflowId('missing-${randomText(random)}');
        final Task task = _seedTaskWithDoer(random, WorkflowDoer(missing));
        final TaskRig rig = buildTaskRig((tasks: <Task>[task], runs: <Run>[]));

        final bool wasRefused = await isRefused(
          () => rig.repository.startTask(task.id),
          isRefusal: _refusesWithAnyError,
        );

        expect(wasRefused, isTrue);
        expect(rig.repository.listRuns(task.id), isEmpty);
        expect(rig.repository.findTask(task.id).status, TaskStatus.toDo);
      }
    },
  );

  test('test_next_run_id_property_ids_never_repeat', () async {
    final Random random = seededRandom(67004);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskRig rig = buildTaskRig(randomTaskSeed(random));

      await _runRandomSequence(random, rig);

      final List<RunId> ids = <RunId>[
        for (final Task task in rig.repository.listTasksAndJobs())
          for (final Run run in rig.repository.listRuns(task.id)) run.id,
      ];
      expect(ids.toSet().length, ids.length);
    }
  });

  test('test_next_run_id_property_never_reuses_a_seeded_id', () async {
    final Random random = seededRandom(67005);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Task owner = _seedTaskWithDoer(
        random,
        const OneAgentDoer(AgentKind.claudeCode),
      );
      final int takenCount = 1 + random.nextInt(_largestTakenRunIdCount);
      final List<Run> seededRuns = <Run>[
        for (int index = 1; index <= takenCount; index += 1)
          buildSeededRun(
            random,
            runId: '$createdRunIdPrefix$index',
            taskId: owner.id,
            number: index,
            status: 'done',
          ),
      ];
      final TaskRig rig = buildTaskRig((
        tasks: <Task>[owner],
        runs: seededRuns,
      ));

      final Run run = await rig.repository.startTask(owner.id);

      final List<RunId> seededIds = <RunId>[
        for (final Run seeded in seededRuns) seeded.id,
      ];
      expect(seededIds, isNot(contains(run.id)));
    }
  });

  test('test_next_run_id_property_returned_runs_are_findable', () async {
    final Random random = seededRandom(67006);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskRig rig = buildTaskRig(randomTaskSeed(random));

      final List<Run> returned = await _runRandomSequence(random, rig);

      for (final Run run in returned) {
        expect(rig.repository.findRun(run.id).taskId, run.taskId);
      }
    }
  });

  test('test_next_run_number_property_grows_past_the_tasks_runs', () async {
    final Random random = seededRandom(67007);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskRig rig = buildTaskRig(randomTaskSeed(random));
      final List<Task> startable = listStartableTasks(rig);
      if (startable.isEmpty) {
        continue;
      }
      final Task task = pickOne(random, startable);
      final List<int> earlierNumbers = <int>[
        for (final Run run in rig.repository.listRuns(task.id)) run.number,
      ];

      final Run run = await rig.repository.startTask(task.id);

      expect(run.number, greaterThanOrEqualTo(1));
      for (final int earlier in earlierNumbers) {
        expect(run.number, greaterThan(earlier));
      }
    }
  });

  test(
    'test_next_run_number_property_ignores_runs_of_unknown_tasks',
    () async {
      final Random random = seededRandom(67008);

      for (int i = 0; i < propertyIterations; i += 1) {
        final Task task = _seedTaskWithDoer(
          random,
          const OneAgentDoer(AgentKind.claudeCode),
        );
        final Run orphan = buildSeededRun(
          random,
          runId: 'orphan-run-$i',
          taskId: TaskId('gone-task-$i'),
          number: 1 + random.nextInt(50),
          status: 'done',
        );
        final TaskRig rig = buildTaskRig((
          tasks: <Task>[task],
          runs: <Run>[orphan],
        ));

        final Run run = await rig.repository.startTask(task.id);

        expect(run.taskId, task.id);
        expect(rig.repository.findRun(orphan.id), same(orphan));
      }
    },
  );

  test('test_next_run_number_property_differs_within_a_task', () async {
    final Random random = seededRandom(67009);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskRig rig = buildTaskRig(randomTaskSeed(random));

      await _runRandomSequence(random, rig);

      for (final Task task in rig.repository.listTasksAndJobs()) {
        final List<int> numbers = <int>[
          for (final Run run in rig.repository.listRuns(task.id)) run.number,
        ];
        expect(numbers.toSet().length, numbers.length);
      }
    }
  });
}
