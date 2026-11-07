import 'dart:math';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/workspace_values.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

import '../../support/random_catalog_json.dart';
import 'codec_rows.dart';

const List<ConstructorRow> workspaceConstructorRows = <ConstructorRow>[
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'repository',
      buildJson: randomRepositoryJson,
      decode: Repository.fromJson,
    ),
    rebuild: _rebuildRepository,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'workspace_scope',
      buildJson: randomWorkspaceScopeJson,
      decode: WorkspaceScope.fromJson,
    ),
    rebuild: _rebuildWorkspaceScope,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'all_workspaces',
      buildJson: randomAllWorkspacesJson,
      decode: WorkspaceScope.fromJson,
    ),
    rebuild: _rebuildWorkspaceScope,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'only_workspaces',
      buildJson: randomOnlyWorkspacesJson,
      decode: WorkspaceScope.fromJson,
    ),
    rebuild: _rebuildWorkspaceScope,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'project_scope',
      buildJson: randomProjectScopeJson,
      decode: ProjectScope.fromJson,
    ),
    rebuild: _rebuildProjectScope,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'all_projects',
      buildJson: randomAllProjectsJson,
      decode: ProjectScope.fromJson,
    ),
    rebuild: _rebuildProjectScope,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'only_projects',
      buildJson: randomOnlyProjectsJson,
      decode: ProjectScope.fromJson,
    ),
    rebuild: _rebuildProjectScope,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'scope',
      buildJson: randomScopeJson,
      decode: Scope.fromJson,
    ),
    rebuild: _rebuildScope,
  ),
];

const List<EncodableRow> workspaceEncodableRows = <EncodableRow>[
  EncodableRow(
    typeName: 'workspace',
    buildJson: randomWorkspaceJson,
    decode: Workspace.fromJson,
  ),
  EncodableRow(
    typeName: 'project',
    buildJson: randomProjectJson,
    decode: Project.fromJson,
  ),
];

Object? randomAllWorkspacesJson(Random random) {
  return randomJsonOfKind<AllWorkspaces>(
    random: random,
    buildJson: randomWorkspaceScopeJson,
    decode: WorkspaceScope.fromJson,
  );
}

Object? randomOnlyWorkspacesJson(Random random) {
  return randomJsonOfKind<OnlyWorkspaces>(
    random: random,
    buildJson: randomWorkspaceScopeJson,
    decode: WorkspaceScope.fromJson,
  );
}

Object? randomAllProjectsJson(Random random) {
  return randomJsonOfKind<AllProjects>(
    random: random,
    buildJson: randomProjectScopeJson,
    decode: ProjectScope.fromJson,
  );
}

Object? randomOnlyProjectsJson(Random random) {
  return randomJsonOfKind<OnlyProjects>(
    random: random,
    buildJson: randomProjectScopeJson,
    decode: ProjectScope.fromJson,
  );
}

JsonEncodable _rebuildRepository(JsonEncodable value) {
  final Repository repository = value as Repository;
  return Repository(
    address: repository.address,
    defaultBranch: repository.defaultBranch,
    agentAccess: repository.agentAccess,
  );
}

JsonEncodable _rebuildWorkspaceScope(JsonEncodable value) {
  final WorkspaceScope scope = value as WorkspaceScope;
  return switch (scope) {
    AllWorkspaces() => const AllWorkspaces(),
    OnlyWorkspaces(:final List<WorkspaceId> workspaces) => OnlyWorkspaces(
      workspaces: workspaces,
    ),
  };
}

JsonEncodable _rebuildProjectScope(JsonEncodable value) {
  final ProjectScope scope = value as ProjectScope;
  return switch (scope) {
    AllProjects() => const AllProjects(),
    OnlyProjects(:final List<ProjectId> projects) => OnlyProjects(
      projects: projects,
    ),
  };
}

JsonEncodable _rebuildScope(JsonEncodable value) {
  final Scope scope = value as Scope;
  return Scope(workspaces: scope.workspaces, projects: scope.projects);
}
