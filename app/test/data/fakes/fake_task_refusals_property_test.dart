import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/fakes/fake_task_lookups.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/repository/app_server_refusal.dart';
import 'package:agent_orchestration/data/rules/run_lifecycle.dart';

import '../../support/random_inputs.dart';
import '../../support/workflow_repositories.dart';
import 'support/refusals.dart';
import 'support/task_inputs.dart';

const int _conflictStatus = 409;

Matcher _isAlreadyRunning(String kind) {
  return throwsA(
    isA<AppServerRefusal>()
        .having(
          (AppServerRefusal refusal) => refusal.status,
          'status',
          _conflictStatus,
        )
        .having(
          (AppServerRefusal refusal) => refusal.message,
          'reason',
          'the $kind is already running',
        ),
  );
}

void main() {
  test('test_describe_task_kind_property_scheduled_work_is_a_job', () {
    final Random random = seededRandom(78701);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Task task = randomSeededTask(random, i);
      expect(describeTaskKind(task), task.schedule == null ? 'task' : 'job');
    }
  });

  test('test_describe_task_kind_property_ignores_every_other_field', () {
    final Random random = seededRandom(78702);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Task task = randomSeededTask(random, i);
      final Task restyled = task.withStatus(
        pickOne(random, TaskStatus.values),
      );
      expect(describeTaskKind(restyled), describeTaskKind(task));
    }
  });

  test('test_describe_task_kind_property_names_the_rust_kinds', () {
    final Random random = seededRandom(78703);
    for (int i = 0; i < propertyIterations; i += 1) {
      expect(<String>{
        'task',
        'job',
      }, contains(describeTaskKind(randomSeededTask(random, i))));
    }
  });

  test('test_refuse_second_active_run_property_refuses_iff_a_run_is_'
      'active', () {
    final Random random = seededRandom(78704);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Task> tasks = randomSeededTasks(random);
      final List<Run> runs = randomSeededRuns(random, tasks);
      for (final Task task in tasks) {
        final List<Run> taskRuns = <Run>[
          for (final Run run in runs)
            if (run.taskId == task.id) run,
        ];
        if (taskRuns.any(isRunActive)) {
          expect(
            () => refuseSecondActiveRun(task, taskRuns),
            _isAlreadyRunning(describeTaskKind(task)),
          );
        } else {
          refuseSecondActiveRun(task, taskRuns);
        }
      }
    }
  });

  test('test_refuse_second_active_run_property_no_runs_never_refuse', () {
    final Random random = seededRandom(78705);
    for (int i = 0; i < propertyIterations; i += 1) {
      refuseSecondActiveRun(randomSeededTask(random, i), const <Run>[]);
    }
  });

  test('test_refuse_second_active_run_property_names_the_kind', () {
    final Random random = seededRandom(78706);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Task task = randomSeededTask(random, i);
      final Run active = buildSeededRun(
        random,
        runId: 'active-$i',
        taskId: task.id,
        number: 1,
        status: pickOne(random, <String>[
          'queued',
          'running',
          'waiting_for_approval',
        ]),
      );

      expect(
        () => refuseSecondActiveRun(task, <Run>[active]),
        _isAlreadyRunning(describeTaskKind(task)),
      );
    }
  });

  test('test_fake_task_repository_new_property_starts_from_the_given_'
      'workflows', () async {
    final Random random = seededRandom(78707);
    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskSeed seed = randomTaskSeed(random);
      final FakeWorkflowRepository workflows =
          buildGalleryWorkflowRepository();
      final FakeTaskRepository repository = buildTaskRepository(
        tasks: seed.tasks,
        runs: seed.runs,
        workflows: workflows,
      );

      for (final Task task in seed.tasks) {
        final bool isStartable =
            canStartDoer(workflows, task.doer) &&
            !repository.listRuns(task.id).any(isRunActive);
        final bool isStarted = await isRefused(
          () => repository.startTask(task.id),
          isRefusal: refusesWithStateError,
        ).then((bool isRefusedHere) => !isRefusedHere);
        expect(isStarted, isStartable, reason: task.id.value);
      }
    }
  });

  test('test_fake_task_repository_list_tasks_and_jobs_in_current_workspace_'
      'property_unlinked_is_every_record', () {
    final Random random = seededRandom(78708);
    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskSeed seed = randomTaskSeed(random);
      final FakeTaskRepository repository = buildSeededTaskRepository(seed);

      expect(
        repository.listTasksAndJobsInCurrentWorkspace(),
        orderedEquals(seed.tasks),
      );
    }
  });
}
