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

Scope forgetProjectsInScope(Scope scope, Set<ProjectId> projectIds) {
  final ProjectScope projects = scope.projects;
  switch (projects) {
    case AllProjects():
      return scope;
    case OnlyProjects():
      final List<ProjectId> keptProjects = <ProjectId>[
        for (final ProjectId projectId in projects.projects)
          if (!projectIds.contains(projectId)) projectId,
      ];
      return Scope(
        workspaces: scope.workspaces,
        projects: OnlyProjects(keptProjects),
      );
  }
}
