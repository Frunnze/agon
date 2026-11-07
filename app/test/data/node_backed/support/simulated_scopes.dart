typedef SimulatedScopedRecord = Map<String, Object?>;

const String _scopeField = 'scope';
const String _workspacesField = 'workspaces';
const String _kindField = 'kind';
const String _allWorkspacesKind = 'all_workspaces';
const String _onlyWorkspacesKind = 'only_workspaces';
const String _allProjectsKind = 'all_projects';
const String _projectsField = 'projects';

Map<String, Object?> _readWorkspaceScope(SimulatedScopedRecord record) {
  final Map<String, Object?> scope =
      record[_scopeField]! as Map<String, Object?>;
  return scope[_workspacesField]! as Map<String, Object?>;
}

bool isSimulatedScopeInWorkspace(
  SimulatedScopedRecord record,
  Object? workspaceId,
) {
  final Map<String, Object?> workspaceScope = _readWorkspaceScope(record);
  if (workspaceScope[_kindField] == _allWorkspacesKind) {
    return true;
  }
  final List<Object?> listed =
      workspaceScope[_workspacesField]! as List<Object?>;
  return listed.contains(workspaceId);
}

List<SimulatedScopedRecord> forgetSimulatedWorkspace(
  List<SimulatedScopedRecord> records, {
  required Object? deletedWorkspaceId,
  required Set<Object?> remainingWorkspaceIds,
}) {
  final List<SimulatedScopedRecord> unseenRecords = <SimulatedScopedRecord>[];
  for (final SimulatedScopedRecord record in records) {
    final Map<String, Object?> workspaceScope = _readWorkspaceScope(record);
    if (workspaceScope[_kindField] == _allWorkspacesKind) {
      continue;
    }
    final List<Object?> kept = <Object?>[
      for (final Object? listed
          in workspaceScope[_workspacesField]! as List<Object?>)
        if (listed != deletedWorkspaceId) listed,
    ];
    workspaceScope[_workspacesField] = kept;
    if (!kept.any(remainingWorkspaceIds.contains)) {
      unseenRecords.add(record);
    }
  }
  records.removeWhere(unseenRecords.contains);
  return unseenRecords;
}

void forgetSimulatedProjects(
  List<SimulatedScopedRecord> records,
  Set<Object?> deletedProjectIds,
) {
  for (final SimulatedScopedRecord record in records) {
    final Map<String, Object?> scope =
        record[_scopeField]! as Map<String, Object?>;
    final Map<String, Object?> projectScope =
        scope[_projectsField]! as Map<String, Object?>;
    if (projectScope[_kindField] == _allProjectsKind) {
      continue;
    }
    projectScope[_projectsField] = <Object?>[
      for (final Object? listed
          in projectScope[_projectsField]! as List<Object?>)
        if (!deletedProjectIds.contains(listed)) listed,
    ];
  }
}

Map<String, Object?> buildSimulatedScopeOnlyIn(String workspaceId) {
  return <String, Object?>{
    _workspacesField: <String, Object?>{
      _kindField: _onlyWorkspacesKind,
      _workspacesField: <Object?>[workspaceId],
    },
    _projectsField: <String, Object?>{_kindField: _allProjectsKind},
  };
}
