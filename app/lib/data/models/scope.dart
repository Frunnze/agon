import 'package:agent_orchestration/data/models/identifiers.dart';

sealed class WorkspaceScope {
  const WorkspaceScope();
}

final class AllWorkspaces extends WorkspaceScope {
  const AllWorkspaces();
}

final class OnlyWorkspaces extends WorkspaceScope {
  OnlyWorkspaces(List<WorkspaceId> workspaces)
    : workspaces = List<WorkspaceId>.unmodifiable(workspaces);

  final List<WorkspaceId> workspaces;
}

sealed class ProjectScope {
  const ProjectScope();
}

final class AllProjects extends ProjectScope {
  const AllProjects();
}

final class OnlyProjects extends ProjectScope {
  OnlyProjects(List<ProjectId> projects)
    : projects = List<ProjectId>.unmodifiable(projects);

  final List<ProjectId> projects;
}

final class Scope {
  const Scope({required this.workspaces, required this.projects});

  const Scope.everywhere()
    : workspaces = const AllWorkspaces(),
      projects = const AllProjects();

  final WorkspaceScope workspaces;
  final ProjectScope projects;
}
