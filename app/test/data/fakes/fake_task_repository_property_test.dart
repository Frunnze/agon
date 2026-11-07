import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/rules/run_lifecycle.dart';

import '../../support/random_inputs.dart';
import 'support/task_inputs.dart';

const String _typePrefix = 'test_fake_task_repository';

void main() {
  test('${_typePrefix}_new_property_keeps_every_seeded_record', () {
    final Random random = seededRandom(66801);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskSeed seed = randomTaskSeed(random);

      final FakeTaskRepository repository = buildSeededTaskRepository(seed);

      expect(
        describeTasks(repository.listTasksAndJobs()),
        describeTasks(seed.tasks),
      );
      for (final Run run in seed.runs) {
        expect(repository.findRun(run.id), same(run));
      }
    }
  });

  test('${_typePrefix}_new_property_later_seed_edits_do_not_leak', () {
    final Random random = seededRandom(66802);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskSeed seed = randomTaskSeed(random);
      final List<String> tasksBefore = describeTasks(seed.tasks);
      final FakeTaskRepository repository = buildSeededTaskRepository(seed);
      final List<String> runsBefore = <String>[
        for (final Task task in seed.tasks)
          ...describeRuns(repository.listRuns(task.id)),
      ];

      seed.tasks.clear();
      seed.runs.clear();

      expect(describeTasks(repository.listTasksAndJobs()), tasksBefore);
      final List<String> runsAfter = <String>[
        for (final Task task in repository.listTasksAndJobs())
          ...describeRuns(repository.listRuns(task.id)),
      ];
      expect(runsAfter, runsBefore);
    }
  });

  test('${_typePrefix}_new_property_shown_lists_cannot_be_edited', () {
    final Random random = seededRandom(66803);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskSeed seed = randomTaskSeed(random);
      final FakeTaskRepository repository = buildSeededTaskRepository(seed);
      final Task extra = randomSeededTask(random, propertyIterations);

      expect(() => repository.listTasks().add(extra), throwsUnsupportedError);
      expect(
        () => repository.listTasksAndJobs().add(extra),
        throwsUnsupportedError,
      );
      for (final Task task in seed.tasks) {
        expect(repository.listRuns(task.id).clear, throwsUnsupportedError);
      }
    }
  });

  test('test_list_tasks_property_lists_every_task_and_no_job', () {
    final Random random = seededRandom(66804);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskSeed seed = randomTaskSeed(random);
      final FakeTaskRepository repository = buildSeededTaskRepository(seed);

      final List<String> expected = <String>[
        for (final Task task in seed.tasks)
          if (task.schedule == null) describeTask(task),
      ];
      expect(describeTasks(repository.listTasks()), expected);
    }
  });

  test('test_list_tasks_property_created_tasks_come_first', () async {
    final Random random = seededRandom(66805);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeTaskRepository repository = buildSeededTaskRepository(
        randomTaskSeed(random),
      );
      final List<String> before = describeTasks(repository.listTasks());

      final Task created = await repository.createTask(
        randomSeededTask(random, 0).toDraft(),
      );

      expect(describeTasks(repository.listTasks()), <String>[
        describeTask(created),
        ...before,
      ]);
    }
  });

  test('test_list_tasks_property_deleted_tasks_leave_the_list', () async {
    final Random random = seededRandom(66806);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskSeed seed = randomTaskSeed(random);
      final FakeTaskRepository repository = buildSeededTaskRepository(seed);
      final List<Task> idle = <Task>[
        for (final Task task in repository.listTasks())
          if (!repository.listRuns(task.id).any(isRunActive)) task,
      ];
      if (idle.isEmpty) {
        continue;
      }
      final Task deleted = pickOne(random, idle);
      final int countBefore = repository.listTasks().length;

      await repository.deleteTask(deleted.id);

      final List<TaskId> listed = <TaskId>[
        for (final Task task in repository.listTasks()) task.id,
      ];
      expect(listed, isNot(contains(deleted.id)));
      expect(listed.length, countBefore - 1);
    }
  });

  test('test_list_tasks_and_jobs_property_is_tasks_plus_jobs', () {
    final Random random = seededRandom(66807);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeTaskRepository repository = buildSeededTaskRepository(
        randomTaskSeed(random),
      );

      final List<Task> everything = repository.listTasksAndJobs();
      final List<Task> jobs = <Task>[
        for (final Task task in everything)
          if (task.schedule != null) task,
      ];
      expect(everything.length, repository.listTasks().length + jobs.length);
      for (final Task task in repository.listTasks()) {
        expect(everything, contains(same(task)));
      }
    }
  });

  test('test_list_tasks_and_jobs_property_stored_jobs_stay_out_of_tasks', () {
    final Random random = seededRandom(66808);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeTaskRepository repository = buildSeededTaskRepository(
        randomTaskSeed(random),
      );
      final Task job = randomSeededTask(random, propertyIterations + i);
      if (job.schedule == null) {
        continue;
      }

      repository.storeTask(job);

      expect(repository.listTasksAndJobs().first, same(job));
      expect(repository.listTasks(), isNot(contains(same(job))));
    }
  });

  test('test_list_tasks_and_jobs_property_ids_stay_unique', () async {
    final Random random = seededRandom(66809);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeTaskRepository repository = buildSeededTaskRepository(
        randomTaskSeed(random),
      );
      for (final Task task in repository.listTasksAndJobs()) {
        repository.storeTask(task.withStatus(TaskStatus.done));
      }
      await repository.createTask(randomSeededTask(random, 0).toDraft());

      final List<Task> everything = repository.listTasksAndJobs();
      final Set<TaskId> ids = <TaskId>{
        for (final Task task in everything) task.id,
      };
      expect(ids.length, everything.length);
    }
  });
}
