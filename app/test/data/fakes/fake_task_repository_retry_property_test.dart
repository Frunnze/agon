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

const Set<RunStatus> _notRetryableStatuses = <RunStatus>{
  RunStatus.queued,
  RunStatus.running,
  RunStatus.waitingForApproval,
  RunStatus.done,
};

void main() {
  test('test_retry_run_property_keeps_done_steps_and_runs_again', () async {
    final Random random = seededRandom(66907);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskRig rig = buildTaskRig(randomTaskSeed(random));
      final List<Run> stopped = <Run>[
        for (final Run run in listRunsWithStatus(
          rig.repository,
          stoppedRunStatuses,
        ))
          if (!rig.repository.listRuns(run.taskId).any(isRunActive)) run,
      ];
      if (stopped.isEmpty) {
        continue;
      }
      final Run before = pickOne(random, stopped);
      final NotificationCounter counter = NotificationCounter();
      rig.repository.addListener(counter.record);

      final Run retried = await rig.repository.retryRun(before.id);

      expect(retried.status, RunStatus.running);
      expect(retried.worktreeBranch, before.worktreeBranch);
      expect(retried.steps.length, before.steps.length);
      for (int index = 0; index < before.steps.length; index += 1) {
        if (before.steps[index].status == StepStatus.done) {
          expect(retried.steps[index].status, StepStatus.done);
        }
      }
      final Task task = rig.repository.findTask(before.taskId);
      expect(task.status, TaskStatus.running);
      expect(counter.count, 1);
    }
  });

  test('test_retry_run_property_only_failed_or_cancelled_runs', () async {
    final Random random = seededRandom(66908);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskRig rig = buildTaskRig(randomTaskSeed(random));
      final List<Run> others = listRunsWithStatus(
        rig.repository,
        _notRetryableStatuses,
      );
      if (others.isEmpty) {
        continue;
      }
      final Run run = pickOne(random, others);
      final List<String> before = describeTaskRepository(rig.repository);

      final bool wasRefused = await isRefused(
        () => rig.repository.retryRun(run.id),
        isRefusal: refusesWithStateError,
      );

      expect(wasRefused, isTrue);
      expect(describeTaskRepository(rig.repository), before);
    }
  });

  test('test_retry_run_property_a_task_runs_once_at_a_time', () async {
    final Random random = seededRandom(66909);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskRig rig = buildTaskRig(randomTaskSeed(random));
      final List<Run> stoppedBesideActive = <Run>[
        for (final Run run in listRunsWithStatus(
          rig.repository,
          stoppedRunStatuses,
        ))
          if (rig.repository.listRuns(run.taskId).any(isRunActive)) run,
      ];
      if (stoppedBesideActive.isEmpty) {
        continue;
      }
      final Run run = pickOne(random, stoppedBesideActive);
      final List<String> before = describeTaskRepository(rig.repository);

      final bool wasRefused = await isRefused(
        () => rig.repository.retryRun(run.id),
        isRefusal: refusesWithStateError,
      );

      expect(wasRefused, isTrue);
      expect(describeTaskRepository(rig.repository), before);
      final int activeCount = rig.repository
          .listRuns(run.taskId)
          .where(isRunActive)
          .length;
      expect(activeCount, 1);
    }
  });
}
