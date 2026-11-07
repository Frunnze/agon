import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../support/random_inputs.dart';
import 'support/job_inputs.dart';
import 'support/notification_counter.dart';
import 'support/workspace_work_picks.dart';
import 'support/workspace_work_rig.dart';

const String _typePrefix = 'test_fake_task_repository';
const int _iterations = 25;

void main() {
  test('${_typePrefix}_start_task_property_hidden_work_starts_without_'
      'showing_up', () async {
    final Random random = seededRandom(78001);
    for (int i = 0; i < _iterations; i += 1) {
      final HiddenWorkRig? built = await buildHiddenWorkRig(random);
      if (built == null) {
        continue;
      }
      final List<Task> visibleBefore = built.rig.fakeTasks.listTasks();

      final Run run = await built.rig.fakeTasks.startTask(built.hidden.id);

      expect(built.rig.fakeTasks.listRuns(built.hidden.id), <Run>[run]);
      expect(built.rig.fakeTasks.listTasks(), orderedEquals(visibleBefore));
      await closeWorkspaceWorkRig(built.rig);
    }
  });

  test('${_typePrefix}_cancel_run_property_cancels_hidden_work', () async {
    final Random random = seededRandom(78002);
    for (int i = 0; i < _iterations; i += 1) {
      final HiddenWorkRig? built = await buildHiddenWorkRig(random);
      if (built == null) {
        continue;
      }
      final Run started = await built.rig.fakeTasks.startTask(built.hidden.id);

      final Run cancelled = await built.rig.fakeTasks.cancelRun(started.id);

      expect(cancelled.status, RunStatus.cancelled);
      final Task stored = built.rig.fakeTasks.listTasksAndJobs().firstWhere(
        (Task task) => task.id == built.hidden.id,
      );
      expect(stored.status, TaskStatus.toDo);
      await closeWorkspaceWorkRig(built.rig);
    }
  });

  test('${_typePrefix}_cancel_run_property_unknown_run_changes_'
      'nothing', () async {
    final Random random = seededRandom(78003);
    for (int i = 0; i < _iterations; i += 1) {
      final WorkspaceWorkRig rig = await buildWorkspaceWorkRig(random);
      final List<Task> before = rig.fakeTasks.listTasksAndJobs();

      await expectLater(
        rig.fakeTasks.cancelRun(RunId('missing-${randomText(random)}')),
        throwsA(isA<RecordNotFound>()),
      );

      expect(identical(rig.fakeTasks.listTasksAndJobs(), before), isTrue);
      await closeWorkspaceWorkRig(rig);
    }
  });

  test('${_typePrefix}_cancel_run_property_notifies_once', () async {
    final Random random = seededRandom(78004);
    for (int i = 0; i < _iterations; i += 1) {
      final HiddenWorkRig? built = await buildHiddenWorkRig(random);
      if (built == null) {
        continue;
      }
      final Run started = await built.rig.fakeTasks.startTask(built.hidden.id);
      final NotificationCounter counter = NotificationCounter();
      built.rig.fakeTasks.addListener(counter.record);

      await built.rig.fakeTasks.cancelRun(started.id);

      expect(counter.count, 1);
      await closeWorkspaceWorkRig(built.rig);
    }
  });

  test('${_typePrefix}_retry_run_property_reopens_hidden_work', () async {
    final Random random = seededRandom(78005);
    for (int i = 0; i < _iterations; i += 1) {
      final HiddenWorkRig? built = await buildHiddenWorkRig(random);
      if (built == null) {
        continue;
      }
      final Run started = await built.rig.fakeTasks.startTask(built.hidden.id);
      await built.rig.fakeTasks.cancelRun(started.id);

      final Run reopened = await built.rig.fakeTasks.retryRun(started.id);

      expect(reopened.id, started.id);
      final Task stored = built.rig.fakeTasks.listTasksAndJobs().firstWhere(
        (Task task) => task.id == built.hidden.id,
      );
      expect(stored.status, TaskStatus.running);
      await closeWorkspaceWorkRig(built.rig);
    }
  });

  test('${_typePrefix}_retry_run_property_refuses_while_another_run_is_'
      'active', () async {
    final Random random = seededRandom(78006);
    for (int i = 0; i < _iterations; i += 1) {
      final HiddenWorkRig? built = await buildHiddenWorkRig(random);
      if (built == null) {
        continue;
      }
      final Run first = await built.rig.fakeTasks.startTask(built.hidden.id);
      await built.rig.fakeTasks.cancelRun(first.id);
      await built.rig.fakeTasks.startTask(built.hidden.id);

      await expectLater(
        built.rig.fakeTasks.retryRun(first.id),
        throwsStateError,
      );
      await closeWorkspaceWorkRig(built.rig);
    }
  });

  test('${_typePrefix}_retry_run_property_unknown_run_is_record_not_'
      'found', () async {
    final Random random = seededRandom(78007);
    for (int i = 0; i < _iterations; i += 1) {
      final WorkspaceWorkRig rig = await buildWorkspaceWorkRig(random);

      await expectLater(
        rig.fakeTasks.retryRun(RunId('missing-${randomText(random)}')),
        throwsA(isA<RecordNotFound>()),
      );
      await closeWorkspaceWorkRig(rig);
    }
  });

  test('${_typePrefix}_delete_task_property_removes_hidden_work', () async {
    final Random random = seededRandom(78008);
    for (int i = 0; i < _iterations; i += 1) {
      final HiddenWorkRig? built = await buildHiddenWorkRig(random);
      if (built == null) {
        continue;
      }

      await built.rig.fakeTasks.deleteTask(built.hidden.id);

      expect(
        describeTaskIds(built.rig.fakeTasks.listTasksAndJobs()),
        isNot(contains(built.hidden.id.value)),
      );
      await closeWorkspaceWorkRig(built.rig);
    }
  });

  test('${_typePrefix}_delete_task_property_running_hidden_work_is_'
      'kept', () async {
    final Random random = seededRandom(78009);
    for (int i = 0; i < _iterations; i += 1) {
      final HiddenWorkRig? built = await buildHiddenWorkRig(random);
      if (built == null) {
        continue;
      }
      await built.rig.fakeTasks.startTask(built.hidden.id);
      final List<Task> before = built.rig.fakeTasks.listTasksAndJobs();

      await expectLater(
        built.rig.fakeTasks.deleteTask(built.hidden.id),
        throwsStateError,
      );

      expect(
        identical(built.rig.fakeTasks.listTasksAndJobs(), before),
        isTrue,
      );
      await closeWorkspaceWorkRig(built.rig);
    }
  });
}
