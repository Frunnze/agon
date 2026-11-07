import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';

import '../../support/random_inputs.dart';
import '../../support/sample_records.dart';
import 'support/refusals.dart';
import 'support/task_inputs.dart';
import 'support/task_rigs.dart';

const int _largestTakenCount = 4;
const int _largestCreationCount = 10;
const int _sequenceLength = 6;

Task _seedTaskWithId(Random random, String identifier) {
  return Task.fromDraft(
    id: TaskId(identifier),
    draft: randomTaskDraft(random),
    schedule: null,
    status: TaskStatus.done,
    createdAt: randomUtcMoment(random),
  );
}

List<RunId> _listEveryRunId(FakeTaskRepository repository) {
  return <RunId>[
    for (final Task task in repository.listTasksAndJobs())
      for (final Run run in repository.listRuns(task.id)) run.id,
  ];
}

void main() {
  test('test_next_free_identifier_property_skips_taken_task_ids', () async {
    final Random random = seededRandom(67601);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int takenCount = 1 + random.nextInt(_largestTakenCount);
      final List<Task> seeded = <Task>[
        for (int index = 1; index <= takenCount; index += 1)
          _seedTaskWithId(random, '$createdTaskIdPrefix$index'),
      ];
      final FakeTaskRepository repository = buildSeededTaskRepository((
        tasks: seeded,
        runs: const <Run>[],
      ));

      final Task created = await repository.createTask(
        randomTaskDraft(random),
      );

      final List<Task> everything = repository.listTasksAndJobs();
      final Set<TaskId> ids = <TaskId>{
        for (final Task task in everything) task.id,
      };
      expect(ids.length, everything.length);
      expect(repository.findTask(created.id), same(created));
    }
  });

  test('test_next_free_identifier_property_skips_taken_run_ids', () async {
    final Random random = seededRandom(67602);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Task owner = _seedTaskWithId(random, 'owner-$i');
      final Task starter = Task.fromDraft(
        id: const TaskId('starter'),
        draft: owner.toDraft(),
        schedule: null,
        status: TaskStatus.toDo,
        createdAt: owner.createdAt,
      );
      final int takenCount = 1 + random.nextInt(_largestTakenCount);
      final List<Run> seededRuns = <Run>[
        for (int index = 1; index <= takenCount; index += 1)
          buildSeededRun(
            random,
            runId: '$createdRunIdPrefix$index',
            taskId: owner.id,
            number: index,
            status: 'failed',
          ),
      ];
      final TaskRig rig = buildTaskRig((
        tasks: <Task>[owner, starter],
        runs: seededRuns,
      ));
      if (!canStartDoer(rig.flows, starter.doer)) {
        continue;
      }

      await rig.repository.startTask(starter.id);
      await rig.repository.retryRun(seededRuns.first.id);

      final List<RunId> ids = _listEveryRunId(rig.repository);
      expect(ids.toSet().length, ids.length);
    }
  });

  test('test_next_free_identifier_property_task_and_run_ids_differ', () async {
    final Random random = seededRandom(67603);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskRig rig = buildTaskRig((
        tasks: const <Task>[],
        runs: const <Run>[],
      ));
      final int creationCount = 1 + random.nextInt(_largestCreationCount);
      final Set<String> identifiers = <String>{};

      for (int index = 0; index < creationCount; index += 1) {
        final Task task = await rig.repository.createTask(
          randomTaskDraft(random),
        );
        identifiers.add(task.id.value);
        if (canStartDoer(rig.flows, task.doer)) {
          final Run run = await rig.repository.startTask(task.id);
          identifiers.add(run.id.value);
        }
      }

      final int recordCount =
          rig.repository.listTasksAndJobs().length +
          _listEveryRunId(rig.repository).length;
      expect(identifiers.length, recordCount);
    }
  });

  test(
    'test_refuse_second_active_run_property_start_names_the_task_kind',
    () async {
      final Random random = seededRandom(67604);

      for (int i = 0; i < propertyIterations; i += 1) {
        final TaskRig rig = buildTaskRig(randomTaskSeed(random));
        final List<Task> busy = listBusyTasks(rig.repository);
        if (busy.isEmpty) {
          continue;
        }
        final Task task = pickOne(random, busy);

        await expectLater(
          rig.repository.startTask(task.id),
          throwsA(
            isA<StateError>().having(
              (StateError error) => error.message,
              'message',
              'the ${task.schedule == null ? 'task' : 'job'} is already '
                  'running',
            ),
          ),
        );
      }
    },
  );

  test('test_refuse_second_active_run_property_idle_tasks_may_run', () async {
    final Random random = seededRandom(67605);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskRig rig = buildTaskRig(randomTaskSeed(random));
      final List<Task> startable = listStartableTasks(rig);
      if (startable.isEmpty) {
        continue;
      }
      final Task task = pickOne(random, startable);

      final Run run = await rig.repository.startTask(task.id);

      final int activeCount = rig.repository
          .listRuns(task.id)
          .where((Run listed) => activeRunStatuses.contains(listed.status))
          .length;
      expect(activeCount, 1);
      expect(run.taskId, task.id);
    }
  });

  test(
    'test_refuse_second_active_run_property_holds_over_sequences',
    () async {
      final Random random = seededRandom(67606);

      for (int i = 0; i < propertyIterations; i += 1) {
        final TaskRig rig = buildTaskRig(randomTaskSeed(random));
        final List<Task> tasks = rig.repository.listTasksAndJobs();
        if (tasks.isEmpty) {
          continue;
        }

        for (int step = 0; step < _sequenceLength; step += 1) {
          final Task task = pickOne(random, tasks);
          final List<Run> runs = rig.repository.listRuns(task.id);
          if (runs.isNotEmpty && random.nextBool()) {
            await isRefused(
              () => rig.repository.retryRun(pickOne(random, runs).id),
              isRefusal: refusesWithStateError,
            );
          } else if (canStartDoer(rig.flows, task.doer)) {
            await isRefused(
              () => rig.repository.startTask(task.id),
              isRefusal: refusesWithStateError,
            );
          }
        }

        for (final Task task in tasks) {
          final int activeCount = rig.repository
              .listRuns(task.id)
              .where((Run run) => activeRunStatuses.contains(run.status))
              .length;
          expect(activeCount, lessThanOrEqualTo(1));
        }
      }
    },
  );
}
