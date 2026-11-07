import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/rules/run_lifecycle.dart';

import '../../support/random_inputs.dart';
import 'support/notification_counter.dart';
import 'support/refusals.dart';
import 'support/task_inputs.dart';
import 'support/task_rigs.dart';

const Set<StepStatus> _finishedStepStatuses = <StepStatus>{
  StepStatus.done,
  StepStatus.failed,
  StepStatus.skipped,
};

void main() {
  test('test_start_task_property_new_run_is_newest_and_running', () async {
    final Random random = seededRandom(66901);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskRig rig = buildTaskRig(randomTaskSeed(random));
      final List<Task> startable = listStartableTasks(rig);
      if (startable.isEmpty) {
        continue;
      }
      final Task task = pickOne(random, startable);
      final List<Run> before = rig.repository.listRuns(task.id);

      final Run run = await rig.repository.startTask(task.id);

      expect(rig.repository.listRuns(task.id).first, same(run));
      for (final Run older in before) {
        expect(run.number, greaterThan(older.number));
      }
      expect(run.status, RunStatus.running);
      expect(run.startedBy, taskClockDevice);
      expect(run.startedAt, taskClockMoment);
      expect(run.finishedAt, isNull);
      expect(rig.repository.findTask(task.id).status, TaskStatus.running);
    }
  });

  test('test_start_task_property_refuses_a_second_active_run', () async {
    final Random random = seededRandom(66902);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskRig rig = buildTaskRig(randomTaskSeed(random));
      final List<Run> active = listRunsWithStatus(
        rig.repository,
        const <RunStatus>{
          RunStatus.queued,
          RunStatus.running,
          RunStatus.waitingForApproval,
        },
      );
      if (active.isEmpty) {
        continue;
      }
      final Run busy = pickOne(random, active);
      final List<String> before = describeTaskRepository(rig.repository);

      final bool wasRefused = await isRefused(
        () => rig.repository.startTask(busy.taskId),
        isRefusal: refusesWithStateError,
      );

      expect(wasRefused, isTrue);
      expect(describeTaskRepository(rig.repository), before);
    }
  });

  test('test_start_task_property_refuses_workflows_not_signed', () async {
    final Random random = seededRandom(66903);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskRig rig = buildTaskRig(randomTaskSeed(random));
      final List<Task> unsigned = <Task>[
        for (final Task task in listIdleTasks(rig.repository))
          if (!canStartDoer(rig.flows, task.doer)) task,
      ];
      if (unsigned.isEmpty) {
        continue;
      }
      final Task task = pickOne(random, unsigned);
      final List<String> before = describeTaskRepository(rig.repository);
      final NotificationCounter counter = NotificationCounter();
      rig.repository.addListener(counter.record);

      final bool wasRefused = await isRefused(
        () => rig.repository.startTask(task.id),
        isRefusal: refusesWithStateError,
      );

      expect(wasRefused, isTrue);
      expect(describeTaskRepository(rig.repository), before);
      expect(counter.count, 0);
    }
  });

  test('test_cancel_run_property_skips_every_unfinished_step_now', () async {
    final Random random = seededRandom(66904);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskRig rig = buildTaskRig(randomTaskSeed(random));
      final List<Run> active = listRunsWithStatus(
        rig.repository,
        const <RunStatus>{
          RunStatus.queued,
          RunStatus.running,
          RunStatus.waitingForApproval,
        },
      );
      if (active.isEmpty) {
        continue;
      }
      final Run before = pickOne(random, active);

      final Run cancelled = await rig.repository.cancelRun(before.id);

      expect(cancelled.status, RunStatus.cancelled);
      expect(cancelled.finishedAt, taskClockMoment);
      for (int index = 0; index < before.steps.length; index += 1) {
        final RunStep earlier = before.steps[index];
        final RunStep later = cancelled.steps[index];
        if (_finishedStepStatuses.contains(earlier.status)) {
          expect(later, same(earlier));
          continue;
        }
        expect(later.status, StepStatus.skipped);
        expect(later.finishedAt, taskClockMoment);
        expect(later.name, earlier.name);
      }
    }
  });

  test('test_cancel_run_property_puts_the_task_back_to_do', () async {
    final Random random = seededRandom(66905);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskRig rig = buildTaskRig(randomTaskSeed(random));
      final List<Task> startable = listStartableTasks(rig);
      if (startable.isEmpty) {
        continue;
      }
      final Task task = pickOne(random, startable);
      final Run started = await rig.repository.startTask(task.id);

      await rig.repository.cancelRun(started.id);

      expect(rig.repository.findTask(task.id).status, TaskStatus.toDo);
      expect(rig.repository.listRuns(task.id).any(isRunActive), isFalse);
      expect(rig.repository.findRun(started.id).status, RunStatus.cancelled);
    }
  });

  test('test_cancel_run_property_finished_runs_are_refused', () async {
    final Random random = seededRandom(66906);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskRig rig = buildTaskRig(randomTaskSeed(random));
      final List<Run> finished = listRunsWithStatus(
        rig.repository,
        const <RunStatus>{
          RunStatus.done,
          RunStatus.failed,
          RunStatus.cancelled,
        },
      );
      if (finished.isEmpty) {
        continue;
      }
      final Run run = pickOne(random, finished);
      final List<String> before = describeTaskRepository(rig.repository);

      final bool wasRefused = await isRefused(
        () => rig.repository.cancelRun(run.id),
        isRefusal: refusesWithStateError,
      );

      expect(wasRefused, isTrue);
      expect(describeTaskRepository(rig.repository), before);
    }
  });
}
