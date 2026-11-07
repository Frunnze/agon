import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/models/workspace.dart';

import '../../support/random_inputs.dart';
import 'support/project_work_inputs.dart';
import 'support/workspace_inputs.dart';
import 'support/workspace_world_inputs.dart';
import 'support/workspace_world_models.dart';
import 'support/workspace_world_visibility.dart';

List<ProjectId> _listProjectIds(WorkspaceWorld world) {
  final List<ProjectId> projectIds = <ProjectId>[];
  for (final Project project in world.projects) {
    final List<Project> listed = world.projectRepository.listProjects(
      project.workspaceId,
    );
    if (listed.any((Project stored) => stored.id == project.id)) {
      projectIds.add(project.id);
    }
  }
  return projectIds;
}

List<WorkflowId> _listWorkflowIds(WorkspaceWorld world) {
  return <WorkflowId>[
    for (final Workflow workflow in world.workflowRepository.listWorkflows())
      workflow.id,
  ];
}

FakeWorkspaceRepository _buildUnlinkedCopy(
  Random random,
  WorkspaceWorld world,
) {
  final List<Workspace> workspaces = world.workspaceRepository
      .listWorkspaces();
  return buildWorkspaceRepository(
    workspaces: workspaces,
    currentWorkspaceId: workspaces.first.id,
    appServerGroup: randomAppServerGroup(random),
  );
}

void main() {
  test('test_refuse_running_work_property_matches_the_server_rule', () {
    final Random random = seededRandom(72401);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkspaceWorld world = buildWorkspaceWorld(random);
      for (final Workspace workspace
          in world.workspaceRepository.listWorkspaces()) {
        final bool isRunning = isRunningLikeServer(
          world.work,
          listWorldProjectsIn(world, workspace.id),
        );

        if (isRunning) {
          expect(
            () => world.contents.refuseRunningWork(workspace),
            throwsA(
              isA<StateError>().having(
                (StateError refusal) => refusal.message,
                'message',
                contains(workspace.name),
              ),
            ),
          );
        } else {
          world.contents.refuseRunningWork(workspace);
        }
      }
    }
  });

  test('test_refuse_running_work_property_changes_nothing', () {
    final Random random = seededRandom(72402);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkspaceWorld world = buildWorkspaceWorld(random);
      final Workspace workspace = pickOne(
        random,
        world.workspaceRepository.listWorkspaces(),
      );

      final bool isRunning = isRunningLikeServer(
        world.work,
        listWorldProjectsIn(world, workspace.id),
      );
      if (isRunning) {
        expect(
          () => world.contents.refuseRunningWork(workspace),
          throwsStateError,
        );
      } else {
        world.contents.refuseRunningWork(workspace);
      }

      expect(_listProjectIds(world), hasLength(workProjectIds.length));
      expect(
        listWorkIds(world.taskRepository),
        hasLength(world.work.tasks.length),
      );
    }
  });

  test('test_refuse_running_work_property_workspace_without_projects_is_'
      'never_refused', () {
    final Random random = seededRandom(72403);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkspaceWorld world = buildWorkspaceWorld(random);
      final Workspace empty = buildSampleWorkspace(random, 99);

      world.contents.refuseRunningWork(empty);
    }
  });

  test('test_remove_contents_property_matches_the_server_rule', () async {
    final Random random = seededRandom(72404);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorldWithIdle picked = buildWorldWithIdleWorkspace(random);
      final WorkspaceWorld world = picked.world;
      final WorkspaceId deleted = picked.idle.id;
      final Set<WorkspaceId> remaining = listOtherWorkspaceIds(world, deleted);
      final Set<ProjectId> removed = listWorldProjectsIn(world, deleted);

      await world.contents.removeContents(
        deletedWorkspaceId: deleted,
        remainingWorkspaceIds: remaining,
      );

      expect(
        _listProjectIds(world),
        expectProjectsAfterDeleting(world, deleted),
      );
      expect(
        listWorkIds(world.taskRepository),
        expectWorkAfterDeleting(world, removed),
      );
      await expectSkillsListedInEachWorkspace(
        world,
        predictSkillsKeptAfterDeleting(world.skills, deleted, remaining),
      );
      await expectWorkflowsListedInEachWorkspace(
        world,
        expectWorkflowsAfterDeleting(world, removed, remaining),
      );
    }
  });

  test('test_remove_contents_property_is_idempotent', () async {
    final Random random = seededRandom(72405);

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
      final List<ProjectId> projectsOnce = _listProjectIds(world);
      final List<WorkflowId> workflowsOnce = _listWorkflowIds(world);
      final List<LibraryEntry> skillsOnce = describeSkillEntries(
        world.skillRepository.listSkills(),
      );
      await world.contents.removeContents(
        deletedWorkspaceId: picked.idle.id,
        remainingWorkspaceIds: remaining,
      );

      expect(_listProjectIds(world), projectsOnce);
      expect(_listWorkflowIds(world), workflowsOnce);
      expect(
        describeSkillEntries(world.skillRepository.listSkills()),
        skillsOnce,
      );
    }
  });

  test('test_link_contents_property_unlinked_deletes_only_the_'
      'workspace', () async {
    final Random random = seededRandom(72406);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkspaceWorld world = buildWorkspaceWorld(random);
      final FakeWorkspaceRepository unlinked = _buildUnlinkedCopy(
        random,
        world,
      );
      final Workspace doomed = pickOne(random, unlinked.listWorkspaces());

      await unlinked.deleteWorkspace(doomed.id);

      expect(_listProjectIds(world), hasLength(workProjectIds.length));
      expect(
        listWorkIds(world.taskRepository),
        hasLength(world.work.tasks.length),
      );
      await expectWorkflowsListedInEachWorkspace(world, <WorkflowId>[
        for (final Workflow workflow in world.workflows) workflow.id,
      ]);
    }
  });

  test('test_link_contents_property_cascades_into_the_linked_'
      'contents', () async {
    final Random random = seededRandom(72407);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorldWithIdle picked = buildWorldWithIdleWorkspace(random);
      final WorkspaceWorld world = picked.world;
      final FakeWorkspaceRepository copy = _buildUnlinkedCopy(random, world);
      copy.linkContents(world.contents);

      await copy.deleteWorkspace(picked.idle.id);

      expect(
        _listProjectIds(world),
        expectProjectsAfterDeleting(world, picked.idle.id),
      );
    }
  });

  test('test_link_contents_property_the_latest_link_wins', () async {
    final Random random = seededRandom(72408);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorldWithIdle picked = buildWorldWithIdleWorkspace(random);
      final WorkspaceWorld replaced = buildWorkspaceWorld(random);
      final FakeWorkspaceRepository copy = _buildUnlinkedCopy(
        random,
        picked.world,
      );
      copy.linkContents(replaced.contents);
      copy.linkContents(picked.world.contents);

      await copy.deleteWorkspace(picked.idle.id);

      expect(_listProjectIds(replaced), hasLength(workProjectIds.length));
      expect(
        _listProjectIds(picked.world),
        expectProjectsAfterDeleting(picked.world, picked.idle.id),
      );
    }
  });
}
