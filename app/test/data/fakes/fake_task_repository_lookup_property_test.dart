import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/rules/run_lifecycle.dart';

import '../../support/random_inputs.dart';
import 'support/task_inputs.dart';

void main() {
  test('test_find_task_property_finds_every_task_and_job', () {
    final Random random = seededRandom(66810);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeTaskRepository repository = buildSeededTaskRepository(
        randomTaskSeed(random),
      );

      for (final Task task in repository.listTasksAndJobs()) {
        expect(repository.findTask(task.id), same(task));
      }
    }
  });

  test('test_find_task_property_unknown_ids_name_the_missing_id', () {
    final Random random = seededRandom(66811);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeTaskRepository repository = buildSeededTaskRepository(
        randomTaskSeed(random),
      );
      final String unknown = 'unknown-${randomText(random)}';

      expect(
        () => repository.findTask(TaskId(unknown)),
        throwsRecordNotFoundFor(unknown),
      );
    }
  });

  test('test_find_task_property_shows_the_latest_update', () async {
    final Random random = seededRandom(66812);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskSeed seed = randomTaskSeed(random);
      if (seed.tasks.isEmpty) {
        continue;
      }
      final FakeTaskRepository repository = buildSeededTaskRepository(seed);
      final Task edited = pickOne(random, seed.tasks);

      final Task updated = await repository.updateTask(
        edited.id,
        randomSeededTask(random, 0).toDraft(),
      );

      expect(repository.findTask(edited.id), same(updated));
    }
  });

  test('test_list_runs_property_only_that_tasks_runs_newest_first', () {
    final Random random = seededRandom(66813);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskSeed seed = randomTaskSeed(random);
      final FakeTaskRepository repository = buildSeededTaskRepository(seed);

      for (final Task task in seed.tasks) {
        final List<Run> runs = repository.listRuns(task.id);
        for (int index = 0; index < runs.length; index += 1) {
          expect(runs[index].taskId, task.id);
          if (index > 0) {
            expect(runs[index - 1].number, greaterThan(runs[index].number));
          }
        }
      }
    }
  });

  test('test_list_runs_property_covers_every_seeded_run_once', () {
    final Random random = seededRandom(66814);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskSeed seed = randomTaskSeed(random);
      final FakeTaskRepository repository = buildSeededTaskRepository(seed);

      final List<RunId> listed = <RunId>[
        for (final Task task in seed.tasks)
          for (final Run run in repository.listRuns(task.id)) run.id,
      ];
      final List<RunId> seededIds = <RunId>[
        for (final Run run in seed.runs) run.id,
      ];
      expect(listed, unorderedEquals(seededIds));
    }
  });

  test('test_list_runs_property_unknown_tasks_have_no_runs', () {
    final Random random = seededRandom(66815);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeTaskRepository repository = buildSeededTaskRepository(
        randomTaskSeed(random),
      );
      final TaskId unknown = TaskId('unknown-${randomText(random)}');

      expect(repository.listRuns(unknown), isEmpty);
    }
  });

  test('test_find_run_property_finds_every_listed_run', () {
    final Random random = seededRandom(66816);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskSeed seed = randomTaskSeed(random);
      final FakeTaskRepository repository = buildSeededTaskRepository(seed);

      for (final Task task in seed.tasks) {
        for (final Run run in repository.listRuns(task.id)) {
          expect(repository.findRun(run.id), same(run));
        }
      }
    }
  });

  test('test_find_run_property_unknown_ids_name_the_missing_id', () {
    final Random random = seededRandom(66817);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeTaskRepository repository = buildSeededTaskRepository(
        randomTaskSeed(random),
      );
      final String unknown = 'unknown-${randomText(random)}';

      expect(
        () => repository.findRun(RunId(unknown)),
        throwsRecordNotFoundFor(unknown),
      );
    }
  });

  test('test_find_run_property_deleted_tasks_take_their_runs', () async {
    final Random random = seededRandom(66818);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskSeed seed = randomTaskSeed(random);
      final FakeTaskRepository repository = buildSeededTaskRepository(seed);
      final List<Task> idle = <Task>[
        for (final Task task in seed.tasks)
          if (!repository.listRuns(task.id).any(isRunActive)) task,
      ];
      if (idle.isEmpty) {
        continue;
      }
      final Task deleted = pickOne(random, idle);
      final List<Run> runs = repository.listRuns(deleted.id);

      await repository.deleteTask(deleted.id);

      for (final Run run in runs) {
        expect(
          () => repository.findRun(run.id),
          throwsRecordNotFoundFor(run.id.value),
        );
      }
    }
  });
}
