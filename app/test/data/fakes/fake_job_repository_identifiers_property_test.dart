import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/task.dart';

import '../../support/random_inputs.dart';
import 'support/job_inputs.dart';

const String _createdJobPrefix = 'created-job-';
const int _largestCollidingNumber = 6;
const int _largestCreationCount = 6;

List<Task> _seedsWithCollidingIds(Random random) {
  final List<Task> seeds = randomStoredRecords(random);
  for (int number = 1; number <= _largestCollidingNumber; number += 1) {
    if (random.nextBool()) {
      final String identifier = '$_createdJobPrefix$number';
      seeds.add(randomStoredRecord(random, identifier: identifier));
    }
  }
  seeds.shuffle(random);
  return seeds;
}

Future<Set<TaskId>> _createJobs(
  Random random,
  FakeJobRepository repository, {
  required int count,
}) async {
  final Set<TaskId> created = <TaskId>{};
  for (int creation = 0; creation < count; creation += 1) {
    final Task job = await repository.createJob(randomJobDraft(random));
    created.add(job.id);
  }
  return created;
}

void main() {
  test('test_claim_unused_job_id_property_skips_every_seeded_'
      'id', () async {
    final Random random = seededRandom(65401);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Task> seeds = _seedsWithCollidingIds(random);
      final CountedJobs counted = buildCountedJobRepository(random, seeds);
      final int count = 1 + random.nextInt(_largestCreationCount);

      final Set<TaskId> created = await _createJobs(
        random,
        counted.repository,
        count: count,
      );

      expect(created.length, count);
      for (final Task seed in seeds) {
        expect(created, isNot(contains(seed.id)));
      }
    }
  });

  test('test_claim_unused_job_id_property_never_reuses_a_deleted_job_'
      'id', () async {
    final Random random = seededRandom(65402);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedJobs counted = buildCountedJobRepository(
        random,
        randomStoredRecords(random),
      );
      final Task deleted = await counted.repository.createJob(
        randomJobDraft(random),
      );
      await counted.repository.deleteJob(deleted.id);

      final Task next = await counted.repository.createJob(
        randomJobDraft(random),
      );

      expect(next.id, isNot(deleted.id));
    }
  });

  test('test_claim_unused_job_id_property_two_repositories_taking_turns_'
      'never_clash', () async {
    final Random random = seededRandom(65403);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedJobs counted = buildCountedJobRepository(
        random,
        const <Task>[],
      );
      final FakeJobRepository other = FakeJobRepository(
        taskRepository: counted.taskRepository,
        clock: FixedClock(counted.moment),
      );
      final int turnCount = 1 + random.nextInt(_largestCreationCount);
      final Set<TaskId> created = <TaskId>{};

      for (int turn = 0; turn < turnCount; turn += 1) {
        final FakeJobRepository chosen = random.nextBool()
            ? counted.repository
            : other;
        final Task job = await chosen.createJob(randomJobDraft(random));
        created.add(job.id);
      }

      expect(created.length, turnCount);
      expect(counted.repository.listJobs().length, turnCount);
    }
  });

  test('test_is_stored_property_plain_task_ids_count_as_taken', () async {
    final Random random = seededRandom(65404);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Task plainTask = Task.fromDraft(
        id: const TaskId('${_createdJobPrefix}1'),
        draft: randomJobDraft(random).task,
        schedule: null,
        status: pickOne(random, TaskStatus.values),
        createdAt: randomUtcMoment(random),
      );
      final CountedJobs counted = buildCountedJobRepository(random, <Task>[
        plainTask,
      ]);

      final Task job = await counted.repository.createJob(
        randomJobDraft(random),
      );

      expect(job.id, isNot(plainTask.id));
      expect(counted.taskRepository.listTasks(), <Task>[plainTask]);
    }
  });

  test('test_is_stored_property_records_stored_later_count_as_'
      'taken', () async {
    final Random random = seededRandom(65405);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedJobs counted = buildCountedJobRepository(
        random,
        randomStoredRecords(random),
      );
      final int number = 1 + random.nextInt(_largestCollidingNumber);
      final Task late = randomStoredRecord(
        random,
        identifier: '$_createdJobPrefix$number',
      );
      counted.taskRepository.storeTask(late);

      final Set<TaskId> created = await _createJobs(
        random,
        counted.repository,
        count: number,
      );

      expect(created, isNot(contains(late.id)));
      expect(counted.taskRepository.findTask(late.id), same(late));
    }
  });

  test('test_is_stored_property_every_existing_record_survives_a_'
      'creation', () async {
    final Random random = seededRandom(65406);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Task> seeds = _seedsWithCollidingIds(random);
      final CountedJobs counted = buildCountedJobRepository(random, seeds);

      await _createJobs(
        random,
        counted.repository,
        count: 1 + random.nextInt(_largestCreationCount),
      );

      for (final Task seed in seeds) {
        expect(counted.taskRepository.findTask(seed.id), same(seed));
      }
    }
  });
}
