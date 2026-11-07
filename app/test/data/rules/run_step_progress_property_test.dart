import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/rules/run_lifecycle.dart';
import 'package:agent_orchestration/data/rules/run_step_progress.dart';

import '../../bridge/support/random_moments.dart';
import '../../support/random_inputs.dart';
import 'support/random_progress_runs.dart';

const Set<RunStatus> _finishedRunStatuses = <RunStatus>{
  RunStatus.done,
  RunStatus.failed,
  RunStatus.cancelled,
};

const Set<StepStatus> _finishedStepStatuses = <StepStatus>{
  StepStatus.done,
  StepStatus.failed,
  StepStatus.skipped,
};

int _countSteps(List<RunStep> steps, Set<StepStatus> statuses) {
  int count = 0;
  for (final RunStep step in steps) {
    if (statuses.contains(step.status)) {
      count += 1;
    }
  }
  return count;
}

RunStatus _expectedRunStatus(List<RunStep> steps) {
  final int failedCount = _countSteps(steps, <StepStatus>{StepStatus.failed});
  final int approvalCount = _countSteps(steps, <StepStatus>{
    StepStatus.waitingForApproval,
  });
  final int waitingCount = _countSteps(steps, <StepStatus>{
    StepStatus.waiting,
  });
  final int completedCount = _countSteps(steps, <StepStatus>{
    StepStatus.done,
    StepStatus.skipped,
  });

  if (failedCount > 0) {
    return RunStatus.failed;
  }
  if (approvalCount > 0) {
    return RunStatus.waitingForApproval;
  }
  if (waitingCount == steps.length) {
    return RunStatus.queued;
  }
  if (completedCount == steps.length) {
    return RunStatus.done;
  }
  return RunStatus.running;
}

void main() {
  test('test_is_run_finished_property_only_done_failed_cancelled_finish', () {
    for (final RunStatus status in RunStatus.values) {
      expect(isRunFinished(status), _finishedRunStatuses.contains(status));
    }
  });

  test('test_is_run_finished_property_is_the_opposite_of_being_active', () {
    final Random random = seededRandom(88401);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = randomProgressRun(random);

      expect(isRunFinished(run.status), !isRunActive(run));
    }
  });

  test('test_is_run_finished_property_finished_runs_take_no_step_change', () {
    final Random random = seededRandom(88402);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = randomProgressRun(random);
      if (!isRunFinished(run.status)) {
        continue;
      }

      for (final RunStep step in run.steps) {
        expect(canChangeRunStep(run, step.name), isFalse);
      }
    }
  });

  test('test_is_step_finished_property_only_done_failed_skipped_finish', () {
    for (final StepStatus status in StepStatus.values) {
      expect(isStepFinished(status), _finishedStepStatuses.contains(status));
    }
  });

  test('test_is_step_finished_property_skipping_finishes_every_step', () {
    final Random random = seededRandom(88403);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<RunStep> steps = randomProgressSteps(random);

      final List<RunStep> skipped = skipUnfinishedSteps(
        steps,
        randomPreciseMoment(random),
      );

      for (final RunStep step in skipped) {
        expect(isStepFinished(step.status), isTrue);
      }
    }
  });

  test('test_is_step_finished_property_finished_runs_hold_no_open_step', () {
    final Random random = seededRandom(88404);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<RunStep> steps = skipUnfinishedSteps(
        randomProgressSteps(random),
        randomPreciseMoment(random),
      );
      if (steps.isEmpty) {
        continue;
      }

      final RunStatus status = deriveRunStatus(steps);

      expect(isRunFinished(status), isTrue);
      expect(status, isNot(RunStatus.cancelled));
    }
  });

  test('test_derive_run_status_property_matches_the_counting_model', () {
    final Random random = seededRandom(88405);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<RunStep> steps = randomProgressSteps(random);

      expect(deriveRunStatus(steps), _expectedRunStatus(steps));
    }
  });

  test('test_derive_run_status_property_step_order_does_not_matter', () {
    final Random random = seededRandom(88406);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<RunStep> steps = randomProgressSteps(random);
      final List<RunStep> shuffled = <RunStep>[...steps]..shuffle(random);

      expect(deriveRunStatus(shuffled), deriveRunStatus(steps));
    }
  });

  test('test_derive_run_status_property_never_cancels_and_empty_queues', () {
    final Random random = seededRandom(88407);

    expect(deriveRunStatus(const <RunStep>[]), RunStatus.queued);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<RunStep> steps = randomProgressSteps(random);

      expect(deriveRunStatus(steps), isNot(RunStatus.cancelled));
    }
  });

  test('test_skip_unfinished_steps_property_finished_steps_stay_the_same', () {
    final Random random = seededRandom(88408);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<RunStep> steps = randomProgressSteps(random);

      final List<RunStep> skipped = skipUnfinishedSteps(
        steps,
        randomPreciseMoment(random),
      );

      expect(skipped.length, steps.length);
      for (int index = 0; index < steps.length; index += 1) {
        if (isStepFinished(steps[index].status)) {
          expect(describeStep(skipped[index]), describeStep(steps[index]));
        }
      }
    }
  });

  test('test_skip_unfinished_steps_property_open_steps_end_skipped_now', () {
    final Random random = seededRandom(88409);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<RunStep> steps = randomProgressSteps(random);
      final DateTime at = randomPreciseMoment(random);

      final List<RunStep> skipped = skipUnfinishedSteps(steps, at);

      for (int index = 0; index < steps.length; index += 1) {
        final RunStep before = steps[index];
        final RunStep after = skipped[index];
        if (isStepFinished(before.status)) {
          continue;
        }
        final RunStep expected = buildProgressStep(
          template: before,
          name: before.name,
          runner: before.runner,
          status: StepStatus.skipped,
        );
        expect(after.finishedAt, at);
        expect(after.startedAt, before.startedAt);
        expect(
          describeStep(after).sublist(0, 4),
          describeStep(expected).sublist(0, 4),
        );
        expect(
          describeStep(after).sublist(6),
          describeStep(expected).sublist(6),
        );
      }
    }
  });

  test(
    'test_skip_unfinished_steps_property_skipping_twice_changes_nothing',
    () {
      final Random random = seededRandom(88410);

      for (int i = 0; i < propertyIterations; i += 1) {
        final List<RunStep> once = skipUnfinishedSteps(
          randomProgressSteps(random),
          randomPreciseMoment(random),
        );

        final List<RunStep> twice = skipUnfinishedSteps(
          once,
          randomPreciseMoment(random),
        );

        expect(describeSteps(twice), describeSteps(once));
      }
    },
  );
}
