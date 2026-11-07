import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/gallery/gallery_runs.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';

import 'support/gallery_records.dart';
import 'support/node_run_rules.dart';

void _expectStepMomentsFitItsStatus(RunStep step) {
  final DateTime? startedAt = step.startedAt;
  final DateTime? finishedAt = step.finishedAt;

  switch (step.status) {
    case StepStatus.waiting:
      expect(startedAt, isNull, reason: step.name);
      expect(finishedAt, isNull, reason: step.name);
    case StepStatus.running ||
        StepStatus.waitingForApproval ||
        StepStatus.waitingForPerson:
      expect(startedAt, isNotNull, reason: step.name);
      expect(finishedAt, isNull, reason: step.name);
    case StepStatus.done || StepStatus.failed:
      expect(startedAt, isNotNull, reason: step.name);
      expect(finishedAt, isNotNull, reason: step.name);
    case StepStatus.skipped:
      expect(finishedAt, isNotNull, reason: step.name);
  }
  if (startedAt != null && finishedAt != null) {
    expect(finishedAt.isBefore(startedAt), isFalse, reason: step.name);
  }
}

void main() {
  test('test_gallery_runs_property_ids_are_unique_and_tasks_exist', () {
    final List<RunId> identifiers = <RunId>[
      for (final Run run in galleryRuns) run.id,
    ];
    final List<String> taskRunNumbers = <String>[
      for (final Run run in galleryRuns) '${run.taskId.value} ${run.number}',
    ];

    expect(hasNoRepeats(identifiers), isTrue);
    expect(hasNoRepeats(taskRunNumbers), isTrue);
    for (final Run run in galleryRuns) {
      findGalleryWork(run.taskId);
      expect(run.number, greaterThanOrEqualTo(1));
      expect(run.steps, isNotEmpty);
    }
  });

  test('test_gallery_runs_property_status_follows_the_steps', () {
    for (final Run run in galleryRuns) {
      if (run.status == RunStatus.cancelled) {
        continue;
      }
      expect(deriveNodeRunStatus(run.steps), run.status, reason: run.id.value);
    }
  });

  test('test_gallery_runs_property_finished_runs_leave_no_open_step', () {
    for (final Run run in galleryRuns) {
      final bool isFinished = finishedRunStatuses.contains(run.status);
      final DateTime? finishedAt = run.finishedAt;

      expect(finishedAt != null, isFinished, reason: run.id.value);
      if (finishedAt == null) {
        continue;
      }
      expect(finishedAt.isBefore(run.startedAt), isFalse);
      for (final RunStep step in run.steps) {
        expect(finishedStepStatuses, contains(step.status), reason: step.name);
        expect(step.finishedAt, isNotNull, reason: step.name);
        expect(step.finishedAt!.isAfter(finishedAt), isFalse);
      }
    }
  });

  test('test_gallery_runs_property_step_moments_fit_their_status', () {
    for (final Run run in galleryRuns) {
      for (final RunStep step in run.steps) {
        _expectStepMomentsFitItsStatus(step);
        final DateTime? startedAt = step.startedAt;
        final bool isOpen = !finishedStepStatuses.contains(step.status);
        if (startedAt != null && isOpen) {
          expect(
            startedAt.isBefore(run.startedAt),
            isFalse,
            reason: step.name,
          );
        }
        if (startedAt != null) {
          expect(startedAt.isAfter(galleryNow), isFalse, reason: step.name);
        }
      }
    }
  });

  test('test_gallery_runs_property_failure_names_the_failed_step', () {
    for (final Run run in galleryRuns) {
      final RunFailure? failure = run.failure;
      expect(failure != null, run.status == RunStatus.failed);
      if (failure == null) {
        continue;
      }
      final RunStep failedStep = run.steps.singleWhere(
        (RunStep step) => step.name == failure.stepName,
      );

      expect(failedStep.status, StepStatus.failed);
      expect(failure.runner, failedStep.runner);
      expect(failure.reason.trim(), isNotEmpty);
    }
  });

  test('test_gallery_runs_property_task_status_follows_the_latest_run', () {
    for (final Task task in galleryWork) {
      final List<Run> runs = <Run>[
        for (final Run run in galleryRuns)
          if (run.taskId == task.id) run,
      ];
      if (runs.isEmpty) {
        continue;
      }
      runs.sort((Run first, Run second) => first.number - second.number);

      expect(task.status, findNodeTaskStatus(runs.last.status));
    }
  });

  test('test_gallery_runs_property_started_by_a_client_after_creation', () {
    for (final Run run in galleryRuns) {
      final Task task = findGalleryWork(run.taskId);
      final Device starter = findGalleryDevice(run.startedBy);

      expect(starter.role, isNot(DeviceRole.runner), reason: run.id.value);
      expect(run.startedAt.isBefore(task.createdAt), isFalse);
      expect(run.startedAt.isAfter(galleryNow), isFalse);
    }
  });
}
