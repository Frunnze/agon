import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes/current_workspace_tasks.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../support/random_inputs.dart';
import 'support/workspace_work_picks.dart';
import 'support/workspace_work_rig.dart';

const int _iterations = 25;

TaskPlaces _readPlaces(WorkspaceWorkRig rig) {
  return (
    workspaceRepository: rig.workspaces,
    projectRepository: rig.fakeProjects,
  );
}

Future<WorkspaceWorkRig> _buildSwitchedRig(Random random) async {
  final WorkspaceWorkRig rig = await buildWorkspaceWorkRig(random);
  await rig.workspaces.switchWorkspace(pickOne(random, rig.workspaceIds));
  return rig;
}

void main() {
  test('test_keep_tasks_in_current_workspace_property_keeps_exactly_current_'
      'projects', () async {
    final Random random = seededRandom(78301);
    for (int i = 0; i < _iterations; i += 1) {
      final WorkspaceWorkRig rig = await _buildSwitchedRig(random);
      final Set<ProjectId> current = listCurrentWorkProjectIds(rig).toSet();
      final List<Task> stored = rig.fakeTasks.listTasksAndJobs();

      final List<Task> kept = keepTasksInCurrentWorkspace(
        stored,
        _readPlaces(rig),
      );

      expect(kept, <Task>[
        for (final Task task in stored)
          if (current.contains(task.projectId)) task,
      ]);
      await closeWorkspaceWorkRig(rig);
    }
  });

  test(
    'test_keep_tasks_in_current_workspace_property_is_idempotent',
    () async {
      final Random random = seededRandom(78302);
      for (int i = 0; i < _iterations; i += 1) {
        final WorkspaceWorkRig rig = await _buildSwitchedRig(random);
        final List<Task> once = keepTasksInCurrentWorkspace(
          rig.fakeTasks.listTasksAndJobs(),
          _readPlaces(rig),
        );

        final List<Task> twice = keepTasksInCurrentWorkspace(
          once,
          _readPlaces(rig),
        );

        expect(twice, orderedEquals(once));
        expect(twice.clear, throwsUnsupportedError);
        await closeWorkspaceWorkRig(rig);
      }
    },
  );

  test('test_keep_tasks_in_current_workspace_property_workspaces_split_the_'
      'work', () async {
    final Random random = seededRandom(78303);
    for (int i = 0; i < _iterations; i += 1) {
      final WorkspaceWorkRig rig = await buildWorkspaceWorkRig(random);
      final List<Task> stored = rig.fakeTasks.listTasksAndJobs();
      final List<TaskId> seen = <TaskId>[];

      for (final WorkspaceId workspaceId in rig.workspaceIds) {
        await rig.workspaces.switchWorkspace(workspaceId);
        for (final Task task in keepTasksInCurrentWorkspace(
          stored,
          _readPlaces(rig),
        )) {
          seen.add(task.id);
        }
      }

      expect(
        seen,
        unorderedEquals(<TaskId>[
          for (final Task task in stored)
            if (task.projectId != missingWorkProjectId) task.id,
        ]),
      );
      await closeWorkspaceWorkRig(rig);
    }
  });

  test('test_refuse_project_outside_current_workspace_property_accepts_'
      'current_projects', () async {
    final Random random = seededRandom(78304);
    for (int i = 0; i < _iterations; i += 1) {
      final WorkspaceWorkRig rig = await _buildSwitchedRig(random);
      for (final ProjectId projectId in listCurrentWorkProjectIds(rig)) {
        refuseProjectOutsideCurrentWorkspace(
          projectId: projectId,
          places: _readPlaces(rig),
        );
      }
      await closeWorkspaceWorkRig(rig);
    }
  });

  test('test_refuse_project_outside_current_workspace_property_names_both_'
      'places', () async {
    final Random random = seededRandom(78305);
    for (int i = 0; i < _iterations; i += 1) {
      final WorkspaceWorkRig rig = await _buildSwitchedRig(random);
      final ProjectId? outside = pickOutsideWorkProjectId(random, rig);
      final WorkspaceId current = rig.workspaces.currentWorkspace().id;

      if (outside != null) {
        expect(
          () => refuseProjectOutsideCurrentWorkspace(
            projectId: outside,
            places: _readPlaces(rig),
          ),
          throwsA(
            isA<StateError>().having(
              (StateError error) => error.message,
              'message',
              'project ${outside.value} is not part of workspace '
                  '${current.value}',
            ),
          ),
        );
      }
      await closeWorkspaceWorkRig(rig);
    }
  });

  test('test_refuse_project_outside_current_workspace_property_unknown_'
      'project_is_not_found', () async {
    final Random random = seededRandom(78306);
    for (int i = 0; i < _iterations; i += 1) {
      final WorkspaceWorkRig rig = await _buildSwitchedRig(random);
      final ProjectId unknown = ProjectId('unknown-${randomText(random)}');

      expect(
        () => refuseProjectOutsideCurrentWorkspace(
          projectId: unknown,
          places: _readPlaces(rig),
        ),
        throwsA(
          isA<RecordNotFound>()
              .having((RecordNotFound error) => error.kind, 'kind', 'project')
              .having(
                (RecordNotFound error) => error.identifier,
                'identifier',
                unknown.value,
              ),
        ),
      );
      expect(
        rig.projects.map((Project project) => project.id),
        isNot(contains(unknown)),
      );
      await closeWorkspaceWorkRig(rig);
    }
  });
}
