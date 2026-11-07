import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/gallery/gallery_runs.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/rules/run_lifecycle.dart';

import '../../support/random_inputs.dart';
import '../fakes/support/task_inputs.dart';

const List<String> _stoppedStatuses = <String>['failed', 'cancelled'];
const List<String> _otherStatuses = <String>[
  'queued',
  'running',
  'waiting_for_approval',
  'done',
];
const Set<StepStatus> _reopenedStepStatuses = <StepStatus>{
  StepStatus.failed,
  StepStatus.skipped,
};

Run _randomRunWithStatus(Random random, List<String> statuses) {
  return buildSeededRun(
    random,
    runId: 'run-${randomText(random)}',
    taskId: TaskId('task-${randomText(random)}'),
    number: 1 + random.nextInt(500),
    status: pickOne(random, statuses),
  );
}

Run _randomStoppedRun(Random random) {
  if (random.nextInt(5) == 0) {
    return galleryFailedRun;
  }
  return _randomRunWithStatus(random, _stoppedStatuses);
}

void main() {
  test('test_build_retried_run_property_reopens_the_same_run', () {
    final Random random = seededRandom(68101);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run stopped = _randomStoppedRun(random);

      final Run reopened = buildRetriedRun(stopped, galleryNow);

      expect(reopened.id, stopped.id);
      expect(reopened.taskId, stopped.taskId);
      expect(reopened.number, stopped.number);
      expect(reopened.log, stopped.log);
      expect(reopened.chat, stopped.chat);
      expect(reopened.notes, stopped.notes);
      expect(reopened.loopRounds, stopped.loopRounds);
      expect(reopened.worktreeBranch, stopped.worktreeBranch);
      expect(reopened.agentSession, stopped.agentSession);
      expect(reopened.startedBy, stopped.startedBy);
      expect(reopened.startedAt, stopped.startedAt);
    }
  });

  test('test_build_retried_run_property_failed_and_skipped_steps_run_'
      'again', () {
    final Random random = seededRandom(68102);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run stopped = _randomStoppedRun(random);

      final Run reopened = buildRetriedRun(stopped, galleryNow);

      expect(isRunActive(reopened), isTrue);
      expect(reopened.failure, isNull);
      expect(reopened.finishedAt, isNull);
      expect(reopened.steps.length, stopped.steps.length);
      for (int index = 0; index < stopped.steps.length; index += 1) {
        final RunStep before = stopped.steps[index];
        final RunStep after = reopened.steps[index];
        expect(after.name, before.name);
        expect(_reopenedStepStatuses, isNot(contains(after.status)));
        if (before.status == StepStatus.done) {
          expect(after.status, StepStatus.done);
          expect(after.finishedAt, before.finishedAt);
        }
      }
      final bool hadUnfinishedStep = stopped.steps.any(
        (RunStep step) => step.status != StepStatus.done,
      );
      final int runningCount = reopened.steps
          .where((RunStep step) => step.status == StepStatus.running)
          .length;
      expect(runningCount, hadUnfinishedStep ? 1 : 0);
    }
  });

  test('test_build_retried_run_property_only_stopped_runs_reopen', () {
    final Random random = seededRandom(68103);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run other = _randomRunWithStatus(random, _otherStatuses);
      final Run stopped = _randomStoppedRun(random);
      final Run reopened = buildRetriedRun(stopped, galleryNow);

      expect(() => buildRetriedRun(other, galleryNow), throwsStateError);
      expect(() => buildRetriedRun(reopened, galleryNow), throwsStateError);
    }
  });
}
