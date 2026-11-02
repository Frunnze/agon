import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

const String _workspaceKind = 'workspace';
const String _projectKind = 'project';

final class ScopeCatalog {
  ScopeCatalog({
    required List<Workspace> workspaces,
    required List<Project> projects,
  }) : workspaces = List<Workspace>.unmodifiable(workspaces),
       projects = List<Project>.unmodifiable(projects);

  final List<Workspace> workspaces;
  final List<Project> projects;

  String nameOfWorkspace(WorkspaceId workspaceId) {
    return findRecord(
      workspaces,
      matches: (Workspace workspace) => workspace.id == workspaceId,
      kind: _workspaceKind,
      identifier: workspaceId.value,
    ).name;
  }

  String nameOfProject(ProjectId projectId) {
    return findRecord(
      projects,
      matches: (Project project) => project.id == projectId,
      kind: _projectKind,
      identifier: projectId.value,
    ).name;
  }

  WorkspaceId findWorkspaceId(String workspaceName) {
    return findRecord(
      workspaces,
      matches: (Workspace workspace) => workspace.name == workspaceName,
      kind: _workspaceKind,
      identifier: workspaceName,
    ).id;
  }

  ProjectId findProjectId(String projectName) {
    return findRecord(
      projects,
      matches: (Project project) => project.name == projectName,
      kind: _projectKind,
      identifier: projectName,
    ).id;
  }

  List<Project> listProjectsIn(List<WorkspaceId> workspaceIds) {
    if (workspaceIds.isEmpty) {
      return projects;
    }

    return <Project>[
      for (final Project project in projects)
        if (workspaceIds.contains(project.workspaceId)) project,
    ];
  }
}
