import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/rules/run_step_progress.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../bridge/support/random_moments.dart';
import '../models/support/random_run_records.dart';
import '../../support/random_inputs.dart';
import 'support/random_progress_runs.dart';

typedef _StatusChange = ({
  Run run,
  String stepName,
  StepStatus status,
  DateTime at,
});

_StatusChange _randomChangeOfActiveRun(Random random) {
  final Run run = randomActiveRun(random);
  return (
    run: run,
    stepName: randomStepNameOf(random, run),
    status: pickOne(random, StepStatus.values),
    at: randomPreciseMoment(random),
  );
}

Run _applyChange(_StatusChange change) {
  return applyStepStatus(
    run: change.run,
    stepName: change.stepName,
    status: change.status,
    at: change.at,
  );
}

void main() {
  test('test_can_change_run_step_property_unknown_steps_are_refused', () {
    final Random random = seededRandom(88421);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = randomProgressRun(random);

      expect(canChangeRunStep(run, unknownStepName), isFalse);
    }
  });

  test(
    'test_can_change_run_step_property_matches_open_run_and_known_step',
    () {
      final Random random = seededRandom(88422);

      for (int i = 0; i < propertyIterations; i += 1) {
        final Run run = randomProgressRun(random);
        final String stepName = randomStepNameOf(random, run);
        final bool isKnown = stepsNamed(run, stepName).isNotEmpty;

        expect(
          canChangeRunStep(run, stepName),
          isKnown && !isRunFinished(run.status),
        );
      }
    },
  );

  test('test_can_change_run_step_property_step_runner_does_not_matter', () {
    final Random random = seededRandom(88423);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = randomActiveRun(random);

      for (final RunStep step in run.steps) {
        expect(canChangeRunStep(run, step.name), isTrue);
      }
    }
  });

  test('test_apply_step_status_property_refused_changes_throw', () {
    final Random random = seededRandom(88424);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = randomProgressRun(random);
      final String stepName = randomStepNameOf(random, run);
      if (canChangeRunStep(run, stepName)) {
        continue;
      }

      expect(
        () => applyStepStatus(
          run: run,
          stepName: stepName,
          status: pickOne(random, StepStatus.values),
          at: randomPreciseMoment(random),
        ),
        throwsStateError,
      );
    }
  });

  test('test_apply_step_status_property_run_status_follows_the_steps', () {
    final Random random = seededRandom(88425);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _StatusChange change = _randomChangeOfActiveRun(random);
      if (!canChangeRunStep(change.run, change.stepName)) {
        continue;
      }

      final Run changed = _applyChange(change);

      expect(changed.status, deriveRunStatus(changed.steps));
      final DateTime? expectedEnd = isRunFinished(changed.status)
          ? change.at
          : null;
      expect(changed.finishedAt, expectedEnd);
      if (changed.status == RunStatus.failed) {
        for (final RunStep step in changed.steps) {
          expect(isStepFinished(step.status), isTrue);
        }
      }
    }
  });

  test(
    'test_apply_step_status_property_named_step_takes_status_and_times',
    () {
      final Random random = seededRandom(88426);

      for (int i = 0; i < propertyIterations; i += 1) {
        final _StatusChange change = _randomChangeOfActiveRun(random);
        if (!canChangeRunStep(change.run, change.stepName)) {
          continue;
        }

        final Run changed = _applyChange(change);

        for (int index = 0; index < changed.steps.length; index += 1) {
          final RunStep before = change.run.steps[index];
          final RunStep after = changed.steps[index];
          final bool isSkippedByFailure =
              after.status == StepStatus.skipped &&
              change.status != StepStatus.skipped;
          if (before.name != change.stepName || isSkippedByFailure) {
            continue;
          }
          final bool isStarting =
              change.status == StepStatus.running && before.startedAt == null;
          final bool isEnding = isStepFinished(change.status);
          expect(after.status, change.status);
          expect(after.startedAt, isStarting ? change.at : before.startedAt);
          expect(after.finishedAt, isEnding ? change.at : null);
        }
      }
    },
  );

  test(
    'test_apply_step_status_property_other_steps_change_only_on_failure',
    () {
      final Random random = seededRandom(88427);

      for (int i = 0; i < propertyIterations; i += 1) {
        final _StatusChange change = _randomChangeOfActiveRun(random);
        if (!canChangeRunStep(change.run, change.stepName)) {
          continue;
        }

        final Run changed = _applyChange(change);

        expect(changed.id, change.run.id);
        expect(changed.log, change.run.log);
        expect(changed.failure, change.run.failure);
        for (int index = 0; index < changed.steps.length; index += 1) {
          final RunStep before = change.run.steps[index];
          final RunStep after = changed.steps[index];
          if (before.name == change.stepName) {
            continue;
          }
          final bool isSkippedByFailure =
              changed.status == RunStatus.failed &&
              !isStepFinished(before.status);
          final RunStep expected = isSkippedByFailure
              ? skipUnfinishedSteps(<RunStep>[before], change.at).single
              : before;
          expect(describeStep(after), describeStep(expected));
        }
      }
    },
  );

  test('test_record_step_result_property_named_steps_take_the_result', () {
    final Random random = seededRandom(88428);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = randomActiveRun(random);
      final String stepName = randomStepNameOf(random, run);
      if (!canChangeRunStep(run, stepName)) {
        continue;
      }
      final String result = randomHostileText(random);
      final String? outcome = randomOptionalHostileText(random);

      final Run recorded = recordStepResult(
        run: run,
        stepName: stepName,
        result: result,
        outcome: outcome,
      );

      for (final RunStep step in stepsNamed(recorded, stepName)) {
        expect(step.result, result);
        expect(step.outcome, outcome);
      }
    }
  });

  test('test_record_step_result_property_status_and_other_steps_stay', () {
    final Random random = seededRandom(88429);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = randomActiveRun(random);
      final String stepName = randomStepNameOf(random, run);
      if (!canChangeRunStep(run, stepName)) {
        continue;
      }

      final Run recorded = recordStepResult(
        run: run,
        stepName: stepName,
        result: randomHostileText(random),
        outcome: randomOptionalHostileText(random),
      );

      expect(recorded.status, run.status);
      expect(recorded.finishedAt, run.finishedAt);
      for (int index = 0; index < run.steps.length; index += 1) {
        final List<Object?> before = describeStep(run.steps[index]);
        final List<Object?> after = describeStep(recorded.steps[index]);
        if (run.steps[index].name == stepName) {
          expect(after.sublist(0, 6), before.sublist(0, 6));
          expect(after.sublist(8), before.sublist(8));
        } else {
          expect(after, before);
        }
      }
    }
  });

  test('test_record_step_result_property_refused_results_throw', () {
    final Random random = seededRandom(88430);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = randomProgressRun(random);
      final String stepName = randomStepNameOf(random, run);
      if (canChangeRunStep(run, stepName)) {
        continue;
      }

      expect(
        () => recordStepResult(
          run: run,
          stepName: stepName,
          result: randomHostileText(random),
          outcome: null,
        ),
        throwsStateError,
      );
    }
  });
}
