import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/repository/project_repository.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';
import 'package:agent_orchestration/presentation/scope_catalog.dart';

ScopeCatalog collectScopeCatalog({
  required WorkspaceRepository workspaceRepository,
  required ProjectRepository projectRepository,
}) {
  final List<Workspace> workspaces = workspaceRepository.listWorkspaces();
  final List<Project> projects = <Project>[
    for (final Workspace workspace in workspaces)
      ...projectRepository.listProjects(workspace.id),
  ];

  return ScopeCatalog(workspaces: workspaces, projects: projects);
}
