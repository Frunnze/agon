import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/models/workflow.dart';

import 'workspace_scope_inputs.dart';
import 'workspace_skill_inputs.dart';
import 'workspace_world_inputs.dart';
import 'workspace_world_models.dart';

List<Skill> predictSkillsKeptAfterDeleting(
  List<Skill> skills,
  WorkspaceId deleted,
  Set<WorkspaceId> remaining,
) {
  final List<Skill> kept = <Skill>[];
  for (final Skill skill in skills) {
    final Scope scope = predictScopeAfterForget(skill.scope, deleted);
    if (!isModelSeenInNoWorkspace(scope.workspaces, remaining)) {
      kept.add(withSkillScope(skill, scope));
    }
  }
  return kept;
}

Future<void> expectSkillsListedInEachWorkspace(
  WorkspaceWorld world,
  List<Skill> stored,
) async {
  for (final WorkspaceId workspaceId in listWorldWorkspaceIds(
    world.workspaceRepository,
  )) {
    await world.workspaceRepository.switchWorkspace(workspaceId);
    final List<Skill> usable = <Skill>[
      for (final Skill skill in stored)
        if (isModelUsableInWorkspace(skill.scope.workspaces, workspaceId))
          skill,
    ];

    expect(
      describeSkillEntries(world.skillRepository.listSkills()),
      describeSkillEntries(usable),
      reason: 'skills in ${workspaceId.value}',
    );
  }
}

Future<void> expectWorkflowsListedInEachWorkspace(
  WorkspaceWorld world,
  List<WorkflowId> stored,
) async {
  for (final WorkspaceId workspaceId in listWorldWorkspaceIds(
    world.workspaceRepository,
  )) {
    await world.workspaceRepository.switchWorkspace(workspaceId);
    final List<WorkflowId> usable = <WorkflowId>[
      for (final Workflow workflow in world.workflows)
        if (stored.contains(workflow.id) &&
            isModelUsableInWorkspace(workflow.availability, workspaceId))
          workflow.id,
    ];

    expect(
      <WorkflowId>[
        for (final Workflow workflow
            in world.workflowRepository.listWorkflows())
          workflow.id,
      ],
      usable,
      reason: 'workflows in ${workspaceId.value}',
    );
  }
}
