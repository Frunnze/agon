import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/gallery/gallery_runs.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/rules/run_lifecycle.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/presentation/step_text.dart';
import 'package:agent_orchestration/presentation/time_phrases.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';

import '../support/random_inputs.dart';
import '../support/sample_records.dart';

const String _notStartedText = 'Did not start';
const String _stoppedTextStart = 'Stopped after ';
const int _longestStepSeconds = 4 * 60 * 60;

final DeviceNames _deviceNames = DeviceNames(galleryDevices);
final List<RunStep> _galleryStepTemplates = <RunStep>[
  for (final Run run in galleryRuns) ...run.steps,
];

String _joinSegments(List<TextSegment> segments) {
  return segments.map((TextSegment segment) => segment.text).join();
}

Duration _randomStepLength(Random random) {
  return Duration(seconds: random.nextInt(_longestStepSeconds));
}

RunStep _rebuildStep({
  required RunStep template,
  required StepStatus status,
  required DateTime? startedAt,
  required DateTime? finishedAt,
}) {
  return RunStep(
    name: template.name,
    agentId: template.agentId,
    runner: template.runner,
    status: status,
    startedAt: startedAt,
    finishedAt: finishedAt,
    result: template.result,
    outcome: template.outcome,
    loopSource: template.loopSource,
    earlierRounds: template.earlierRounds,
  );
}

RunStep _randomSkippedStep(Random random) {
  final DateTime startedAt = galleryNow.subtract(_randomStepLength(random));
  final bool hasStarted = random.nextBool();

  return _rebuildStep(
    template: pickOne(random, _galleryStepTemplates),
    status: StepStatus.skipped,
    startedAt: hasStarted ? startedAt : null,
    finishedAt: random.nextBool() ? galleryNow : null,
  );
}

String _describeAgentStep(Random random, RunStep step) {
  return _joinSegments(
    describeStepSubtitle(
      step: step,
      target: randomRunnerTarget(random),
      deviceNames: _deviceNames,
      now: galleryNow,
    ),
  );
}

String _describePersonStep(RunStep step) {
  return _joinSegments(
    describePersonStepSubtitle(step: step, now: galleryNow),
  );
}

Run _randomCancelledRun(Random random) {
  final Run base = pickOne(random, galleryRuns);
  final List<RunStep> steps = <RunStep>[
    for (final RunStep template in base.steps)
      _rebuildStep(
        template: template,
        status: pickOne(random, StepStatus.values),
        startedAt: random.nextBool()
            ? galleryNow.subtract(_randomStepLength(random))
            : null,
        finishedAt: null,
      ),
  ];
  final Run active = base.withProgress(
    nextStatus: RunStatus.running,
    nextSteps: steps,
    nextFinishedAt: null,
  );

  return buildCancelledRun(active, galleryNow);
}

void main() {
  test('test_describe_skipped_step_property_started_step_says_stopped', () {
    final Random random = seededRandom(7311);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Duration ranFor = _randomStepLength(random);
      final Duration stoppedAgo = _randomStepLength(random);
      final DateTime stoppedAt = galleryNow.subtract(stoppedAgo);
      final RunStep step = _rebuildStep(
        template: pickOne(random, _galleryStepTemplates),
        status: StepStatus.skipped,
        startedAt: stoppedAt.subtract(ranFor),
        finishedAt: stoppedAt,
      );
      final String took = describeStepDuration(ranFor);

      expect(_describeAgentStep(random, step), '$_stoppedTextStart$took');
      expect(_describePersonStep(step), '$_stoppedTextStart$took');
    }
  });

  test('test_describe_skipped_step_property_unstarted_step_did_not_start', () {
    final Random random = seededRandom(7312);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RunStep step = _rebuildStep(
        template: pickOne(random, _galleryStepTemplates),
        status: StepStatus.skipped,
        startedAt: null,
        finishedAt: random.nextBool() ? galleryNow : null,
      );

      expect(_describeAgentStep(random, step), _notStartedText);
      expect(_describePersonStep(step), _notStartedText);
    }
  });

  test('test_describe_skipped_step_property_open_step_is_measured_to_now', () {
    final Random random = seededRandom(7313);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Duration ranFor = _randomStepLength(random);
      final RunStep step = _rebuildStep(
        template: pickOne(random, _galleryStepTemplates),
        status: StepStatus.skipped,
        startedAt: galleryNow.subtract(ranFor),
        finishedAt: null,
      );
      final String took = describeStepDuration(ranFor);

      expect(_describeAgentStep(random, step), '$_stoppedTextStart$took');
      expect(_describePersonStep(step), '$_stoppedTextStart$took');
    }
  });

  test('test_describe_step_subtitle_property_cancel_keeps_started_honest', () {
    final Random random = seededRandom(7314);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run cancelled = _randomCancelledRun(random);

      for (final RunStep step in cancelled.steps) {
        final String text = _describeAgentStep(random, step);
        final bool hasStarted = step.startedAt != null;

        if (step.status == StepStatus.skipped) {
          expect(text == _notStartedText, !hasStarted);
          expect(text.startsWith(_stoppedTextStart), hasStarted);
        }
      }
    }
  });

  test('test_describe_step_subtitle_property_skipped_ignores_the_target', () {
    final Random random = seededRandom(7315);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RunStep step = _randomSkippedStep(random);

      expect(
        _describeAgentStep(random, step),
        _describeAgentStep(random, step),
      );
    }
  });

  test('test_describe_step_subtitle_property_skipped_claims_no_progress', () {
    final Random random = seededRandom(7316);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String text = _describeAgentStep(
        random,
        _randomSkippedStep(random),
      );

      expect(text, isNot(endsWith(' so far')));
      expect(text, isNot(contains('Waiting for a runner')));
    }
  });

  test('test_describe_person_step_subtitle_property_cancel_keeps_honest', () {
    final Random random = seededRandom(7317);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run cancelled = _randomCancelledRun(random);

      for (final RunStep step in cancelled.steps) {
        final String text = _describePersonStep(step);
        final bool hasStarted = step.startedAt != null;

        if (step.status == StepStatus.skipped) {
          expect(text == _notStartedText, !hasStarted);
          expect(text.startsWith(_stoppedTextStart), hasStarted);
        }
      }
    }
  });

  test(
    'test_describe_person_step_subtitle_property_skipped_matches_agent',
    () {
      final Random random = seededRandom(7318);

      for (int i = 0; i < propertyIterations; i += 1) {
        final RunStep step = _randomSkippedStep(random);

        expect(_describePersonStep(step), _describeAgentStep(random, step));
      }
    },
  );

  test('test_describe_person_step_subtitle_property_stopped_never_asks', () {
    final Random random = seededRandom(7319);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String text = _describePersonStep(_randomSkippedStep(random));

      expect(text, isNot(startsWith('Asked you ')));
      expect(text, isNot(startsWith('You · answered')));
    }
  });
}
