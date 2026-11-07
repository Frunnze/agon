import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';

import '../../support/random_inputs.dart';
import 'support/notification_counter.dart';
import 'support/task_inputs.dart';
import 'support/task_rigs.dart';

void main() {
  test('test_replace_run_property_cancel_keeps_the_runs_in_place', () async {
    final Random random = seededRandom(67010);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskRig rig = buildTaskRig(randomTaskSeed(random));
      final List<Task> startable = listStartableTasks(rig);
      if (startable.isEmpty) {
        continue;
      }
      final Task task = pickOne(random, startable);
      final Run started = await rig.repository.startTask(task.id);
      final List<Run> before = rig.repository.listRuns(task.id);

      final Run cancelled = await rig.repository.cancelRun(started.id);

      final List<Run> after = rig.repository.listRuns(task.id);
      expect(after.length, before.length);
      expect(after.first, same(cancelled));
      for (int index = 1; index < after.length; index += 1) {
        expect(after[index], same(before[index]));
      }
    }
  });

  test('test_replace_run_property_other_tasks_keep_their_runs', () async {
    final Random random = seededRandom(67011);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskRig rig = buildTaskRig(randomTaskSeed(random));
      final List<Task> startable = listStartableTasks(rig);
      if (startable.isEmpty) {
        continue;
      }
      final Task task = pickOne(random, startable);
      final Map<TaskId, List<Run>> before = <TaskId, List<Run>>{
        for (final Task other in rig.repository.listTasksAndJobs())
          other.id: rig.repository.listRuns(other.id),
      };

      final Run started = await rig.repository.startTask(task.id);
      await rig.repository.cancelRun(started.id);

      for (final MapEntry<TaskId, List<Run>> entry in before.entries) {
        if (entry.key != task.id) {
          expect(
            rig.repository.listRuns(entry.key),
            orderedEquals(entry.value),
          );
        }
      }
    }
  });

  test('test_replace_run_property_notifies_once_per_cancel', () async {
    final Random random = seededRandom(67012);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskRig rig = buildTaskRig(randomTaskSeed(random));
      final List<Task> startable = listStartableTasks(rig);
      if (startable.isEmpty) {
        continue;
      }
      final Run started = await rig.repository.startTask(
        pickOne(random, startable).id,
      );
      final NotificationCounter counter = NotificationCounter();
      rig.repository.addListener(counter.record);

      await rig.repository.cancelRun(started.id);

      expect(counter.count, 1);
    }
  });
}
