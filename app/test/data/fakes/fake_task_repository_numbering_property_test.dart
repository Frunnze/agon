import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';

import '../../support/random_inputs.dart';
import '../../support/sample_records.dart';
import 'support/startable_drafts.dart';
import 'support/task_inputs.dart';
import 'support/task_rigs.dart';

const int _largestRestartCount = 6;

List<Task> _listStartableTasksWithRuns(TaskRig rig) {
  return <Task>[
    for (final Task task in listStartableTasks(rig))
      if (rig.repository.listRuns(task.id).isNotEmpty) task,
  ];
}

Future<Run> _restart(TaskRig rig, Task task) async {
  final Run started = await rig.repository.startTask(task.id);
  await rig.repository.cancelRun(started.id);
  return started;
}

void main() {
  test('test_next_run_number_property_a_task_of_a_used_doer_starts_at_'
      'one', () async {
    final Random random = seededRandom(68401);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskRig rig = buildTaskRig(randomTaskSeed(random));
      final List<Task> used = _listStartableTasksWithRuns(rig);
      if (used.isEmpty) {
        continue;
      }
      final Task sibling = pickOne(random, used);
      final TaskDraft draft = replaceDraftDoer(
        randomTaskDraft(random),
        sibling.doer,
      );
      final Task created = await rig.repository.createTask(draft);

      final Run first = await rig.repository.startTask(created.id);

      expect(first.number, 1);
      expect(rig.repository.listRuns(sibling.id), isNotEmpty);
    }
  });

  test('test_next_run_number_property_counts_up_by_one_within_a_'
      'task', () async {
    final Random random = seededRandom(68402);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskRig rig = buildTaskRig(randomTaskSeed(random));
      final Task task = await rig.repository.createTask(
        randomStartableTaskDraft(random, rig.flows),
      );
      final int restartCount = 1 + random.nextInt(_largestRestartCount);

      for (int number = 1; number <= restartCount; number += 1) {
        final List<Task> others = <Task>[
          for (final Task other in listStartableTasks(rig))
            if (other.id != task.id) other,
        ];
        if (others.isNotEmpty && random.nextBool()) {
          await _restart(rig, pickOne(random, others));
        }
        final Run started = await _restart(rig, task);

        expect(started.number, number);
      }
    }
  });

  test('test_next_run_number_property_follows_only_the_tasks_own_'
      'runs', () async {
    final Random random = seededRandom(68403);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskRig rig = buildTaskRig(randomTaskSeed(random));
      final List<Task> startable = listStartableTasks(rig);
      if (startable.isEmpty) {
        continue;
      }
      final Task task = pickOne(random, startable);
      int highestOwnNumber = 0;
      for (final Run run in rig.repository.listRuns(task.id)) {
        highestOwnNumber = max(highestOwnNumber, run.number);
      }

      final Run run = await rig.repository.startTask(task.id);

      expect(run.number, highestOwnNumber + 1);
    }
  });
}
