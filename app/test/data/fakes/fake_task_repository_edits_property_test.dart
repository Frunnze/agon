import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../support/random_inputs.dart';
import '../../support/sample_records.dart';
import 'support/notification_counter.dart';
import 'support/refusals.dart';
import 'support/task_inputs.dart';
import 'support/task_rigs.dart';

bool _refusesAsNotFound(Object error) => error is RecordNotFound;

void _expectDraftFields(Task task, TaskDraft draft) {
  expect(task.title, draft.title);
  expect(task.details, draft.details);
  expect(task.projectId, draft.projectId);
  expect(task.doer, draft.doer);
  expect(task.runsOn, draft.runsOn);
  expect(task.agentPlace, draft.agentPlace);
  expect(task.skills, draft.skills);
  expect(task.usesAutomaticSkills, draft.usesAutomaticSkills);
  expect(task.approvalPolicy, draft.approvalPolicy);
}

void main() {
  test('test_create_task_property_keeps_the_draft_and_starts_to_do', () async {
    final Random random = seededRandom(67101);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeTaskRepository repository = buildSeededTaskRepository(
        randomTaskSeed(random),
      );
      final TaskDraft draft = randomTaskDraft(random);

      final Task created = await repository.createTask(draft);

      _expectDraftFields(created, draft);
      expect(created.status, TaskStatus.toDo);
      expect(created.schedule, isNull);
      expect(created.createdAt, taskClockMoment);
      expect(repository.listRuns(created.id), isEmpty);
    }
  });

  test('test_create_task_property_each_creation_is_a_new_task', () async {
    final Random random = seededRandom(67102);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeTaskRepository repository = buildSeededTaskRepository(
        randomTaskSeed(random),
      );
      final int countBefore = repository.listTasksAndJobs().length;
      final TaskDraft draft = randomTaskDraft(random);

      final Task first = await repository.createTask(draft);
      final Task second = await repository.createTask(draft);

      expect(second.id, isNot(first.id));
      expect(repository.listTasksAndJobs().length, countBefore + 2);
      expect(repository.listTasks().first, same(second));
    }
  });

  test('test_create_task_property_notifies_once', () async {
    final Random random = seededRandom(67103);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeTaskRepository repository = buildSeededTaskRepository(
        randomTaskSeed(random),
      );
      final NotificationCounter counter = NotificationCounter();
      repository.addListener(counter.record);

      await repository.createTask(randomTaskDraft(random));

      expect(counter.count, 1);
    }
  });

  test('test_update_task_property_keeps_identity_status_and_runs', () async {
    final Random random = seededRandom(67104);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskSeed seed = randomTaskSeed(random);
      if (seed.tasks.isEmpty) {
        continue;
      }
      final FakeTaskRepository repository = buildSeededTaskRepository(seed);
      final Task before = pickOne(random, seed.tasks);
      final List<Run> runsBefore = repository.listRuns(before.id);
      final TaskDraft draft = randomTaskDraft(random);

      final Task after = await repository.updateTask(before.id, draft);

      _expectDraftFields(after, draft);
      expect(after.id, before.id);
      expect(after.status, before.status);
      expect(after.createdAt, before.createdAt);
      expect(repository.listRuns(before.id), orderedEquals(runsBefore));
    }
  });

  test('test_update_task_property_unknown_ids_change_nothing', () async {
    final Random random = seededRandom(67105);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeTaskRepository repository = buildSeededTaskRepository(
        randomTaskSeed(random),
      );
      final List<String> before = describeTaskRepository(repository);
      final NotificationCounter counter = NotificationCounter();
      repository.addListener(counter.record);

      final bool wasRefused = await isRefused(
        () => repository.updateTask(
          TaskId('unknown-${randomText(random)}'),
          randomTaskDraft(random),
        ),
        isRefusal: _refusesAsNotFound,
      );

      expect(wasRefused, isTrue);
      expect(describeTaskRepository(repository), before);
      expect(counter.count, 0);
    }
  });

  test('test_update_task_property_notifies_once', () async {
    final Random random = seededRandom(67106);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskSeed seed = randomTaskSeed(random);
      if (seed.tasks.isEmpty) {
        continue;
      }
      final FakeTaskRepository repository = buildSeededTaskRepository(seed);
      final NotificationCounter counter = NotificationCounter();
      repository.addListener(counter.record);

      await repository.updateTask(
        pickOne(random, seed.tasks).id,
        randomTaskDraft(random),
      );

      expect(counter.count, 1);
    }
  });

  test('test_delete_task_property_removes_the_task_and_its_runs', () async {
    final Random random = seededRandom(67107);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeTaskRepository repository = buildSeededTaskRepository(
        randomTaskSeed(random),
      );
      final List<Task> idle = listIdleTasks(repository);
      if (idle.isEmpty) {
        continue;
      }
      final Task deleted = pickOne(random, idle);
      final List<String> others = <String>[
        for (final Task task in repository.listTasksAndJobs())
          if (task.id != deleted.id) describeTask(task),
      ];

      await repository.deleteTask(deleted.id);

      expect(describeTasks(repository.listTasksAndJobs()), others);
      expect(repository.listRuns(deleted.id), isEmpty);
    }
  });

  test('test_delete_task_property_refuses_while_a_run_is_active', () async {
    final Random random = seededRandom(67108);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeTaskRepository repository = buildSeededTaskRepository(
        randomTaskSeed(random),
      );
      final List<Task> busy = listBusyTasks(repository);
      if (busy.isEmpty) {
        continue;
      }
      final List<String> before = describeTaskRepository(repository);

      final bool wasRefused = await isRefused(
        () => repository.deleteTask(pickOne(random, busy).id),
        isRefusal: refusesWithStateError,
      );

      expect(wasRefused, isTrue);
      expect(describeTaskRepository(repository), before);
    }
  });

  test('test_delete_task_property_unknown_ids_change_nothing', () async {
    final Random random = seededRandom(67109);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeTaskRepository repository = buildSeededTaskRepository(
        randomTaskSeed(random),
      );
      final List<String> before = describeTaskRepository(repository);

      final bool wasRefused = await isRefused(
        () => repository.deleteTask(TaskId('unknown-${randomText(random)}')),
        isRefusal: _refusesAsNotFound,
      );

      expect(wasRefused, isTrue);
      expect(describeTaskRepository(repository), before);
    }
  });
}
