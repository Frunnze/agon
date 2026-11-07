import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_runs.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/rules/run_lifecycle.dart';

import '../../support/random_inputs.dart';

const int _mostSteps = 7;

const Set<StepStatus> _finishedStepStatuses = <StepStatus>{
  StepStatus.done,
  StepStatus.failed,
  StepStatus.skipped,
};

const List<StepStatus> _activeRunStepStatuses = <StepStatus>[
  StepStatus.waiting,
  StepStatus.running,
  StepStatus.waitingForApproval,
  StepStatus.waitingForPerson,
  StepStatus.done,
  StepStatus.skipped,
];

const List<RunStatus> _activeRunStatuses = <RunStatus>[
  RunStatus.queued,
  RunStatus.running,
  RunStatus.waitingForApproval,
];

DateTime? _randomOptionalMoment(Random random) {
  return random.nextBool() ? randomUtcMoment(random) : null;
}

RunStep _randomStep(Random random, int index) {
  final StepStatus status = pickOne(random, _activeRunStepStatuses);
  final bool isFinished = _finishedStepStatuses.contains(status);
  return RunStep(
    name: 'step-$index',
    agentId: WorkflowAgentId('agent-$index'),
    runner: random.nextBool() ? DeviceId('runner-$index') : null,
    status: status,
    startedAt: _randomOptionalMoment(random),
    finishedAt: isFinished ? randomUtcMoment(random) : null,
    result: random.nextBool() ? randomText(random) : null,
    outcome: random.nextBool() ? randomWordPhrase(random) : null,
    loopSource: null,
    earlierRounds: const <EarlierRound>[],
  );
}

Run _randomActiveRun(Random random) {
  final int stepCount = 1 + random.nextInt(_mostSteps);
  final List<RunStep> steps = <RunStep>[
    for (int index = 0; index < stepCount; index += 1)
      _randomStep(random, index),
  ];
  return galleryFailedRun.withProgress(
    nextStatus: pickOne(random, _activeRunStatuses),
    nextSteps: steps,
    nextFinishedAt: null,
  );
}

List<Object?> _describeStep(RunStep step) {
  return <Object?>[
    step.name,
    step.agentId,
    step.runner,
    step.status,
    step.startedAt,
    step.finishedAt,
    step.result,
    step.outcome,
    step.loopSource,
    step.earlierRounds.length,
  ];
}

void main() {
  test('test_build_cancelled_run_property_leaves_no_open_step', () {
    final Random random = seededRandom(7341);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = _randomActiveRun(random);
      final Run cancelled = buildCancelledRun(run, randomUtcMoment(random));

      for (final RunStep step in cancelled.steps) {
        expect(_finishedStepStatuses, contains(step.status));
      }
      expect(cancelled.steps.length, run.steps.length);
    }
  });

  test('test_skip_step_property_records_the_cancel_time', () {
    final Random random = seededRandom(7342);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = _randomActiveRun(random);
      final DateTime at = randomUtcMoment(random);
      final Run cancelled = buildCancelledRun(run, at);

      expect(cancelled.finishedAt, at);
      for (int index = 0; index < run.steps.length; index += 1) {
        final RunStep before = run.steps[index];
        final RunStep after = cancelled.steps[index];
        if (!_finishedStepStatuses.contains(before.status)) {
          expect(after.status, StepStatus.skipped);
          expect(after.finishedAt, at);
        }
      }
    }
  });

  test('test_build_cancelled_run_property_keeps_finished_steps', () {
    final Random random = seededRandom(7343);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = _randomActiveRun(random);
      final Run cancelled = buildCancelledRun(run, randomUtcMoment(random));

      for (int index = 0; index < run.steps.length; index += 1) {
        final RunStep before = run.steps[index];
        if (_finishedStepStatuses.contains(before.status)) {
          final RunStep after = cancelled.steps[index];
          expect(_describeStep(after), _describeStep(before));
        }
      }
    }
  });

  test('test_skip_step_property_keeps_what_the_step_did', () {
    final Random random = seededRandom(7344);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = _randomActiveRun(random);
      final Run cancelled = buildCancelledRun(run, randomUtcMoment(random));

      for (int index = 0; index < run.steps.length; index += 1) {
        final RunStep before = run.steps[index];
        final RunStep after = cancelled.steps[index];
        expect(after.runner, before.runner);
        expect(after.startedAt, before.startedAt);
        expect(after.result, before.result);
        expect(after.outcome, before.outcome);
      }
    }
  });

  test('test_skip_step_property_keeps_the_step_identity', () {
    final Random random = seededRandom(7345);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = _randomActiveRun(random);
      final Run cancelled = buildCancelledRun(run, randomUtcMoment(random));

      for (int index = 0; index < run.steps.length; index += 1) {
        final RunStep before = run.steps[index];
        final RunStep after = cancelled.steps[index];
        expect(after.name, before.name);
        expect(after.agentId, before.agentId);
        expect(after.loopSource, before.loopSource);
        expect(after.earlierRounds, before.earlierRounds);
      }
    }
  });

  test('test_gallery_failed_run_property_skipped_steps_record_their_end', () {
    for (final RunStep step in galleryFailedRun.steps) {
      if (step.status == StepStatus.skipped) {
        expect(step.finishedAt, isNotNull);
      }
    }
    expect(galleryFailedRun.finishedAt, isNotNull);
  });
}
