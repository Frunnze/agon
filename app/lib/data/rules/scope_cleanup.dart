import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/scope.dart';

WorkspaceScope _withoutWorkspace(
  OnlyWorkspaces workspaces,
  WorkspaceId workspaceId,
) {
  final List<WorkspaceId> keptWorkspaces = <WorkspaceId>[];
  for (final WorkspaceId listedId in workspaces.workspaces) {
    if (listedId != workspaceId) {
      keptWorkspaces.add(listedId);
    }
  }
  return OnlyWorkspaces(keptWorkspaces);
}

Scope forgetWorkspaceInScope(Scope scope, WorkspaceId workspaceId) {
  final WorkspaceScope workspaces = scope.workspaces;
  switch (workspaces) {
    case AllWorkspaces():
      return scope;
    case OnlyWorkspaces():
      return Scope(
        workspaces: _withoutWorkspace(workspaces, workspaceId),
        projects: scope.projects,
      );
  }
}

bool isSeenInNoWorkspace(
  WorkspaceScope workspaces,
  Set<WorkspaceId> knownWorkspaceIds,
) {
  switch (workspaces) {
    case AllWorkspaces():
      return false;
    case OnlyWorkspaces():
      return !workspaces.workspaces.any(knownWorkspaceIds.contains);
  }
}
