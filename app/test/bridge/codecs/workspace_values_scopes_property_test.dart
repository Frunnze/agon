import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/workspace_values.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

import '../../support/random_inputs.dart';
import '../support/list_copy_properties.dart';
import '../support/node_json_primitives.dart';
import '../support/random_catalog_json.dart';
import '../support/tagged_wire_union_properties.dart';
import '../support/wire_codec_properties.dart';
import '../support/wire_json_edits.dart';

const String _kindField = 'kind';
const List<String> _nodeWorkspaceScopeKinds = <String>[
  'all_workspaces',
  'only_workspaces',
];
const List<String> _nodeProjectScopeKinds = <String>[
  'all_projects',
  'only_projects',
];

const List<WireCodec> _scopeCodecs = <WireCodec>[
  WireCodec(
    typeName: 'project',
    seed: 54100,
    buildJson: randomProjectJson,
    decode: Project.fromJson,
    requiredFields: <String>{'id', 'workspace_id', 'name', 'repositories'},
    optionalFields: <String>{'approval_policy'},
  ),
  WireCodec(
    typeName: 'all_workspaces',
    seed: 54110,
    buildJson: _buildAllWorkspacesJson,
    decode: WorkspaceScope.fromJson,
    requiredFields: <String>{_kindField},
    optionalFields: <String>{},
  ),
  WireCodec(
    typeName: 'only_workspaces',
    seed: 54120,
    buildJson: _buildOnlyWorkspacesJson,
    decode: WorkspaceScope.fromJson,
    requiredFields: <String>{_kindField, 'workspaces'},
    optionalFields: <String>{},
  ),
  WireCodec(
    typeName: 'all_projects',
    seed: 54130,
    buildJson: _buildAllProjectsJson,
    decode: ProjectScope.fromJson,
    requiredFields: <String>{_kindField},
    optionalFields: <String>{},
  ),
  WireCodec(
    typeName: 'only_projects',
    seed: 54140,
    buildJson: _buildOnlyProjectsJson,
    decode: ProjectScope.fromJson,
    requiredFields: <String>{_kindField, 'projects'},
    optionalFields: <String>{},
  ),
  WireCodec(
    typeName: 'scope',
    seed: 54150,
    buildJson: randomScopeJson,
    decode: Scope.fromJson,
    requiredFields: <String>{'workspaces', 'projects'},
    optionalFields: <String>{},
  ),
];

JsonObject _buildAllWorkspacesJson(Random random) {
  return <String, Object?>{_kindField: AllWorkspaces.kind};
}

JsonObject _buildOnlyWorkspacesJson(Random random) {
  return <String, Object?>{
    _kindField: OnlyWorkspaces.kind,
    'workspaces': randomUuidTexts(random),
  };
}

JsonObject _buildAllProjectsJson(Random random) {
  return <String, Object?>{_kindField: AllProjects.kind};
}

JsonObject _buildOnlyProjectsJson(Random random) {
  return <String, Object?>{
    _kindField: OnlyProjects.kind,
    'projects': randomUuidTexts(random),
  };
}

String _readWorkspaceScopeKind(JsonEncodable scope) {
  return switch (scope) {
    AllWorkspaces() => 'all_workspaces',
    OnlyWorkspaces() => 'only_workspaces',
    _ => throw StateError('not a workspace scope: $scope'),
  };
}

String _readProjectScopeKind(JsonEncodable scope) {
  return switch (scope) {
    AllProjects() => 'all_projects',
    OnlyProjects() => 'only_projects',
    _ => throw StateError('not a project scope: $scope'),
  };
}

Repository _buildRepository(Random random) {
  return Repository.fromJson(randomRepositoryJson(random));
}

Project _buildProject(Random random, List<Repository> repositories) {
  final Project template = Project.fromJson(randomProjectJson(random));
  return Project(
    id: template.id,
    workspaceId: template.workspaceId,
    name: template.name,
    repositories: repositories,
    approvalPolicy: template.approvalPolicy,
  );
}

List<Repository> _readRepositories(Project project) => project.repositories;

WorkspaceId _buildWorkspaceId(Random random) {
  return WorkspaceId(randomUuidText(random));
}

OnlyWorkspaces _buildOnlyWorkspaces(
  Random random,
  List<WorkspaceId> workspaces,
) {
  return OnlyWorkspaces(workspaces: workspaces);
}

List<WorkspaceId> _readWorkspaces(OnlyWorkspaces scope) => scope.workspaces;

ProjectId _buildProjectId(Random random) => ProjectId(randomUuidText(random));

OnlyProjects _buildOnlyProjects(Random random, List<ProjectId> projects) {
  return OnlyProjects(projects: projects);
}

List<ProjectId> _readProjects(OnlyProjects scope) => scope.projects;

void main() {
  for (final WireCodec codec in _scopeCodecs) {
    testWireDecodingProperties(codec);
    testWireEncodingProperties(codec);
  }

  testTaggedWireUnionProperties(
    const TaggedWireUnion(
      typeName: 'workspace_scope',
      seed: 54160,
      tagField: _kindField,
      nodeTags: _nodeWorkspaceScopeKinds,
      buildJson: randomWorkspaceScopeJson,
      decode: WorkspaceScope.fromJson,
      readVariantTag: _readWorkspaceScopeKind,
    ),
  );

  testTaggedWireUnionProperties(
    const TaggedWireUnion(
      typeName: 'project_scope',
      seed: 54170,
      tagField: _kindField,
      nodeTags: _nodeProjectScopeKinds,
      buildJson: randomProjectScopeJson,
      decode: ProjectScope.fromJson,
      readVariantTag: _readProjectScopeKind,
    ),
  );

  testListCopyProperties(
    const ListCopy<Project, Repository>(
      testNamePrefix: 'test_project_constructor_property_repositories',
      seed: 54180,
      buildElement: _buildRepository,
      construct: _buildProject,
      readList: _readRepositories,
    ),
  );

  testListCopyProperties(
    const ListCopy<OnlyWorkspaces, WorkspaceId>(
      testNamePrefix: 'test_only_workspaces_constructor_property_workspaces',
      seed: 54190,
      buildElement: _buildWorkspaceId,
      construct: _buildOnlyWorkspaces,
      readList: _readWorkspaces,
    ),
  );

  testListCopyProperties(
    const ListCopy<OnlyProjects, ProjectId>(
      testNamePrefix: 'test_only_projects_constructor_property_projects',
      seed: 54200,
      buildElement: _buildProjectId,
      construct: _buildOnlyProjects,
      readList: _readProjects,
    ),
  );

  test('test_scope_to_json_property_keeps_both_halves_apart', () {
    final Random random = seededRandom(54210);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkspaceScope workspaces = WorkspaceScope.fromJson(
        randomWorkspaceScopeJson(random),
      );
      final ProjectScope projects = ProjectScope.fromJson(
        randomProjectScopeJson(random),
      );
      final Scope scope = Scope(workspaces: workspaces, projects: projects);

      final Scope decodedAgain = Scope.fromJson(reencodeAsJsonText(scope));

      expect(decodedAgain.workspaces.toJson(), equals(workspaces.toJson()));
      expect(decodedAgain.projects.toJson(), equals(projects.toJson()));
    }
  });

  test('test_scope_from_json_property_rejects_swapped_halves', () {
    final Random random = seededRandom(54211);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject scopeJson = randomScopeJson(random);
      final JsonObject swappedJson = <String, Object?>{
        'workspaces': scopeJson['projects'],
        'projects': scopeJson['workspaces'],
      };

      expect(() => Scope.fromJson(swappedJson), throwsFormatException);
    }
  });
}
