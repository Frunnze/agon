import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_runs.dart';
import 'package:agent_orchestration/data/gallery/gallery_tasks.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/data/rules/run_lifecycle.dart';

import '../../support/random_inputs.dart';
import '../../support/sample_records.dart';
import '../../support/task_repositories.dart';
import '../../support/workflow_repositories.dart';
import 'support/startable_drafts.dart';
import 'support/task_inputs.dart';

TaskDraft _randomStartableDraft(Random random) {
  return randomStartableTaskDraft(random, buildGalleryWorkflowRepository());
}

Future<void> applyRandomTaskOperation(
  FakeTaskRepository repository,
  Random random,
) async {
  final List<Task> tasks = repository.listTasks();
  final Task task = pickOne(random, tasks);
  final List<Run> runs = repository.listRuns(task.id);

  switch (random.nextInt(4)) {
    case 0:
      await repository.createTask(randomTaskDraft(random));
    case 1:
      await repository.updateTask(task.id, randomTaskDraft(random));
    case 2:
      if (runs.isNotEmpty && isRunActive(runs.first)) {
        await repository.cancelRun(runs.first.id);
      } else if (canStartDoer(buildGalleryWorkflowRepository(), task.doer)) {
        await repository.startTask(task.id);
      }
    default:
      if (runs.isNotEmpty && !isRunActive(runs.first)) {
        final RunStatus status = runs.first.status;
        if (status == RunStatus.failed || status == RunStatus.cancelled) {
          await repository.retryRun(runs.first.id);
        }
      }
  }
}

void expectTaskInvariants(FakeTaskRepository repository) {
  final List<Task> tasks = repository.listTasks();
  final Set<TaskId> taskIds = tasks.map((Task task) => task.id).toSet();
  expect(taskIds.length, tasks.length);

  for (final Task task in tasks) {
    expect(task.schedule, isNull);
    final List<Run> runs = repository.listRuns(task.id);
    expect(runs.where(isRunActive).length <= 1, isTrue);
    for (int index = 1; index < runs.length; index += 1) {
      expect(runs[index - 1].number > runs[index].number, isTrue);
    }
    if (runs.isNotEmpty && isRunActive(runs.first)) {
      expect(task.status, TaskStatus.running);
    }
  }
}

void main() {
  test(
    'test_list_tasks_property_ids_stay_unique_after_any_sequence',
    () async {
      final Random random = seededRandom(101);

      for (int i = 0; i < propertyIterations ~/ 4; i += 1) {
        final FakeTaskRepository repository = buildGalleryTaskRepository();
        for (int step = 0; step < 12; step += 1) {
          await applyRandomTaskOperation(repository, random);
          expectTaskInvariants(repository);
        }
      }
    },
  );

  test('test_find_task_property_finds_every_listed_task', () async {
    final Random random = seededRandom(102);
    final FakeTaskRepository repository = buildGalleryTaskRepository();

    for (int i = 0; i < propertyIterations; i += 1) {
      await applyRandomTaskOperation(repository, random);
      final Task listed = pickOne(random, repository.listTasks());
      expect(repository.findTask(listed.id).title, listed.title);
    }
    expect(
      () => repository.findTask(const TaskId('missing')),
      throwsA(isA<RecordNotFound>()),
    );
  });

  test('test_find_task_property_finds_every_job_and_starts_it', () async {
    final Random random = seededRandom(108);
    final FakeTaskRepository repository = buildGalleryTaskRepository();

    for (int i = 0; i < propertyIterations; i += 1) {
      final Task job = pickOne(random, galleryJobs);
      expect(repository.findTask(job.id).schedule, job.schedule);
    }
    final Task startedJob = pickOne(random, galleryJobs);
    final Run run = await repository.startTask(startedJob.id);
    expect(run.taskId, startedJob.id);
    expect(repository.listRuns(startedJob.id), <Run>[run]);
  });

  test('test_list_runs_property_only_runs_of_that_task', () async {
    final Random random = seededRandom(103);
    final FakeTaskRepository repository = buildGalleryTaskRepository();

    for (int i = 0; i < propertyIterations; i += 1) {
      await applyRandomTaskOperation(repository, random);
      final Task task = pickOne(random, repository.listTasks());
      for (final Run run in repository.listRuns(task.id)) {
        expect(run.taskId, task.id);
      }
    }
  });

  test('test_find_run_property_finds_every_listed_run', () async {
    final Random random = seededRandom(104);
    final FakeTaskRepository repository = buildGalleryTaskRepository();

    for (int i = 0; i < propertyIterations; i += 1) {
      await applyRandomTaskOperation(repository, random);
      final Task task = pickOne(random, repository.listTasks());
      for (final Run run in repository.listRuns(task.id)) {
        expect(repository.findRun(run.id).number, run.number);
      }
    }
    expect(
      () => repository.findRun(const RunId('missing')),
      throwsA(isA<RecordNotFound>()),
    );
  });

  test('test_create_task_property_new_task_first_and_to_do', () async {
    final Random random = seededRandom(105);
    final FakeTaskRepository repository = buildGalleryTaskRepository();

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskDraft draft = randomTaskDraft(random);
      final Task created = await repository.createTask(draft);

      expect(repository.listTasks().first.id, created.id);
      expect(created.status, TaskStatus.toDo);
      expect(created.title, draft.title);
      expect(created.schedule, isNull);
    }
  });

  test('test_update_task_property_keeps_identity_and_status', () async {
    final Random random = seededRandom(106);
    final FakeTaskRepository repository = buildGalleryTaskRepository();

    for (int i = 0; i < propertyIterations; i += 1) {
      final Task before = pickOne(random, repository.listTasks());
      final TaskDraft draft = randomTaskDraft(random);
      final Task after = await repository.updateTask(before.id, draft);

      expect(after.id, before.id);
      expect(after.status, before.status);
      expect(after.createdAt, before.createdAt);
      expect(after.details, draft.details);
      expect(repository.listTasks().length, galleryTasks.length);
    }
  });

  test('test_start_task_property_branch_and_first_step_running', () async {
    final Random random = seededRandom(107);

    for (int i = 0; i < propertyIterations ~/ 4; i += 1) {
      final FakeTaskRepository repository = buildGalleryTaskRepository();
      final Task task = await repository.createTask(
        _randomStartableDraft(random),
      );
      final Run run = await repository.startTask(task.id);

      expect(run.status, RunStatus.running);
      expect(run.steps.first.status, StepStatus.running);
      expect(run.worktreeBranch, startsWith('task/'));
      expect(run.log.first.text, startsWith('Created worktree task/'));
      expect(repository.findTask(task.id).status, TaskStatus.running);
      await expectLater(
        repository.startTask(task.id),
        throwsA(isA<StateError>()),
      );
    }
  });

  test('test_cancel_run_property_leaves_no_active_step', () async {
    final Random random = seededRandom(108);

    for (int i = 0; i < propertyIterations ~/ 4; i += 1) {
      final FakeTaskRepository repository = buildGalleryTaskRepository();
      final Task task = await repository.createTask(
        _randomStartableDraft(random),
      );
      final Run started = await repository.startTask(task.id);
      final Run cancelled = await repository.cancelRun(started.id);

      expect(cancelled.status, RunStatus.cancelled);
      expect(
        cancelled.steps.every(
          (RunStep step) =>
              step.status == StepStatus.done ||
              step.status == StepStatus.skipped,
        ),
        isTrue,
      );
      expect(repository.findTask(task.id).status, TaskStatus.toDo);
      await expectLater(
        repository.cancelRun(started.id),
        throwsA(isA<StateError>()),
      );
    }
  });

  test(
    'test_retry_run_property_reuses_worktree_and_keeps_done_steps',
    () async {
      final FakeTaskRepository repository = buildGalleryTaskRepository();
      final Run retried = await repository.retryRun(GalleryRunIds.release41);
      final Random random = seededRandom(109);

      expect(retried.worktreeBranch, galleryFailedRun.worktreeBranch);
      expect(retried.steps.first.status, StepStatus.done);
      expect(retried.steps[1].status, StepStatus.running);
      expect(retried.id, galleryFailedRun.id);
      expect(retried.number, galleryFailedRun.number);
      for (int i = 0; i < propertyIterations ~/ 4; i += 1) {
        final Run anyRun = pickOne(random, galleryRuns);
        if (anyRun.status != RunStatus.failed) {
          await expectLater(
            buildGalleryTaskRepository().retryRun(anyRun.id),
            throwsA(isA<StateError>()),
          );
        }
      }
    },
  );
}
