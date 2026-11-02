import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/presentation/scope_catalog.dart';

final class ScopeSelection {
  ScopeSelection({
    required List<WorkspaceId> workspaceIds,
    required List<ProjectId> projectIds,
  }) : workspaceIds = List<WorkspaceId>.unmodifiable(workspaceIds),
       projectIds = List<ProjectId>.unmodifiable(projectIds);

  factory ScopeSelection.everywhere() {
    return ScopeSelection(
      workspaceIds: const <WorkspaceId>[],
      projectIds: const <ProjectId>[],
    );
  }

  factory ScopeSelection.fromScope(Scope scope) {
    final List<WorkspaceId> workspaceIds = switch (scope.workspaces) {
      AllWorkspaces() => const <WorkspaceId>[],
      OnlyWorkspaces(:final List<WorkspaceId> workspaces) => workspaces,
    };
    final List<ProjectId> projectIds = switch (scope.projects) {
      AllProjects() => const <ProjectId>[],
      OnlyProjects(:final List<ProjectId> projects) => projects,
    };

    return ScopeSelection(workspaceIds: workspaceIds, projectIds: projectIds);
  }

  final List<WorkspaceId> workspaceIds;
  final List<ProjectId> projectIds;

  Scope toScope() {
    final WorkspaceScope workspaces = workspaceIds.isEmpty
        ? const AllWorkspaces()
        : OnlyWorkspaces(workspaceIds);
    final ProjectScope projects = projectIds.isEmpty
        ? const AllProjects()
        : OnlyProjects(projectIds);

    return Scope(workspaces: workspaces, projects: projects);
  }

  ScopeSelection withWorkspace(WorkspaceId workspaceId, ScopeCatalog catalog) {
    if (workspaceIds.contains(workspaceId)) {
      return this;
    }

    return _keepProjectsWithin(<WorkspaceId>[
      ...workspaceIds,
      workspaceId,
    ], catalog);
  }

  ScopeSelection withoutWorkspace(
    WorkspaceId workspaceId,
    ScopeCatalog catalog,
  ) {
    final List<WorkspaceId> remaining = <WorkspaceId>[
      for (final WorkspaceId candidate in workspaceIds)
        if (candidate != workspaceId) candidate,
    ];

    return _keepProjectsWithin(remaining, catalog);
  }

  ScopeSelection withProject(ProjectId projectId, ScopeCatalog catalog) {
    final bool isWithinWorkspaces = catalog
        .listProjectsIn(workspaceIds)
        .any((Project project) => project.id == projectId);
    if (!isWithinWorkspaces) {
      throw ArgumentError.value(
        projectId,
        'projectId',
        'Only projects of the chosen workspaces can be added',
      );
    }
    if (projectIds.contains(projectId)) {
      return this;
    }

    return ScopeSelection(
      workspaceIds: workspaceIds,
      projectIds: <ProjectId>[...projectIds, projectId],
    );
  }

  ScopeSelection withoutProject(ProjectId projectId) {
    final List<ProjectId> remaining = <ProjectId>[
      for (final ProjectId candidate in projectIds)
        if (candidate != projectId) candidate,
    ];

    return ScopeSelection(workspaceIds: workspaceIds, projectIds: remaining);
  }

  ScopeSelection _keepProjectsWithin(
    List<WorkspaceId> nextWorkspaceIds,
    ScopeCatalog catalog,
  ) {
    final Set<ProjectId> allowedProjectIds = <ProjectId>{
      for (final Project project in catalog.listProjectsIn(nextWorkspaceIds))
        project.id,
    };
    final List<ProjectId> keptProjectIds = <ProjectId>[
      for (final ProjectId projectId in projectIds)
        if (allowedProjectIds.contains(projectId)) projectId,
    ];

    return ScopeSelection(
      workspaceIds: nextWorkspaceIds,
      projectIds: keptProjectIds,
    );
  }
}
