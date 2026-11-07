import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/fakes/fake_task_lookups.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/repository/app_server_refusal.dart';
import 'package:agent_orchestration/data/rules/workflow_problems.dart';

import '../../support/fake_task_work_links.dart';
import '../../support/random_inputs.dart';
import '../../support/sample_records.dart';
import 'support/startable_drafts.dart';
import 'support/task_inputs.dart';
import 'support/workflow_inputs.dart';

final OnlyWorkspaces _elsewhere = OnlyWorkspaces(const <WorkspaceId>[
  WorkspaceId('workspace-elsewhere'),
]);
const int _largestRunNumber = 50;

typedef _StartRig = ({
  FakeWorkflowRepository workflows,
  FakeTaskRepository tasks,
  Workflow workflow,
  Task task,
});

Workflow _randomSignedWorkflow(Random random, {required bool isBroken}) {
  final Workflow valid = withAvailabilityElsewhere(
    randomValidWorkflow(random, index: 0, signature: buildSampleSignature()),
  );
  if (!isBroken) {
    return valid;
  }
  Workflow broken = breakWorkflow(random, valid);
  while (describeWorkflowProblem(broken) == null) {
    broken = breakWorkflow(random, valid);
  }
  return broken;
}

Workflow withAvailabilityElsewhere(Workflow workflow) {
  return Workflow(
    id: workflow.id,
    name: workflow.name,
    availability: _elsewhere,
    agents: workflow.agents,
    connections: workflow.connections,
    signature: workflow.signature,
  );
}

_StartRig _buildStartRig(Random random, {required bool isBroken}) {
  final Workflow workflow = _randomSignedWorkflow(random, isBroken: isBroken);
  final FakeWorkflowRepository workflows = buildWorkflowRepositoryIn(
    workflows: <Workflow>[workflow],
    changes: const <WorkflowChange>[],
    workspaceRepository: buildAcmeWorkspaceRepository(),
  );
  final Task task = Task.fromDraft(
    id: const TaskId('task-with-workflow'),
    draft: replaceDraftDoer(
      randomTaskDraft(random),
      WorkflowDoer(workflow.id),
    ),
    schedule: null,
    status: TaskStatus.toDo,
    createdAt: randomUtcMoment(random),
  );
  return (
    workflows: workflows,
    tasks: buildTaskRepository(
      tasks: <Task>[task],
      runs: const <Run>[],
      workflows: workflows,
    ),
    workflow: workflow,
    task: task,
  );
}

Run _runNumbered(Random random, TaskId taskId, int number) {
  return buildSeededRun(
    random,
    runId: 'run-${taskId.value}-$number',
    taskId: taskId,
    number: number,
    status: 'done',
  );
}

void main() {
  test('test_start_task_property_refuses_invalid_signed_workflows', () async {
    final Random random = seededRandom(77901);
    for (int i = 0; i < propertyIterations; i += 1) {
      final _StartRig rig = _buildStartRig(random, isBroken: true);

      await expectLater(
        rig.tasks.startTask(rig.task.id),
        throwsA(
          isA<AppServerRefusal>().having(
            (AppServerRefusal refusal) => refusal.status,
            'status',
            400,
          ),
        ),
      );
      expect(rig.tasks.listRuns(rig.task.id), isEmpty);
      expect(rig.tasks.listTasksAndJobs().single.status, TaskStatus.toDo);
    }
  });

  test('test_start_task_property_starts_signed_workflows_of_any_'
      'workspace', () async {
    final Random random = seededRandom(77902);
    for (int i = 0; i < propertyIterations; i += 1) {
      final _StartRig rig = _buildStartRig(random, isBroken: false);
      expect(rig.workflows.listWorkflows(), isEmpty);

      final Run run = await rig.tasks.startTask(rig.task.id);

      expect(run.taskId, rig.task.id);
      expect(run.steps.length, rig.workflow.agents.length);
    }
  });

  test('test_find_startable_workflow_property_one_agent_tasks_need_no_'
      'workflow', () {
    final Random random = seededRandom(77903);
    for (int i = 0; i < propertyIterations; i += 1) {
      final _StartRig rig = _buildStartRig(
        random,
        isBroken: random.nextBool(),
      );
      final Task oneAgent = Task.fromDraft(
        id: rig.task.id,
        draft: replaceDraftDoer(
          rig.task.toDraft(),
          OneAgentDoer(pickOne(random, AgentKind.values)),
        ),
        schedule: null,
        status: TaskStatus.toDo,
        createdAt: rig.task.createdAt,
      );

      expect(findStartableWorkflow(oneAgent, rig.workflows), isNull);
    }
  });

  test('test_find_startable_workflow_property_names_the_server_problem', () {
    final Random random = seededRandom(77904);
    for (int i = 0; i < propertyIterations; i += 1) {
      final _StartRig rig = _buildStartRig(random, isBroken: true);
      final String problem = describeWorkflowProblem(rig.workflow)!;

      expect(
        () => findStartableWorkflow(rig.task, rig.workflows),
        throwsA(
          isA<AppServerRefusal>().having(
            (AppServerRefusal refusal) => refusal.message,
            'reason',
            problem,
          ),
        ),
      );
    }
  });

  test('test_find_startable_workflow_property_unsigned_is_refused_before_'
      'validity', () {
    final Random random = seededRandom(77905);
    for (int i = 0; i < propertyIterations; i += 1) {
      final _StartRig rig = _buildStartRig(
        random,
        isBroken: random.nextBool(),
      );
      final FakeWorkflowRepository unsigned = buildWorkflowRepositoryIn(
        workflows: <Workflow>[rig.workflow],
        changes: <WorkflowChange>[buildSampleChange(rig.workflow.id)],
        workspaceRepository: buildAcmeWorkspaceRepository(),
      );

      expect(
        () => findStartableWorkflow(rig.task, unsigned),
        throwsA(
          isA<StateError>().having(
            (StateError error) => error.message,
            'message',
            'workflow ${rig.workflow.name} is not signed',
          ),
        ),
      );
    }
  });

  test('test_find_task_in_property_finds_every_listed_task', () {
    final Random random = seededRandom(77906);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Task> tasks = randomSeededTasks(random);
      for (final Task task in tasks) {
        expect(findTaskIn(tasks, task.id), same(task));
      }
    }
  });

  test('test_find_task_in_property_missing_task_names_its_id', () {
    final Random random = seededRandom(77907);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Task> tasks = randomSeededTasks(random);
      final String missing = 'missing-${randomText(random)}';

      expect(
        () => findTaskIn(tasks, TaskId(missing)),
        throwsRecordNotFoundFor(missing),
      );
    }
  });

  test('test_find_task_in_property_first_match_wins_on_repeated_ids', () {
    final Random random = seededRandom(77908);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Task first = randomSeededTask(random, 0);
      final Task second = randomSeededTask(random, 0);

      expect(findTaskIn(<Task>[first, second], first.id), same(first));
    }
  });

  test('test_find_next_run_number_property_is_one_past_the_highest', () {
    final Random random = seededRandom(77909);
    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskId taskId = TaskId('task-${random.nextInt(3)}');
      final List<int> numbers = <int>[
        for (int run = 0; run < random.nextInt(6); run += 1)
          1 + random.nextInt(_largestRunNumber),
      ];
      final List<Run> runs = <Run>[
        for (final int number in numbers) _runNumbered(random, taskId, number),
      ];
      final int highest = numbers.fold(0, max);

      expect(findNextRunNumber(runs, taskId), highest + 1);
    }
  });

  test('test_find_next_run_number_property_ignores_other_tasks', () {
    final Random random = seededRandom(77910);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Run> others = <Run>[
        for (int run = 0; run < random.nextInt(6); run += 1)
          _runNumbered(random, TaskId('other-$run'), 1 + random.nextInt(9)),
      ];

      expect(findNextRunNumber(others, const TaskId('fresh')), 1);
    }
  });

  test('test_find_next_run_number_property_grows_with_every_run', () {
    final Random random = seededRandom(77911);
    for (int i = 0; i < propertyIterations; i += 1) {
      const TaskId taskId = TaskId('growing');
      final List<Run> runs = <Run>[];
      for (int step = 0; step < 1 + random.nextInt(6); step += 1) {
        final int next = findNextRunNumber(runs, taskId);
        runs.add(_runNumbered(random, taskId, next));
        expect(findNextRunNumber(runs, taskId), next + 1);
      }
    }
  });
}
