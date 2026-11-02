import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/presentation/scope_catalog.dart';

const String _everywhereLabel = 'Everywhere';
const String _allProjectsLabel = 'all projects';
const String _nameSeparator = ', ';
const String _partSeparator = ' · ';

List<String> _nameWorkspaces(WorkspaceScope workspaces, ScopeCatalog catalog) {
  switch (workspaces) {
    case AllWorkspaces():
      return const <String>[];
    case OnlyWorkspaces():
      return <String>[
        for (final WorkspaceId workspaceId in workspaces.workspaces)
          catalog.nameOfWorkspace(workspaceId),
      ];
  }
}

List<String> _nameProjects(ProjectScope projects, ScopeCatalog catalog) {
  switch (projects) {
    case AllProjects():
      return const <String>[];
    case OnlyProjects():
      return <String>[
        for (final ProjectId projectId in projects.projects)
          catalog.nameOfProject(projectId),
      ];
  }
}

List<String> describeScopeChips(Scope scope, ScopeCatalog catalog) {
  final List<String> chips = <String>[
    ..._nameWorkspaces(scope.workspaces, catalog),
    ..._nameProjects(scope.projects, catalog),
  ];

  if (chips.isEmpty) {
    return const <String>[_everywhereLabel];
  }
  return chips;
}

String describeScopeLine(Scope scope, ScopeCatalog catalog) {
  final List<String> workspaceNames = _nameWorkspaces(
    scope.workspaces,
    catalog,
  );
  final List<String> projectNames = _nameProjects(scope.projects, catalog);
  final List<String> parts = <String>[];

  if (workspaceNames.isNotEmpty) {
    parts.add(workspaceNames.join(_nameSeparator));
  }
  if (projectNames.isNotEmpty) {
    parts.add(projectNames.join(_nameSeparator));
  } else if (workspaceNames.isNotEmpty) {
    parts.add(_allProjectsLabel);
  }

  if (parts.isEmpty) {
    return _everywhereLabel;
  }
  return parts.join(_partSeparator);
}
