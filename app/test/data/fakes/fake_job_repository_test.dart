import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/gallery/gallery_tasks.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../support/random_inputs.dart';
import '../../support/sample_records.dart';
import '../../support/task_repositories.dart';

FakeJobRepository buildJobRepository(FakeTaskRepository taskRepository) {
  return FakeJobRepository(
    taskRepository: taskRepository,
    clock: FixedClock(galleryNow),
  );
}

FakeJobRepository buildGalleryJobRepository() {
  return buildJobRepository(buildGalleryTaskRepository());
}

JobDraft randomJobDraft(Random random) {
  return JobDraft(
    task: randomTaskDraft(random),
    schedule: randomJobSchedule(random),
  );
}

void main() {
  test('test_list_jobs_property_every_job_has_a_schedule', () async {
    final Random random = seededRandom(201);
    final FakeJobRepository repository = buildGalleryJobRepository();

    for (int i = 0; i < propertyIterations; i += 1) {
      await repository.createJob(randomJobDraft(random));
      final List<Task> jobs = repository.listJobs();

      expect(jobs.every((Task job) => job.schedule != null), isTrue);
      expect(jobs.map((Task job) => job.id).toSet().length, jobs.length);
    }
  });

  test('test_find_job_property_finds_every_listed_job', () async {
    final Random random = seededRandom(202);
    final FakeTaskRepository taskRepository = buildGalleryTaskRepository();
    final FakeJobRepository repository = buildJobRepository(taskRepository);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Task job = pickOne(random, repository.listJobs());
      final Task task = pickOne(random, taskRepository.listTasks());

      expect(repository.findJob(job.id).title, job.title);
      expect(
        () => repository.findJob(task.id),
        throwsA(isA<RecordNotFound>()),
      );
    }
    expect(
      () => repository.findJob(const TaskId('missing')),
      throwsA(isA<RecordNotFound>()),
    );
  });

  test('test_create_job_property_new_job_listed_first', () async {
    final Random random = seededRandom(203);
    final FakeJobRepository repository = buildGalleryJobRepository();

    for (int i = 0; i < propertyIterations; i += 1) {
      final JobDraft draft = randomJobDraft(random);
      final Task job = await repository.createJob(draft);

      expect(repository.listJobs().first.id, job.id);
      expect(job.schedule, same(draft.schedule));
      expect(job.status, TaskStatus.toDo);
    }
  });

  test('test_update_job_property_keeps_identity', () async {
    final Random random = seededRandom(204);
    final FakeJobRepository repository = buildGalleryJobRepository();

    for (int i = 0; i < propertyIterations; i += 1) {
      final Task before = pickOne(random, repository.listJobs());
      final JobDraft draft = randomJobDraft(random);
      final Task after = await repository.updateJob(before.id, draft);

      expect(after.id, before.id);
      expect(after.status, before.status);
      expect(after.title, draft.task.title);
      expect(repository.listJobs().length, galleryJobs.length);
    }
  });

  test('test_update_job_property_turns_a_task_into_that_job', () async {
    final Random random = seededRandom(205);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeTaskRepository taskRepository = buildGalleryTaskRepository();
      final FakeJobRepository repository = buildJobRepository(taskRepository);
      final Task task = pickOne(random, taskRepository.listTasks());
      final int taskCount = taskRepository.listTasks().length;
      final JobDraft draft = randomJobDraft(random);

      final Task job = await repository.updateJob(task.id, draft);

      expect(job.id, task.id);
      expect(job.createdAt, task.createdAt);
      expect(job.status, task.status);
      expect(job.schedule, same(draft.schedule));
      expect(repository.findJob(task.id).title, draft.task.title);
      expect(repository.listJobs().length, galleryJobs.length + 1);
      expect(taskRepository.listTasks().length, taskCount - 1);
      expect(taskRepository.findTask(task.id).schedule, same(draft.schedule));
    }
  });

  test('test_update_job_property_fuzz_unknown_ids_rejected', () async {
    final Random random = seededRandom(206);
    final FakeJobRepository repository = buildGalleryJobRepository();

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskId unknown = TaskId('unknown-${randomText(random)}');

      await expectLater(
        repository.updateJob(unknown, randomJobDraft(random)),
        throwsA(isA<RecordNotFound>()),
      );
      expect(repository.listJobs().length, galleryJobs.length);
    }
  });
}
