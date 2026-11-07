import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';

import '../../support/random_inputs.dart';
import 'support/workspace_world_inputs.dart';

void main() {
  test('test_remove_contents_property_keeps_other_workspaces_'
      'projects', () async {
    final Random random = seededRandom(72409);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorldWithIdle picked = buildWorldWithIdleWorkspace(random);
      final WorkspaceWorld world = picked.world;
      final Set<WorkspaceId> remaining = listOtherWorkspaceIds(
        world,
        picked.idle.id,
      );

      await world.contents.removeContents(
        deletedWorkspaceId: picked.idle.id,
        remainingWorkspaceIds: remaining,
      );

      for (final WorkspaceId workspaceId in remaining) {
        expect(world.projectRepository.listProjects(workspaceId), <Project>[
          for (final Project project in world.projects)
            if (project.workspaceId == workspaceId) project,
        ]);
      }
    }
  });

  test('test_list_project_ids_property_ignores_running_work_elsewhere', () {
    final Random random = seededRandom(72410);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorldWithIdle picked = buildWorldWithIdleWorkspace(random);

      picked.world.contents.refuseRunningWork(picked.idle);
    }
  });

  test('test_list_project_ids_property_every_project_of_the_workspace_'
      'goes', () async {
    final Random random = seededRandom(72411);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorldWithIdle picked = buildWorldWithIdleWorkspace(random);
      final WorkspaceWorld world = picked.world;

      await world.contents.removeContents(
        deletedWorkspaceId: picked.idle.id,
        remainingWorkspaceIds: listOtherWorkspaceIds(world, picked.idle.id),
      );

      expect(world.projectRepository.listProjects(picked.idle.id), isEmpty);
    }
  });

  test('test_list_project_ids_property_sees_projects_created_later', () async {
    final Random random = seededRandom(72412);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorldWithIdle picked = buildWorldWithIdleWorkspace(random);
      final WorkspaceWorld world = picked.world;
      final Project created = await world.projectRepository.createProject(
        ProjectDraft(
          workspaceId: picked.idle.id,
          name: 'later-$i',
          repositories: const <Repository>[],
          approvalPolicy: null,
        ),
      );

      await world.contents.removeContents(
        deletedWorkspaceId: picked.idle.id,
        remainingWorkspaceIds: listOtherWorkspaceIds(world, picked.idle.id),
      );

      expect(
        world.projectRepository.listProjects(picked.idle.id),
        isNot(contains(created)),
      );
    }
  });
}
