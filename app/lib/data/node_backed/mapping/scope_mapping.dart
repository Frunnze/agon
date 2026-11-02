import 'package:agent_orchestration/bridge/codecs/workspace_values.dart'
    as node;
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/scope.dart';

WorkspaceScope mapWorkspaceScopeFromNode(node.WorkspaceScope scope) {
  return switch (scope) {
    node.AllWorkspaces() => const AllWorkspaces(),
    node.OnlyWorkspaces(:final List<WorkspaceId> workspaces) => OnlyWorkspaces(
      workspaces,
    ),
  };
}

node.WorkspaceScope mapWorkspaceScopeToNode(WorkspaceScope scope) {
  return switch (scope) {
    AllWorkspaces() => const node.AllWorkspaces(),
    OnlyWorkspaces(:final List<WorkspaceId> workspaces) => node.OnlyWorkspaces(
      workspaces: workspaces,
    ),
  };
}

ProjectScope mapProjectScopeFromNode(node.ProjectScope scope) {
  return switch (scope) {
    node.AllProjects() => const AllProjects(),
    node.OnlyProjects(:final List<ProjectId> projects) => OnlyProjects(
      projects,
    ),
  };
}

node.ProjectScope mapProjectScopeToNode(ProjectScope scope) {
  return switch (scope) {
    AllProjects() => const node.AllProjects(),
    OnlyProjects(:final List<ProjectId> projects) => node.OnlyProjects(
      projects: projects,
    ),
  };
}

Scope mapScopeFromNode(node.Scope scope) {
  return Scope(
    workspaces: mapWorkspaceScopeFromNode(scope.workspaces),
    projects: mapProjectScopeFromNode(scope.projects),
  );
}

node.Scope mapScopeToNode(Scope scope) {
  return node.Scope(
    workspaces: mapWorkspaceScopeToNode(scope.workspaces),
    projects: mapProjectScopeToNode(scope.projects),
  );
}
