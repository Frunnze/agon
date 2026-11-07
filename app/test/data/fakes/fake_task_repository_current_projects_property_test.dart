import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../support/random_inputs.dart';
import 'support/notification_counter.dart';
import 'support/workspace_work_picks.dart';
import 'support/workspace_work_rig.dart';

const String _typePrefix = 'test_fake_task_repository';
const int _iterations = 25;

void main() {
  test('${_typePrefix}_create_task_property_current_projects_are_'
      'listed', () async {
    final Random random = seededRandom(78010);
    for (int i = 0; i < _iterations; i += 1) {
      final WorkspaceWorkRig rig = await buildWorkspaceWorkRig(random);
      final List<ProjectId> current = listCurrentWorkProjectIds(rig);
      if (current.isNotEmpty) {
        final Task created = await rig.fakeTasks.createTask(
          randomWorkDraftIn(random, rig, pickOne(random, current)),
        );
        expect(rig.fakeTasks.findTask(created.id), same(created));
        expect(rig.fakeTasks.listTasks().first, same(created));
      }
      await closeWorkspaceWorkRig(rig);
    }
  });

  test('${_typePrefix}_create_task_property_refusals_store_nothing', () async {
    final Random random = seededRandom(78011);
    for (int i = 0; i < _iterations; i += 1) {
      final WorkspaceWorkRig rig = await buildWorkspaceWorkRig(random);
      final List<Task> before = rig.fakeTasks.listTasksAndJobs();
      final NotificationCounter counter = NotificationCounter();
      rig.fakeTasks.addListener(counter.record);

      await expectLater(
        rig.fakeTasks.createTask(
          randomWorkDraftIn(random, rig, missingWorkProjectId),
        ),
        throwsA(isA<RecordNotFound>()),
      );

      expect(identical(rig.fakeTasks.listTasksAndJobs(), before), isTrue);
      expect(counter.count, 0);
      await closeWorkspaceWorkRig(rig);
    }
  });

  test('${_typePrefix}_update_task_property_moves_hidden_work_into_the_'
      'current_workspace', () async {
    final Random random = seededRandom(78012);
    for (int i = 0; i < _iterations; i += 1) {
      final HiddenWorkRig? built = await buildHiddenWorkRig(random);
      if (built == null) {
        continue;
      }
      final List<ProjectId> current = listCurrentWorkProjectIds(built.rig);
      if (current.isNotEmpty) {
        final Task updated = await built.rig.fakeTasks.updateTask(
          built.hidden.id,
          randomWorkDraftIn(random, built.rig, pickOne(random, current)),
        );
        expect(updated.schedule, isNull);
        expect(built.rig.fakeTasks.findTask(built.hidden.id), same(updated));
      }
      await closeWorkspaceWorkRig(built.rig);
    }
  });

  test(
    '${_typePrefix}_update_task_property_refusals_change_nothing',
    () async {
      final Random random = seededRandom(78013);
      for (int i = 0; i < _iterations; i += 1) {
        final HiddenWorkRig? built = await buildHiddenWorkRig(random);
        if (built == null) {
          continue;
        }
        final List<Task> before = built.rig.fakeTasks.listTasksAndJobs();

        await expectLater(
          built.rig.fakeTasks.updateTask(
            built.hidden.id,
            randomWorkDraftIn(random, built.rig, built.hidden.projectId),
          ),
          throwsA(anyOf(isA<RecordNotFound>(), isA<StateError>())),
        );

        expect(
          identical(built.rig.fakeTasks.listTasksAndJobs(), before),
          isTrue,
        );
        await closeWorkspaceWorkRig(built.rig);
      }
    },
  );
}
