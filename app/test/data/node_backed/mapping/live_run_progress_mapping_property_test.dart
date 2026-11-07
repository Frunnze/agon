import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/live_run_values.dart'
    as node;
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';
import 'package:agent_orchestration/data/rules/run_step_progress.dart';

import '../../../bridge/support/random_moments.dart';
import '../../../support/random_inputs.dart';
import '../../rules/support/random_progress_runs.dart';
import 'support/live_run_event_sequences.dart';
import 'support/live_run_views.dart';

Run _applyOne(Run run, node.RunEvent event, DateTime at) {
  return applyLiveRunView(
    run: run,
    view: buildLiveView(<node.RunEvent>[event]),
    at: at,
  );
}

Run _startedRun(Random random) {
  final Run fresh = freshHeldRun(random);
  final RunStep first = fresh.steps.first;
  return _applyOne(
    fresh,
    buildStatusEvent(first.name, StepStatus.running),
    randomPreciseMoment(random),
  );
}

void main() {
  test('test_fail_step_property_a_failure_ends_the_run_as_failed', () {
    final Random random = seededRandom(88481);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = _startedRun(random);
      final RunStep failing = pickOne(random, run.steps);
      final DateTime at = randomPreciseMoment(random);

      final Run failed = _applyOne(
        run,
        buildFailureEvent(random, failing.name),
        at,
      );

      expect(failed.status, RunStatus.failed);
      expect(failed.finishedAt, at);
      expect(failed.failure?.stepName, failing.name);
      expect(failed.failure?.runner, failing.runner);
      for (final RunStep step in failed.steps) {
        expect(isStepFinished(step.status), isTrue);
        expect(step.finishedAt, isNotNull);
      }
    }
  });

  test('test_change_step_status_property_moves_the_run_and_the_times', () {
    final Random random = seededRandom(88482);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = freshHeldRun(random);
      final RunStep step = pickOne(random, run.steps);
      final StepStatus status = pickOne(random, StepStatus.values);
      final DateTime at = randomPreciseMoment(random);

      final Run changed = _applyOne(
        run,
        buildStatusEvent(step.name, status),
        at,
      );

      final RunStep after = stepsNamed(changed, step.name).single;
      expect(changed.status, deriveRunStatus(changed.steps));
      expect(changed.finishedAt, isRunFinished(changed.status) ? at : null);
      expect(after.startedAt, status == StepStatus.running ? at : null);
      final bool isEnded = isStepFinished(after.status);
      expect(after.finishedAt, isEnded ? at : null);
    }
  });

  test('test_record_step_result_property_live_results_reach_the_step', () {
    final Random random = seededRandom(88483);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = _startedRun(random);
      final RunStep step = pickOne(random, run.steps);
      final String result = 'result ${randomText(random)}';
      final String? outcome = random.nextBool() ? randomText(random) : null;

      final Run recorded = _applyOne(
        run,
        node.StepResultRecorded(
          stepName: step.name,
          result: result,
          outcome: outcome,
        ),
        randomPreciseMoment(random),
      );

      final RunStep after = stepsNamed(recorded, step.name).single;
      expect(after.result, result);
      expect(after.outcome, outcome);
      expect(after.status, step.status);
      expect(recorded.status, run.status);
    }
  });

  test('test_finish_reporting_runner_steps_property_finished_event_lands', () {
    final Random random = seededRandom(88484);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = _startedRun(random);
      final DateTime at = randomPreciseMoment(random);
      final RunStep reporting = run.steps.first;

      final Run finished = _applyOne(run, const node.RunFinished(), at);

      for (final RunStep step in finished.steps) {
        if (step.runner == reporting.runner) {
          expect(step.status, StepStatus.done);
          expect(step.finishedAt, at);
        } else {
          expect(step.status, StepStatus.waiting);
        }
      }
      expect(finished.status, deriveRunStatus(finished.steps));
    }
  });

  test(
    'test_change_step_status_property_ended_runs_and_unknown_steps_refuse',
    () {
      final Random random = seededRandom(88485);

      for (int i = 0; i < propertyIterations; i += 1) {
        final Run run = randomProgressRun(random);
        final String stepName = randomStepNameOf(random, run);
        final bool isRefused = !canChangeRunStep(run, stepName);
        if (!isRefused) {
          continue;
        }

        final Run changed = _applyOne(
          run,
          buildStatusEvent(stepName, pickOne(random, StepStatus.values)),
          randomPreciseMoment(random),
        );

        expect(changed.status, run.status);
        expect(changed.finishedAt, run.finishedAt);
        expect(describeSteps(changed.steps), describeSteps(run.steps));
      }
    },
  );
}
