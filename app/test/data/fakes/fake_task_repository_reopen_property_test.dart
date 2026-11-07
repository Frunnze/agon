import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/rules/run_lifecycle.dart';

import '../../support/random_inputs.dart';
import 'support/task_inputs.dart';
import 'support/task_rigs.dart';

List<Run> _listRetryableRuns(TaskRig rig) {
  return <Run>[
    for (final Run run in listRunsWithStatus(
      rig.repository,
      stoppedRunStatuses,
    ))
      if (!rig.repository.listRuns(run.taskId).any(isRunActive)) run,
  ];
}

bool _canStartTaskOf(TaskRig rig, Run run) {
  final Task task = rig.repository.findTask(run.taskId);
  return canStartDoer(rig.flows, task.doer);
}

List<RunId> _listRunIds(List<Run> runs) {
  return <RunId>[for (final Run run in runs) run.id];
}

List<int> _listRunNumbers(List<Run> runs) {
  return <int>[for (final Run run in runs) run.number];
}

void main() {
  test('test_retry_run_property_reopens_the_same_run_in_place', () async {
    final Random random = seededRandom(68301);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskRig rig = buildTaskRig(randomTaskSeed(random));
      final List<Run> retryable = _listRetryableRuns(rig);
      if (retryable.isEmpty) {
        continue;
      }
      final Run before = pickOne(random, retryable);
      final List<Run> runsBefore = rig.repository.listRuns(before.taskId);

      final Run reopened = await rig.repository.retryRun(before.id);

      final List<Run> runsAfter = rig.repository.listRuns(before.taskId);
      expect(reopened.id, before.id);
      expect(reopened.number, before.number);
      expect(_listRunIds(runsAfter), _listRunIds(runsBefore));
      expect(_listRunNumbers(runsAfter), _listRunNumbers(runsBefore));
      expect(rig.repository.findRun(before.id), same(reopened));
      expect(isRunActive(rig.repository.findRun(before.id)), isTrue);
    }
  });

  test('test_retry_run_property_keeps_the_log_chat_and_branch', () async {
    final Random random = seededRandom(68302);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskRig rig = buildTaskRig(randomTaskSeed(random));
      final List<Run> retryable = _listRetryableRuns(rig);
      if (retryable.isEmpty) {
        continue;
      }
      final Run before = pickOne(random, retryable);

      final Run reopened = await rig.repository.retryRun(before.id);

      expect(reopened.log, before.log);
      expect(reopened.chat, before.chat);
      expect(reopened.worktreeBranch, before.worktreeBranch);
      expect(reopened.startedAt, before.startedAt);
      expect(reopened.failure, isNull);
      expect(reopened.finishedAt, isNull);
    }
  });

  test(
    'test_retry_run_property_a_later_start_takes_the_next_number',
    () async {
      final Random random = seededRandom(68303);

      for (int i = 0; i < propertyIterations; i += 1) {
        final TaskRig rig = buildTaskRig(randomTaskSeed(random));
        final List<Run> retryable = <Run>[
          for (final Run run in _listRetryableRuns(rig))
            if (_canStartTaskOf(rig, run)) run,
        ];
        if (retryable.isEmpty) {
          continue;
        }
        final Run before = pickOne(random, retryable);
        final int highestNumber = rig.repository
            .listRuns(before.taskId)
            .first
            .number;

        final Run reopened = await rig.repository.retryRun(before.id);
        await rig.repository.cancelRun(reopened.id);
        final Run next = await rig.repository.startTask(before.taskId);

        expect(next.number, highestNumber + 1);
        expect(next.id, isNot(before.id));
        final Task task = rig.repository.findTask(before.taskId);
        expect(task.status, TaskStatus.running);
      }
    },
  );
}
