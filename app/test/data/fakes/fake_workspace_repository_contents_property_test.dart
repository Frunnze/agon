import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';

import '../../support/random_inputs.dart';
import 'support/project_work_inputs.dart';
import 'support/workspace_world_inputs.dart';
import 'support/workspace_world_models.dart';

typedef _Deletion = ({
  WorkspaceWorld world,
  WorkspaceId deleted,
  Set<WorkspaceId> remaining,
  Set<ProjectId> removedProjects,
  bool isRunning,
});

_Deletion _planDeletion(Random random) {
  final WorkspaceWorld world = buildWorkspaceWorld(random);
  final List<WorkspaceId> listed = listWorldWorkspaceIds(
    world.workspaceRepository,
  );
  final WorkspaceId deleted = pickOne(random, listed);
  final Set<ProjectId> removedProjects = listWorldProjectsIn(world, deleted);
  return (
    world: world,
    deleted: deleted,
    remaining: <WorkspaceId>{
      for (final WorkspaceId workspaceId in listed)
        if (workspaceId != deleted) workspaceId,
    },
    removedProjects: removedProjects,
    isRunning: isRunningLikeServer(world.work, removedProjects),
  );
}

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

Future<_Deletion> _deleteIdle(Random random) async {
  _Deletion deletion = _planDeletion(random);
  while (deletion.isRunning) {
    deletion = _planDeletion(random);
  }
  await deletion.world.workspaceRepository.deleteWorkspace(deletion.deleted);
  return deletion;
}

void main() {
  test('test_delete_workspace_property_refuses_running_work_and_changes_'
      'nothing', () async {
    final Random random = seededRandom(72301);
    int refusedCount = 0;

    for (int i = 0; i < propertyIterations; i += 1) {
      final _Deletion deletion = _planDeletion(random);
      if (!deletion.isRunning) {
        continue;
      }
      refusedCount += 1;
      final WorkspaceWorld world = deletion.world;
      final List<WorkspaceId> workspacesBefore = listWorldWorkspaceIds(
        world.workspaceRepository,
      );

      await expectLater(
        world.workspaceRepository.deleteWorkspace(deletion.deleted),
        throwsStateError,
      );

      expect(
        listWorldWorkspaceIds(world.workspaceRepository),
        workspacesBefore,
      );
      expect(_listProjectIds(world), <ProjectId>[
        for (final Project project in world.projects) project.id,
      ]);
      expect(listWorkIds(world.taskRepository), <TaskId>[
        for (final Task task in world.work.tasks) task.id,
      ]);
      expect(
        describeSkillEntries(world.skillRepository.listSkills()),
        describeSkillEntries(world.skills),
      );
      expect(_listWorkflowIds(world), <WorkflowId>[
        for (final Workflow workflow in world.workflows) workflow.id,
      ]);
    }
    expect(refusedCount, greaterThan(0));
  });

  test('test_delete_workspace_property_removes_its_projects_and_their_'
      'work', () async {
    final Random random = seededRandom(72302);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _Deletion deletion = await _deleteIdle(random);
      final WorkspaceWorld world = deletion.world;

      expect(
        listWorldWorkspaceIds(world.workspaceRepository),
        isNot(contains(deletion.deleted)),
      );
      expect(
        _listProjectIds(world),
        expectProjectsAfterDeleting(world, deletion.deleted),
      );
      expect(
        listWorkIds(world.taskRepository),
        expectWorkAfterDeleting(world, deletion.removedProjects),
      );
    }
  });

  test('test_delete_workspace_property_removes_library_seen_in_no_'
      'workspace', () async {
    final Random random = seededRandom(72303);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _Deletion deletion = await _deleteIdle(random);
      final WorkspaceWorld world = deletion.world;

      expect(
        describeSkillEntries(world.skillRepository.listSkills()),
        expectSkillsAfterDeleting(world, deletion.deleted, deletion.remaining),
      );
      final List<LibraryEntry> keptRules = expectRulesAfterDeleting(
        world,
        deletion.deleted,
        deletion.remaining,
      );
      for (final WorkspaceId workspaceId in deletion.remaining) {
        await world.workspaceRepository.switchWorkspace(workspaceId);
        final List<String> visibleIds = expectVisibleRuleIds(
          world,
          deletion.deleted,
          deletion.remaining,
          workspaceId,
        );
        expect(
          describeRuleEntries(world.ruleRepository.listRules()),
          <LibraryEntry>[
            for (final LibraryEntry entry in keptRules)
              if (visibleIds.contains(entry.identifier)) entry,
          ],
        );
      }
    }
  });

  test('test_delete_workspace_property_removes_unseen_unused_'
      'workflows', () async {
    final Random random = seededRandom(72304);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _Deletion deletion = await _deleteIdle(random);

      expect(
        _listWorkflowIds(deletion.world),
        expectWorkflowsAfterDeleting(
          deletion.world,
          deletion.removedProjects,
          deletion.remaining,
        ),
      );
    }
  });
}
