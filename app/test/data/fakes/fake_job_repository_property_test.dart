import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../support/random_inputs.dart';
import 'support/job_inputs.dart';

const int _largestCreationCount = 5;

List<Task> _scheduledRecords(List<Task> records) {
  return <Task>[
    for (final Task record in records)
      if (record.schedule != null) record,
  ];
}

void main() {
  test(
    'test_fake_job_repository_new_property_lists_only_the_scheduled_records',
    () {
      final Random random = seededRandom(64901);

      for (int i = 0; i < propertyIterations; i += 1) {
        final List<Task> records = randomStoredRecords(random);
        final CountedJobs counted = buildCountedJobRepository(random, records);

        expect(
          describeTaskIds(counted.repository.listJobs()),
          describeTaskIds(_scheduledRecords(records)),
        );
      }
    },
  );

  test('test_fake_job_repository_new_property_two_repositories_over_one_task_'
      'repository_never_share_an_id', () async {
    final Random random = seededRandom(64902);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedJobs counted = buildCountedJobRepository(
        random,
        randomStoredRecords(random),
      );
      final FakeJobRepository second = FakeJobRepository(
        taskRepository: counted.taskRepository,
        clock: FixedClock(counted.moment),
      );
      final int jobCountBefore = counted.repository.listJobs().length;

      final Task first = await counted.repository.createJob(
        randomJobDraft(random),
      );
      final Task other = await second.createJob(randomJobDraft(random));

      expect(other.id, isNot(first.id));
      expect(counted.repository.listJobs().length, jobCountBefore + 2);
    }
  });

  test(
    'test_fake_job_repository_new_property_stamps_new_jobs_with_its_clock',
    () async {
      final Random random = seededRandom(64903);

      for (int i = 0; i < propertyIterations; i += 1) {
        final CountedJobs counted = buildCountedJobRepository(
          random,
          randomStoredRecords(random),
        );

        final Task job = await counted.repository.createJob(
          randomJobDraft(random),
        );

        expect(job.createdAt, counted.moment);
      }
    },
  );

  test('test_list_jobs_property_follows_the_task_repository_order', () async {
    final Random random = seededRandom(64910);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedJobs counted = buildCountedJobRepository(
        random,
        randomStoredRecords(random),
      );
      final int changeCount = random.nextInt(_largestCreationCount);
      for (int change = 0; change < changeCount; change += 1) {
        await changeRandomJobValidly(random, counted);
      }

      expect(
        describeTaskIds(counted.repository.listJobs()),
        describeTaskIds(
          _scheduledRecords(counted.taskRepository.listTasksAndJobs()),
        ),
      );
    }
  });

  test('test_list_jobs_property_is_unmodifiable', () async {
    final Random random = seededRandom(64911);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedJobs counted = buildCountedJobRepository(
        random,
        randomStoredRecords(random),
      );
      final Task job = await counted.repository.createJob(
        randomJobDraft(random),
      );
      final List<Task> jobs = counted.repository.listJobs();

      expect(() => jobs.add(job), throwsUnsupportedError);
    }
  });

  test('test_list_jobs_property_never_lists_a_plain_task', () async {
    final Random random = seededRandom(64912);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedJobs counted = buildCountedJobRepository(
        random,
        randomStoredRecords(random),
      );
      final int changeCount = random.nextInt(_largestCreationCount);
      for (int change = 0; change < changeCount; change += 1) {
        await changeRandomJobValidly(random, counted);
      }

      final Set<String> plainTaskIds = describeTaskIds(
        counted.taskRepository.listTasks(),
      ).toSet();
      for (final Task job in counted.repository.listJobs()) {
        expect(job.schedule, isNotNull);
        expect(plainTaskIds, isNot(contains(job.id.value)));
      }
    }
  });

  test('test_find_job_property_finds_every_listed_job', () async {
    final Random random = seededRandom(64913);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedJobs counted = buildCountedJobRepository(
        random,
        randomStoredRecords(random),
      );
      await counted.repository.createJob(randomJobDraft(random));

      for (final Task job in counted.repository.listJobs()) {
        expect(counted.repository.findJob(job.id), same(job));
      }
    }
  });

  test('test_find_job_property_plain_tasks_are_not_jobs', () {
    final Random random = seededRandom(64914);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedJobs counted = buildCountedJobRepository(
        random,
        randomStoredRecords(random),
      );

      for (final Task task in counted.taskRepository.listTasks()) {
        expect(
          () => counted.repository.findJob(task.id),
          throwsA(
            isA<RecordNotFound>()
                .having((RecordNotFound e) => e.kind, 'kind', 'job')
                .having(
                  (RecordNotFound e) => e.identifier,
                  'id',
                  task.id.value,
                ),
          ),
        );
      }
    }
  });

  test('test_find_job_property_deleted_jobs_are_gone', () async {
    final Random random = seededRandom(64915);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedJobs counted = buildCountedJobRepository(
        random,
        randomStoredRecords(random),
      );
      final Task job = await counted.repository.createJob(
        randomJobDraft(random),
      );

      await counted.repository.deleteJob(job.id);

      expect(
        () => counted.repository.findJob(job.id),
        throwsA(isA<RecordNotFound>()),
      );
      expect(
        () => counted.repository.findJob(TaskId(randomText(random))),
        throwsA(isA<RecordNotFound>()),
      );
    }
  });
}
