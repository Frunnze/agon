import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/gallery/gallery_runs.dart';
import 'package:agent_orchestration/data/gallery/gallery_tasks.dart';
import 'package:agent_orchestration/data/gallery/gallery_workflows.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/data/rules/run_lifecycle.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/presentation/doer_text.dart';
import 'package:agent_orchestration/presentation/run_text.dart';
import 'package:agent_orchestration/presentation/runner_target_text.dart';
import 'package:agent_orchestration/presentation/step_text.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';

import '../support/random_inputs.dart';
import '../support/sample_records.dart';

String joinSegments(List<TextSegment> segments) {
  return segments.map((TextSegment segment) => segment.text).join();
}

Run randomRunWithStatuses(Random random) {
  final Run base = pickOne(random, galleryRuns);
  final List<RunStep> steps = <RunStep>[
    for (final RunStep step in base.steps)
      step.withStatus(pickOne(random, StepStatus.values)),
  ];

  return base.withProgress(
    nextStatus: pickOne(random, RunStatus.values),
    nextSteps: steps,
    nextFinishedAt: random.nextBool() ? galleryNow : null,
  );
}

void main() {
  final DeviceNames deviceNames = DeviceNames(galleryDevices);

  test('test_name_of_property_known_ids_resolve_unknown_ids_fail', () {
    final Random random = seededRandom(4001);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Device device = pickOne(random, galleryDevices);
      expect(deviceNames.nameOf(device.id), device.name);
      expect(
        () => deviceNames.nameOf(DeviceId('x${randomText(random)}')),
        throwsA(isA<RecordNotFound>()),
      );
    }
  });

  test('test_describe_doer_property_names_agent_or_workflow', () {
    final Random random = seededRandom(4002);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskDoer doer = randomTaskDoer(random);
      final String label = describeDoer(doer, galleryWorkflows);
      final Workflow? workflow = findWorkflowForDoer(doer, galleryWorkflows);

      if (doer is OneAgentDoer) {
        expect(label, doer.agent.label);
        expect(workflow, isNull);
      } else {
        expect(label, 'workflow ${workflow!.name}');
      }
    }
  });

  test('test_find_workflow_for_doer_property_unknown_workflows_fail', () {
    final Random random = seededRandom(4003);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkflowDoer doer = WorkflowDoer(
        WorkflowId('missing-${randomText(random)}'),
      );
      expect(
        () => findWorkflowForDoer(doer, galleryWorkflows),
        throwsA(isA<RecordNotFound>()),
      );
    }
  });

  test('test_find_current_step_property_returns_a_step_of_the_run', () {
    final Random random = seededRandom(4004);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = randomRunWithStatuses(random);
      final RunStep current = findCurrentStep(run);
      final bool hasActiveStep = run.steps.any(
        (RunStep step) =>
            step.status == StepStatus.running ||
            step.status == StepStatus.failed ||
            step.status == StepStatus.waitingForApproval,
      );

      expect(run.steps.contains(current), isTrue);
      if (hasActiveStep) {
        expect(current.status, isNot(StepStatus.done));
      }
    }
  });

  test('test_describe_step_progress_property_position_within_bounds', () {
    final Random random = seededRandom(4005);
    final RegExp progressPattern = RegExp(r'^step (\d+) of (\d+)$');

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = randomRunWithStatuses(random);
      final String? progress = describeStepProgress(run);
      final bool shows = isRunActive(run) || run.status == RunStatus.failed;

      if (!shows || run.steps.length < 2) {
        expect(progress, isNull);
      } else {
        final RegExpMatch match = progressPattern.firstMatch(progress!)!;
        final int position = int.parse(match.group(1)!);
        expect(position >= 1 && position <= run.steps.length, isTrue);
      }
    }
  });

  test('test_describe_run_label_property_ends_with_run_number', () {
    final Random random = seededRandom(4006);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = pickOne(random, galleryRuns);
      final Task task = pickOne(random, galleryTasks);
      final Workflow? workflow = random.nextBool()
          ? pickOne(random, galleryWorkflows)
          : null;
      final String label = describeRunLabel(
        task: task,
        workflow: workflow,
        run: run,
      );

      expect(label, endsWith(' #${run.number}'));
      expect(label, startsWith(workflow?.name ?? task.title));
    }
  });

  test('test_describe_run_timing_property_started_or_stopped_phrase', () {
    final Random random = seededRandom(4007);
    final RegExp timingPattern = RegExp(
      r'^(started .+|(stopped|finished) (at \d{2}:\d{2}|yesterday at '
      r'\d{2}:\d{2}|\d+ days ago))$',
    );

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = randomRunWithStatuses(random);
      final DateTime now = galleryNow.add(
        Duration(minutes: random.nextInt(60 * 24 * 5)),
      );
      final String timing = describeRunTiming(run, now);

      expect(timingPattern.hasMatch(timing), isTrue, reason: timing);
    }
  });

  test('test_describe_runner_target_property_names_the_target', () {
    final Random random = seededRandom(4008);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RunnerTarget target = randomRunnerTarget(random);
      final String text = joinSegments(
        describeRunnerTarget(target, deviceNames),
      );

      switch (target) {
        case AnyFreeRunner():
          expect(text, 'Any runner');
        case SpecificRunner():
          expect(text, deviceNames.nameOf(target.deviceId));
        case RunnerWithLabels():
          expect(text, 'Any runner with ${target.labels.join(', ')}');
      }
    }
  });

  test('test_describe_step_subtitle_property_matches_step_status', () {
    final Random random = seededRandom(4009);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = randomRunWithStatuses(random);
      final RunStep step = pickOne(random, run.steps);
      final String text = joinSegments(
        describeStepSubtitle(
          step: step,
          target: randomRunnerTarget(random),
          deviceNames: deviceNames,
          now: galleryNow,
        ),
      );

      expect(text, isNotEmpty);
      if (step.status == StepStatus.skipped) {
        expect(text, 'Did not start');
      }
      if (step.status == StepStatus.running) {
        expect(text, endsWith(' so far'));
      }
    }
  });
}
