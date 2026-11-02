import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/scope.dart';

bool includesWorkspace(WorkspaceScope workspaces, WorkspaceId workspaceId) {
  switch (workspaces) {
    case AllWorkspaces():
      return true;
    case OnlyWorkspaces():
      return workspaces.workspaces.contains(workspaceId);
  }
}

bool includesProject(ProjectScope projects, ProjectId projectId) {
  switch (projects) {
    case AllProjects():
      return true;
    case OnlyProjects():
      return projects.projects.contains(projectId);
  }
}

bool doesScopeApply({
  required Scope scope,
  required WorkspaceId workspaceId,
  required ProjectId projectId,
}) {
  final bool coversWorkspace = includesWorkspace(
    scope.workspaces,
    workspaceId,
  );
  final bool coversProject = includesProject(scope.projects, projectId);

  return coversWorkspace && coversProject;
}
