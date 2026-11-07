import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../support/random_inputs.dart';
import '../fakes/support/workspace_work_rig.dart';
import 'support/node_backed_harness.dart';
import 'support/task_repository_rig.dart';

const int _rigIterations = 25;
const int _largestPollMilliseconds = 40;

Matcher _isMissing({required String kind, required String identifier}) {
  return isA<RecordNotFound>()
      .having((RecordNotFound missing) => missing.kind, 'kind', kind)
      .having(
        (RecordNotFound missing) => missing.identifier,
        'identifier',
        identifier,
      );
}

Set<WorkspaceId> _workspacesOf(WorkspaceWorkRig rig, List<Task> tasks) {
  final Map<ProjectId, WorkspaceId> workspaceOfProject =
      <ProjectId, WorkspaceId>{
        for (final Project project in rig.projects)
          project.id: project.workspaceId,
      };
  return <WorkspaceId>{
    for (final Task task in tasks) workspaceOfProject[task.projectId]!,
  };
}

Set<String> _listedIds(List<Task> tasks) {
  return <String>{for (final Task task in tasks) task.id.value};
}

void main() {
  test('test_node_backed_task_repository_property_starts_empty_and_'
      'silent', () async {
    final Random random = seededRandom(51401);
    for (int i = 0; i < _rigIterations; i += 1) {
      final Duration pollInterval = Duration(
        milliseconds: random.nextInt(_largestPollMilliseconds),
      );
      final TaskRepositoryRig rig = openTaskRepositoryRig(
        livePollInterval: pollInterval,
      );
      seedTasksWithRuns(random, rig.node);
      await pumpEventQueue();

      expect(rig.tasks.listTasks(), isEmpty);
      for (final String runId in rig.node.runs.keys) {
        expect(
          () => rig.tasks.findRun(RunId(runId)),
          throwsA(_isMissing(kind: 'run', identifier: runId)),
        );
      }
      for (final String taskId in rig.node.tasks.keys) {
        expect(rig.tasks.listRuns(TaskId(taskId)), isEmpty);
      }
      expect(rig.node.receivedCommands, isEmpty);
      closeTaskRepositoryRig(rig);
    }
  });

  test('test_node_backed_task_repository_property_loads_when_the_workspace_'
      'changes', () async {
    final Random random = seededRandom(51402);
    for (int i = 0; i < _rigIterations; i += 1) {
      final TaskRepositoryRig rig = openTaskRepositoryRig(
        livePollInterval: quietLivePollInterval,
      );
      seedTasksWithRuns(random, rig.node);

      await rig.workspaces.switchWorkspace(harnessWorkspaceId);
      await pumpEventQueue();

      final List<String> listed = <String>[
        for (final Task task in rig.tasks.listTasks()) task.id.value,
      ];
      expect(listed, listSimulatedOneTimeTaskIds(rig.node));
      closeTaskRepositoryRig(rig);
    }
  });

  test('test_node_backed_task_repository_property_live_reads_wait_for_the_'
      'poll_interval', () async {
    final Random random = seededRandom(51403);
    for (int i = 0; i < _rigIterations; i += 1) {
      final TaskRepositoryRig rig = await openSeededTaskRepositoryRig(random);
      final RunId runId = RunId('watched-${randomText(random)}');

      rig.tasks.watchRun(runId);
      for (int pump = 0; pump < 5; pump += 1) {
        await pumpEventQueue();
      }

      expect(countReceivedCommands(rig.node, 'watch_run'), 1);
      rig.tasks.stopWatchingRun(runId);
      closeTaskRepositoryRig(rig);
    }
  });

  test(
    'test_list_tasks_property_lists_one_time_tasks_in_node_order',
    () async {
      final Random random = seededRandom(51404);
      for (int i = 0; i < _rigIterations; i += 1) {
        final TaskRepositoryRig rig = await openSeededTaskRepositoryRig(
          random,
        );

        final List<Task> listed = rig.tasks.listTasks();

        expect(<String>[
          for (final Task task in listed) task.id.value,
        ], listSimulatedOneTimeTaskIds(rig.node));
        for (final Task task in listed) {
          expect(task.schedule, isNull);
        }
        closeTaskRepositoryRig(rig);
      }
    },
  );

  test(
    'test_list_tasks_property_keeps_only_current_workspace_tasks',
    () async {
      final Random random = seededRandom(51405);
      for (int i = 0; i < _rigIterations; i += 1) {
        final WorkspaceWorkRig rig = await buildWorkspaceWorkRig(random);
        for (int step = 0; step < 3; step += 1) {
          final List<Task> listed = rig.nodeTasks.listTasks();
          final WorkspaceId current = rig.workspaces.currentWorkspace().id;

          expect(_workspacesOf(rig, listed), everyElement(current));
          expect(_listedIds(listed), _listedIds(rig.fakeTasks.listTasks()));
          await switchWorkRigWorkspace(random, rig);
        }
        await closeWorkspaceWorkRig(rig);
      }
    },
  );

  test('test_list_tasks_property_is_stable_and_read_only', () async {
    final Random random = seededRandom(51406);
    for (int i = 0; i < _rigIterations; i += 1) {
      final TaskRepositoryRig rig = await openSeededTaskRepositoryRig(random);
      final List<Task> first = rig.tasks.listTasks();
      final List<Task> second = rig.tasks.listTasks();

      expect(second, orderedEquals(first));
      final Task draftTask = Task.fromDraft(
        id: TaskId(randomText(random)),
        draft: randomTaskDraft(random),
        schedule: null,
        status: TaskStatus.toDo,
        createdAt: taskRigMoment,
      );
      expect(() => first.add(draftTask), throwsUnsupportedError);
      expect(rig.tasks.listTasks().length, second.length);
      closeTaskRepositoryRig(rig);
    }
  });

  test('test_node_backed_task_repository_find_task_property_finds_every_'
      'listed_task', () async {
    final Random random = seededRandom(51407);
    for (int i = 0; i < _rigIterations; i += 1) {
      final TaskRepositoryRig rig = await openSeededTaskRepositoryRig(random);
      for (final Task task in rig.tasks.listTasks()) {
        expect(rig.tasks.findTask(task.id), same(task));
      }
      closeTaskRepositoryRig(rig);
    }
  });

  test('test_node_backed_task_repository_find_task_property_unknown_task_'
      'names_its_id', () async {
    final Random random = seededRandom(51408);
    final TaskRepositoryRig rig = await openSeededTaskRepositoryRig(random);
    for (int i = 0; i < propertyIterations; i += 1) {
      final String identifier = 'unknown ${randomText(random)}';
      expect(
        () => rig.tasks.findTask(TaskId(identifier)),
        throwsA(_isMissing(kind: 'task', identifier: identifier)),
      );
    }
    closeTaskRepositoryRig(rig);
  });

  test('test_list_runs_property_newest_number_first', () async {
    final Random random = seededRandom(51409);
    for (int i = 0; i < _rigIterations; i += 1) {
      final TaskRepositoryRig rig = await openSeededTaskRepositoryRig(random);
      for (final Task task in rig.tasks.listTasks()) {
        final List<Run> runs = rig.tasks.listRuns(task.id);
        for (int index = 1; index < runs.length; index += 1) {
          final int newerNumber = runs[index - 1].number;
          expect(newerNumber, greaterThanOrEqualTo(runs[index].number));
        }
      }
      closeTaskRepositoryRig(rig);
    }
  });

  test('test_list_runs_property_holds_exactly_that_tasks_runs', () async {
    final Random random = seededRandom(51410);
    for (int i = 0; i < _rigIterations; i += 1) {
      final TaskRepositoryRig rig = await openSeededTaskRepositoryRig(random);
      for (final Task task in rig.tasks.listTasks()) {
        final List<Run> runs = rig.tasks.listRuns(task.id);
        expect(<String>{
          for (final Run run in runs) run.id.value,
        }, listSimulatedRunIdsOf(rig.node, task.id));
        expect(runs.map((Run run) => run.taskId), everyElement(task.id));
      }
      closeTaskRepositoryRig(rig);
    }
  });

  test('test_list_runs_property_unknown_task_has_no_runs', () async {
    final Random random = seededRandom(51411);
    final TaskRepositoryRig rig = await openSeededTaskRepositoryRig(random);
    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskId unknown = TaskId('unknown ${randomText(random)}');
      expect(rig.tasks.listRuns(unknown), isEmpty);
    }
    closeTaskRepositoryRig(rig);
  });

  test('test_node_backed_task_repository_find_run_property_finds_every_'
      'listed_run', () async {
    final Random random = seededRandom(51412);
    for (int i = 0; i < _rigIterations; i += 1) {
      final TaskRepositoryRig rig = await openSeededTaskRepositoryRig(random);
      for (final Run run in listEveryListedRun(rig.tasks)) {
        expect(rig.tasks.findRun(run.id), same(run));
      }
      closeTaskRepositoryRig(rig);
    }
  });

  test('test_node_backed_task_repository_find_run_property_unknown_run_'
      'names_its_id', () async {
    final Random random = seededRandom(51413);
    final TaskRepositoryRig rig = await openSeededTaskRepositoryRig(random);
    for (int i = 0; i < propertyIterations; i += 1) {
      final String identifier = 'unknown ${randomText(random)}';
      expect(
        () => rig.tasks.findRun(RunId(identifier)),
        throwsA(_isMissing(kind: 'run', identifier: identifier)),
      );
    }
    closeTaskRepositoryRig(rig);
  });
}
