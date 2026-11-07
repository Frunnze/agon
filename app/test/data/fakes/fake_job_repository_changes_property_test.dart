import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../support/random_inputs.dart';
import '../../support/workflow_repositories.dart';
import 'support/job_inputs.dart';
import 'support/startable_drafts.dart';

const int _largestCreationCount = 6;
const int _collidingSeedCount = 3;

Task? _pickOne(Random random, List<Task> candidates) {
  if (candidates.isEmpty) {
    return null;
  }
  return pickOne(random, candidates);
}

Task? _pickJob(Random random, List<Task> records) {
  return _pickOne(random, <Task>[
    for (final Task record in records)
      if (record.schedule != null) record,
  ]);
}

Task? _pickPlainTask(Random random, List<Task> records) {
  return _pickOne(random, <Task>[
    for (final Task record in records)
      if (record.schedule == null) record,
  ]);
}

List<Task> _seedsNamedLikeCreatedJobs(Random random) {
  final List<Task> seeds = <Task>[];
  for (int number = 1; number <= _collidingSeedCount; number += 1) {
    seeds.add(randomStoredRecord(random, identifier: 'created-job-$number'));
  }
  return seeds;
}

void main() {
  test('test_create_job_property_keeps_the_draft_and_schedule', () async {
    final Random random = seededRandom(65001);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedJobs counted = buildCountedJobRepository(
        random,
        randomStoredRecords(random),
      );
      final JobDraft draft = randomJobDraft(random);

      final Task job = await counted.repository.createJob(draft);

      final Task expected = Task.fromDraft(
        id: job.id,
        draft: draft.task,
        schedule: draft.schedule,
        status: TaskStatus.toDo,
        createdAt: counted.moment,
      );
      expect(describeJobContent(job), describeJobContent(expected));
      expect(job.schedule, same(draft.schedule));
      expect(counted.repository.findJob(job.id), same(job));
      expect(counted.notifications.count, 1);
    }
  });

  test('test_create_job_property_never_replaces_an_existing_'
      'record', () async {
    final Random random = seededRandom(65002);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Task> seeds = _seedsNamedLikeCreatedJobs(random);
      final CountedJobs counted = buildCountedJobRepository(random, seeds);

      final Task job = await counted.repository.createJob(
        randomJobDraft(random),
      );

      for (final Task seed in seeds) {
        expect(job.id, isNot(seed.id));
        expect(counted.taskRepository.findTask(seed.id), same(seed));
      }
      expect(
        counted.taskRepository.listTasksAndJobs().length,
        seeds.length + 1,
      );
    }
  });

  test('test_create_job_property_every_creation_adds_one_new_job', () async {
    final Random random = seededRandom(65003);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedJobs counted = buildCountedJobRepository(
        random,
        randomStoredRecords(random),
      );
      final int jobCountBefore = counted.repository.listJobs().length;
      final int creationCount = 1 + random.nextInt(_largestCreationCount);
      final Set<TaskId> createdIds = <TaskId>{};

      for (int creation = 0; creation < creationCount; creation += 1) {
        final Task job = await counted.repository.createJob(
          randomJobDraft(random),
        );
        createdIds.add(job.id);
      }

      expect(createdIds.length, creationCount);
      expect(
        counted.repository.listJobs().length,
        jobCountBefore + creationCount,
      );
    }
  });

  test('test_update_job_property_keeps_identity_status_and_creation_'
      'time', () async {
    final Random random = seededRandom(65004);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Task> seeds = randomStoredRecords(random);
      final CountedJobs counted = buildCountedJobRepository(random, seeds);
      final Task? before = _pickJob(random, seeds);
      if (before == null) {
        continue;
      }
      final JobDraft draft = randomJobDraft(random);

      final Task after = await counted.repository.updateJob(before.id, draft);

      final Task expected = Task.fromDraft(
        id: before.id,
        draft: draft.task,
        schedule: draft.schedule,
        status: before.status,
        createdAt: before.createdAt,
      );
      expect(describeJobContent(after), describeJobContent(expected));
      expect(after.createdAt, before.createdAt);
      expect(
        describeTaskIds(counted.repository.listJobs()),
        describeTaskIds(<Task>[
          for (final Task seed in seeds)
            if (seed.schedule != null) seed,
        ]),
      );
    }
  });

  test('test_update_job_property_unknown_ids_are_refused_without_'
      'change', () async {
    final Random random = seededRandom(65005);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Task> seeds = randomStoredRecords(random);
      final CountedJobs counted = buildCountedJobRepository(random, seeds);

      await expectLater(
        counted.repository.updateJob(
          TaskId('unknown-${randomText(random)}'),
          randomJobDraft(random),
        ),
        throwsA(isA<RecordNotFound>()),
      );
      expect(counted.taskRepository.listTasksAndJobs(), orderedEquals(seeds));
      expect(counted.notifications.count, 0);
    }
  });

  test('test_update_job_property_repeating_an_update_changes_'
      'nothing_more', () async {
    final Random random = seededRandom(65006);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Task> seeds = randomStoredRecords(random);
      final CountedJobs counted = buildCountedJobRepository(random, seeds);
      final Task? job = _pickJob(random, seeds);
      if (job == null) {
        continue;
      }
      final JobDraft draft = randomJobDraft(random);

      final Task first = await counted.repository.updateJob(job.id, draft);
      final List<String> idsAfterFirst = describeTaskIds(
        counted.repository.listJobs(),
      );
      final Task second = await counted.repository.updateJob(job.id, draft);

      expect(describeJobContent(second), describeJobContent(first));
      expect(describeTaskIds(counted.repository.listJobs()), idsAfterFirst);
    }
  });

  test('test_delete_job_property_removes_only_that_job', () async {
    final Random random = seededRandom(65007);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Task> seeds = randomStoredRecords(random);
      final CountedJobs counted = buildCountedJobRepository(random, seeds);
      final Task? job = _pickJob(random, seeds);
      if (job == null) {
        continue;
      }

      await counted.repository.deleteJob(job.id);

      expect(
        describeTaskIds(counted.taskRepository.listTasksAndJobs()),
        describeTaskIds(<Task>[
          for (final Task seed in seeds)
            if (seed.id != job.id) seed,
        ]),
      );
      expect(counted.notifications.count, 1);
    }
  });

  test('test_delete_job_property_plain_tasks_and_unknown_ids_are_'
      'refused', () async {
    final Random random = seededRandom(65008);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Task> seeds = randomStoredRecords(random);
      final CountedJobs counted = buildCountedJobRepository(random, seeds);
      final Task? task = _pickPlainTask(random, seeds);
      final TaskId refusedId = task == null
          ? TaskId('unknown-${randomText(random)}')
          : task.id;

      await expectLater(
        counted.repository.deleteJob(refusedId),
        throwsA(isA<RecordNotFound>()),
      );
      expect(counted.taskRepository.listTasksAndJobs(), orderedEquals(seeds));
      expect(counted.notifications.count, 0);
    }
  });

  test('test_delete_job_property_running_jobs_are_refused_and_'
      'kept', () async {
    final Random random = seededRandom(65009);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedJobs counted = buildCountedJobRepository(
        random,
        randomStoredRecords(random),
      );
      final Task job = await counted.repository.createJob(
        randomStartableJobDraft(random, buildGalleryWorkflowRepository()),
      );
      await counted.taskRepository.startTask(job.id);

      await expectLater(
        counted.repository.deleteJob(job.id),
        throwsStateError,
      );
      expect(counted.repository.findJob(job.id).status, TaskStatus.running);
    }
  });
}
