import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/gallery/gallery_runs.dart';
import 'package:agent_orchestration/data/gallery/gallery_workflows.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/run_lifecycle.dart';
import 'package:agent_orchestration/data/rules/task_branch.dart';

import '../../support/random_inputs.dart';
import '../../support/sample_records.dart';

Task randomTask(Random random) {
  return Task.fromDraft(
    id: TaskId('task-${random.nextInt(1000)}'),
    draft: randomTaskDraft(random),
    schedule: random.nextBool() ? randomJobSchedule(random) : null,
    status: TaskStatus.toDo,
    createdAt: galleryNow,
  );
}

Run createRandomRun(Random random) {
  final Task task = randomTask(random);
  final Workflow? workflow = task.doer is WorkflowDoer
      ? pickOne(random, galleryWorkflows)
      : null;

  return createRun(
    runId: RunId('run-${random.nextInt(1000)}'),
    task: task,
    workflow: workflow,
    number: 1 + random.nextInt(500),
    startedBy: GalleryDeviceIds.airLaptop,
    at: galleryNow,
  );
}

void main() {
  test('test_create_run_property_exactly_one_running_step', () {
    final Random random = seededRandom(1001);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = createRandomRun(random);
      final int runningSteps = run.steps
          .where((RunStep step) => step.status == StepStatus.running)
          .length;

      expect(runningSteps, 1);
      expect(run.steps.first.status, StepStatus.running);
      expect(isRunActive(run), isTrue);
      expect(
        run.log.single.text,
        'Created worktree ${run.worktreeBranch} '
        'from main',
      );
    }
  });

  test('test_describe_run_branch_property_jobs_get_a_run_suffix', () {
    final Random random = seededRandom(1002);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Task task = randomTask(random);
      final int number = 1 + random.nextInt(500);
      final String branch = describeRunBranch(task, number);

      if (task.schedule == null) {
        expect(branch, describeTaskBranch(task.title));
      } else {
        expect(branch, describeJobRunBranch(task.title, number));
      }
    }
  });

  test('test_is_run_active_property_matches_status_set', () {
    final Random random = seededRandom(1003);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = createRandomRun(random);
      final RunStatus status = pickOne(random, RunStatus.values);
      final Run changed = run.withProgress(
        nextStatus: status,
        nextSteps: run.steps,
        nextFinishedAt: null,
      );
      final bool expectedActive =
          status == RunStatus.queued ||
          status == RunStatus.running ||
          status == RunStatus.waitingForApproval;

      expect(isRunActive(changed), expectedActive);
    }
  });

  test('test_build_cancelled_run_property_only_active_runs_cancel', () {
    final Random random = seededRandom(1004);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = createRandomRun(random);
      final Run cancelled = buildCancelledRun(run, galleryNow);

      expect(cancelled.status, RunStatus.cancelled);
      expect(cancelled.finishedAt, galleryNow);
      expect(() => buildCancelledRun(cancelled, galleryNow), throwsStateError);
    }
  });

  test('test_build_retried_run_property_keeps_branch_and_done_steps', () {
    final Random random = seededRandom(1005);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run failed = random.nextBool()
          ? galleryFailedRun
          : buildCancelledRun(createRandomRun(random), galleryNow);
      final Run retried = buildRetriedRun(failed, galleryNow);

      expect(retried.worktreeBranch, failed.worktreeBranch);
      expect(retried.status, RunStatus.running);
      for (int index = 0; index < failed.steps.length; index += 1) {
        if (failed.steps[index].status == StepStatus.done) {
          expect(retried.steps[index].status, StepStatus.done);
        }
      }
      expect(() => buildRetriedRun(retried, galleryNow), throwsStateError);
    }
  });
}
