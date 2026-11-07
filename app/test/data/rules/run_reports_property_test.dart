import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/rules/run_reports.dart';
import 'package:agent_orchestration/data/rules/run_step_progress.dart';

import '../../bridge/support/random_moments.dart';
import '../models/support/random_run_records.dart';
import '../../support/random_inputs.dart';
import 'support/random_progress_runs.dart';

bool _isAlreadyFailed(Run run, String stepName) {
  return stepsNamed(
    run,
    stepName,
  ).any((RunStep step) => step.status == StepStatus.failed);
}

RunFailure _randomFailureOf(Random random, Run run) {
  final RunFailure failure = randomRunFailure(random);
  return RunFailure(
    stepName: randomStepNameOf(random, run),
    runner: failure.runner,
    reason: failure.reason,
    retryRunsOnSameRunner: failure.retryRunsOnSameRunner,
  );
}

DeviceId? _reportingRunnerByModel(Run run) {
  for (final RunStep step in run.steps) {
    if (step.runner != null && !isStepFinished(step.status)) {
      return step.runner;
    }
  }
  return null;
}

List<Object?> _describeProgress(Run run) {
  return <Object?>[run.status, run.finishedAt, describeSteps(run.steps)];
}

void main() {
  test('test_can_fail_run_step_property_matches_the_server_guard', () {
    final Random random = seededRandom(88464);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = randomProgressRun(random);
      final String stepName = randomStepNameOf(random, run);
      final bool isKnown = stepsNamed(run, stepName).isNotEmpty;
      final bool isOpen =
          _isAlreadyFailed(run, stepName) || !isRunFinished(run.status);

      expect(canFailRunStep(run, stepName), isKnown && isOpen);
    }
  });

  test('test_can_fail_run_step_property_unknown_steps_cannot_fail', () {
    final Random random = seededRandom(88465);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = randomProgressRun(random);

      expect(canFailRunStep(run, unknownStepName), isFalse);
    }
  });

  test('test_can_fail_run_step_property_failed_steps_can_report_again', () {
    final Random random = seededRandom(88466);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = randomProgressRun(random);
      for (final RunStep step in run.steps) {
        if (_isAlreadyFailed(run, step.name)) {
          expect(canFailRunStep(run, step.name), isTrue);
        }
      }
    }
  });

  test('test_fail_run_step_property_reports_the_holder_and_the_reason', () {
    final Random random = seededRandom(88467);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = randomProgressRun(random);
      final RunFailure failure = _randomFailureOf(random, run);
      if (!canFailRunStep(run, failure.stepName)) {
        continue;
      }

      final Run failed = failRunStep(
        run: run,
        failure: failure,
        at: randomPreciseMoment(random),
      );

      final RunFailure? reported = failed.failure;
      expect(reported?.stepName, failure.stepName);
      expect(reported?.reason, failure.reason);
      expect(reported?.retryRunsOnSameRunner, failure.retryRunsOnSameRunner);
      expect(reported?.runner, stepsNamed(run, failure.stepName).first.runner);
    }
  });

  test('test_fail_run_step_property_fails_the_run_like_a_status_change', () {
    final Random random = seededRandom(88468);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = randomProgressRun(random);
      final RunFailure failure = _randomFailureOf(random, run);
      final DateTime at = randomPreciseMoment(random);
      if (!canFailRunStep(run, failure.stepName)) {
        continue;
      }

      final Run failed = failRunStep(run: run, failure: failure, at: at);

      final Run expected = _isAlreadyFailed(run, failure.stepName)
          ? run
          : applyStepStatus(
              run: run,
              stepName: failure.stepName,
              status: StepStatus.failed,
              at: at,
            );
      expect(_describeProgress(failed), _describeProgress(expected));
      if (!_isAlreadyFailed(run, failure.stepName)) {
        expect(failed.status, RunStatus.failed);
      }
    }
  });

  test('test_fail_run_step_property_reporting_twice_changes_nothing', () {
    final Random random = seededRandom(88469);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = randomProgressRun(random);
      final RunFailure failure = _randomFailureOf(random, run);
      if (!canFailRunStep(run, failure.stepName)) {
        expect(
          () => failRunStep(run: run, failure: failure, at: run.startedAt),
          throwsStateError,
        );
        continue;
      }
      final Run once = failRunStep(
        run: run,
        failure: failure,
        at: run.startedAt,
      );

      final Run twice = failRunStep(
        run: once,
        failure: failure,
        at: randomPreciseMoment(random),
      );

      expect(_describeProgress(twice), _describeProgress(once));
      expect(twice.failure?.runner, once.failure?.runner);
    }
  });

  test('test_finish_reporting_runner_steps_property_finished_runs_stay', () {
    final Random random = seededRandom(88470);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = randomProgressRun(random);
      if (!isRunFinished(run.status)) {
        continue;
      }

      final Run finished = finishReportingRunnerSteps(
        run,
        randomPreciseMoment(random),
      );

      expect(_describeProgress(finished), _describeProgress(run));
    }
  });

  test('test_finish_reporting_runner_steps_property_holder_steps_finish', () {
    final Random random = seededRandom(88471);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = randomActiveRun(random);
      final DeviceId? reportingRunner = _reportingRunnerByModel(run);

      final Run finished = finishReportingRunnerSteps(
        run,
        randomPreciseMoment(random),
      );

      final bool isChanged =
          _describeProgress(finished).toString() !=
          _describeProgress(run).toString();
      for (int index = 0; index < run.steps.length; index += 1) {
        final RunStep before = run.steps[index];
        final RunStep after = finished.steps[index];
        final bool isReported =
            reportingRunner != null && before.runner == reportingRunner;
        if (isChanged && isReported) {
          expect(isStepFinished(after.status), isTrue);
        }
        if (!isReported && finished.status != RunStatus.failed) {
          expect(describeStep(after), describeStep(before));
        }
      }
    }
  });

  test('test_finish_reporting_runner_steps_property_one_holder_ends_once', () {
    final Random random = seededRandom(88472);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = randomActiveRun(random);
      final Run singleHolderRun = buildProgressRun(
        random,
        status: run.status,
        steps: <RunStep>[
          for (final RunStep step in run.steps)
            buildProgressStep(
              template: step,
              name: step.name,
              runner: step.runner == null ? null : holdingRunner,
              status: step.status,
            ),
        ],
      );
      final DateTime at = randomPreciseMoment(random);

      final Run once = finishReportingRunnerSteps(singleHolderRun, at);
      final Run twice = finishReportingRunnerSteps(once, at);

      expect(_describeProgress(twice), _describeProgress(once));
    }
  });
}
