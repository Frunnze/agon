import 'dart:math';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/models/workspace.dart';

import '../../../support/sample_scopes.dart';

const WorkspaceId neverMadeWorkspaceId = WorkspaceId('workspace-never-made');
const int _largestWorkspaceIdCount = 4;

List<WorkspaceId> listWorkspaceIds(List<Workspace> workspaces) {
  final List<WorkspaceId> workspaceIds = <WorkspaceId>[];
  for (final Workspace workspace in workspaces) {
    workspaceIds.add(workspace.id);
  }
  return workspaceIds;
}

List<WorkspaceId> randomWorkspaceIds(Random random) {
  final int count = 1 + random.nextInt(_largestWorkspaceIdCount);
  return <WorkspaceId>[
    for (int i = 0; i < count; i += 1) WorkspaceId('workspace-$i'),
  ];
}

WorkspaceScope randomWorkspaceScopeOver(
  Random random,
  List<WorkspaceId> workspaceIds,
) {
  if (random.nextInt(3) == 0) {
    return const AllWorkspaces();
  }
  final List<WorkspaceId> candidates = <WorkspaceId>[
    ...workspaceIds,
    neverMadeWorkspaceId,
  ];
  final List<WorkspaceId> picked = pickSome(random, candidates);
  picked.shuffle(random);
  return OnlyWorkspaces(picked);
}

Scope randomScopeOver(Random random, List<WorkspaceId> workspaceIds) {
  return Scope(
    workspaces: randomWorkspaceScopeOver(random, workspaceIds),
    projects: randomProjectScope(random),
  );
}

bool isModelUsableInWorkspace(
  WorkspaceScope workspaces,
  WorkspaceId workspaceId,
) {
  if (workspaces is OnlyWorkspaces) {
    return workspaces.workspaces.contains(workspaceId);
  }
  return true;
}

Scope predictScopeAfterForget(Scope scope, WorkspaceId deletedWorkspaceId) {
  final WorkspaceScope workspaces = scope.workspaces;
  if (workspaces is! OnlyWorkspaces) {
    return scope;
  }
  final List<WorkspaceId> kept = <WorkspaceId>[];
  for (final WorkspaceId listedId in workspaces.workspaces) {
    if (listedId != deletedWorkspaceId) {
      kept.add(listedId);
    }
  }
  return Scope(workspaces: OnlyWorkspaces(kept), projects: scope.projects);
}

bool isModelSeenInNoWorkspace(
  WorkspaceScope workspaces,
  Set<WorkspaceId> knownWorkspaceIds,
) {
  if (workspaces is! OnlyWorkspaces) {
    return false;
  }
  for (final WorkspaceId listedId in workspaces.workspaces) {
    if (knownWorkspaceIds.contains(listedId)) {
      return false;
    }
  }
  return true;
}

Set<WorkspaceId> randomRemainingWorkspaceIds(
  Random random, {
  required List<WorkspaceId> workspaceIds,
  required WorkspaceId deletedWorkspaceId,
}) {
  final List<WorkspaceId> others = <WorkspaceId>[
    for (final WorkspaceId workspaceId in workspaceIds)
      if (workspaceId != deletedWorkspaceId) workspaceId,
  ];
  if (random.nextBool()) {
    return others.toSet();
  }
  return pickSome(random, others).toSet();
}
