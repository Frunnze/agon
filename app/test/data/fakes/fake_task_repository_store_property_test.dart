import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/rules/run_lifecycle.dart';

import '../../support/random_inputs.dart';
import '../../support/sample_records.dart';
import 'support/notification_counter.dart';
import 'support/task_inputs.dart';

void main() {
  test('test_store_task_property_new_tasks_come_first', () {
    final Random random = seededRandom(67110);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeTaskRepository repository = buildSeededTaskRepository(
        randomTaskSeed(random),
      );
      final List<String> before = describeTasks(repository.listTasksAndJobs());
      final Task stored = randomSeededTask(random, propertyIterations + i);

      repository.storeTask(stored);

      expect(describeTasks(repository.listTasksAndJobs()), <String>[
        describeTask(stored),
        ...before,
      ]);
    }
  });

  test('test_store_task_property_known_tasks_are_replaced_in_place', () {
    final Random random = seededRandom(67111);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskSeed seed = randomTaskSeed(random);
      if (seed.tasks.isEmpty) {
        continue;
      }
      final FakeTaskRepository repository = buildSeededTaskRepository(seed);
      final int position = random.nextInt(seed.tasks.length);
      final Task replacement = seed.tasks[position].withStatus(
        pickOne(random, TaskStatus.values),
      );

      repository.storeTask(replacement);

      final List<Task> everything = repository.listTasksAndJobs();
      expect(everything.length, seed.tasks.length);
      expect(everything[position], same(replacement));
    }
  });

  test('test_store_task_property_notifies_once', () {
    final Random random = seededRandom(67112);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskSeed seed = randomTaskSeed(random);
      final FakeTaskRepository repository = buildSeededTaskRepository(seed);
      final NotificationCounter counter = NotificationCounter();
      repository.addListener(counter.record);
      final Task stored = seed.tasks.isNotEmpty && random.nextBool()
          ? pickOne(random, seed.tasks)
          : randomSeededTask(random, propertyIterations + i);

      repository.storeTask(stored);

      expect(counter.count, 1);
    }
  });

  test('test_replace_task_property_keeps_positions_and_ids', () async {
    final Random random = seededRandom(67113);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskSeed seed = randomTaskSeed(random);
      if (seed.tasks.isEmpty) {
        continue;
      }
      final FakeTaskRepository repository = buildSeededTaskRepository(seed);

      await repository.updateTask(
        pickOne(random, seed.tasks).id,
        randomTaskDraft(random),
      );

      final List<TaskId> ids = <TaskId>[
        for (final Task task in repository.listTasksAndJobs()) task.id,
      ];
      final List<TaskId> seededIds = <TaskId>[
        for (final Task task in seed.tasks) task.id,
      ];
      expect(ids, seededIds);
    }
  });

  test('test_replace_task_property_follows_the_run_status', () async {
    final Random random = seededRandom(67114);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskSeed seed = randomTaskSeed(random);
      final FakeTaskRepository repository = buildSeededTaskRepository(seed);
      final List<Run> active = <Run>[
        for (final Run run in seed.runs)
          if (isRunActive(run)) run,
      ];
      if (active.isEmpty) {
        continue;
      }
      final Run run = pickOne(random, active);

      await repository.cancelRun(run.id);

      expect(repository.findTask(run.taskId).status, TaskStatus.toDo);
      expect(repository.listTasksAndJobs().length, seed.tasks.length);
    }
  });

  test('test_replace_task_property_leaves_other_tasks_alone', () async {
    final Random random = seededRandom(67115);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskSeed seed = randomTaskSeed(random);
      if (seed.tasks.isEmpty) {
        continue;
      }
      final FakeTaskRepository repository = buildSeededTaskRepository(seed);
      final Task edited = pickOne(random, seed.tasks);

      await repository.updateTask(edited.id, randomTaskDraft(random));

      for (final Task task in seed.tasks) {
        if (task.id != edited.id) {
          expect(repository.findTask(task.id), same(task));
        }
      }
    }
  });
}
