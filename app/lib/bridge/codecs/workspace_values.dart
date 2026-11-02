import 'package:agent_orchestration/bridge/codecs/identifier_codecs.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

enum AgentAccess implements WireNamed {
  readOnly('read_only'),
  pushAfterApproval('push_after_approval');

  const AgentAccess(this.wireName);

  @override
  final String wireName;

  static AgentAccess decode(Object? json) => decodeWireName(values, json);
}

final class Workspace implements JsonEncodable {
  const Workspace({
    required this.id,
    required this.name,
    required this.appServerAddress,
  });

  factory Workspace.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    return Workspace(
      id: readField(fields, 'id', decodeWorkspaceId),
      name: readField(fields, 'name', decodeText),
      appServerAddress: readField(fields, 'app_server_address', decodeText),
    );
  }

  final WorkspaceId id;
  final String name;
  final String appServerAddress;

  @override
  JsonObject toJson() {
    return <String, Object?>{
      'id': id.value,
      'name': name,
      'app_server_address': appServerAddress,
    };
  }
}

final class Repository implements JsonEncodable {
  const Repository({
    required this.address,
    required this.defaultBranch,
    required this.agentAccess,
  });

  factory Repository.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    return Repository(
      address: readField(fields, 'address', decodeText),
      defaultBranch: readField(fields, 'default_branch', decodeText),
      agentAccess: readField(fields, 'agent_access', AgentAccess.decode),
    );
  }

  final String address;
  final String defaultBranch;
  final AgentAccess agentAccess;

  @override
  JsonObject toJson() {
    return <String, Object?>{
      'address': address,
      'default_branch': defaultBranch,
      'agent_access': agentAccess.wireName,
    };
  }
}

final class CheckedLocalFolder {
  const CheckedLocalFolder({
    required this.address,
    required this.defaultBranch,
  });

  factory CheckedLocalFolder.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    return CheckedLocalFolder(
      address: readField(fields, 'address', decodeText),
      defaultBranch: readField(fields, 'default_branch', decodeText),
    );
  }

  final String address;
  final String defaultBranch;
}

final class Project implements JsonEncodable {
  Project({
    required this.id,
    required this.workspaceId,
    required this.name,
    required List<Repository> repositories,
  }) : repositories = List<Repository>.unmodifiable(repositories);

  factory Project.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    return Project(
      id: readField(fields, 'id', decodeProjectId),
      workspaceId: readField(fields, 'workspace_id', decodeWorkspaceId),
      name: readField(fields, 'name', decodeText),
      repositories: readListField(fields, 'repositories', Repository.fromJson),
    );
  }

  final ProjectId id;
  final WorkspaceId workspaceId;
  final String name;
  final List<Repository> repositories;

  @override
  JsonObject toJson() {
    return <String, Object?>{
      'id': id.value,
      'workspace_id': workspaceId.value,
      'name': name,
      'repositories': encodeList(repositories),
    };
  }
}

sealed class WorkspaceScope implements JsonEncodable {
  const WorkspaceScope();

  factory WorkspaceScope.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    final String kind = readField(fields, 'kind', decodeText);
    return switch (kind) {
      AllWorkspaces.kind => const AllWorkspaces(),
      OnlyWorkspaces.kind => OnlyWorkspaces(
        workspaces: readListField(fields, 'workspaces', decodeWorkspaceId),
      ),
      _ => throw FormatException('unknown workspace scope $kind'),
    };
  }
}

final class AllWorkspaces extends WorkspaceScope {
  const AllWorkspaces();

  static const String kind = 'all_workspaces';

  @override
  JsonObject toJson() => <String, Object?>{'kind': kind};
}

final class OnlyWorkspaces extends WorkspaceScope {
  OnlyWorkspaces({required List<WorkspaceId> workspaces})
    : workspaces = List<WorkspaceId>.unmodifiable(workspaces);

  static const String kind = 'only_workspaces';

  final List<WorkspaceId> workspaces;

  @override
  JsonObject toJson() {
    return <String, Object?>{'kind': kind, 'workspaces': workspaces};
  }
}

sealed class ProjectScope implements JsonEncodable {
  const ProjectScope();

  factory ProjectScope.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    final String kind = readField(fields, 'kind', decodeText);
    return switch (kind) {
      AllProjects.kind => const AllProjects(),
      OnlyProjects.kind => OnlyProjects(
        projects: readListField(fields, 'projects', decodeProjectId),
      ),
      _ => throw FormatException('unknown project scope $kind'),
    };
  }
}

final class AllProjects extends ProjectScope {
  const AllProjects();

  static const String kind = 'all_projects';

  @override
  JsonObject toJson() => <String, Object?>{'kind': kind};
}

final class OnlyProjects extends ProjectScope {
  OnlyProjects({required List<ProjectId> projects})
    : projects = List<ProjectId>.unmodifiable(projects);

  static const String kind = 'only_projects';

  final List<ProjectId> projects;

  @override
  JsonObject toJson() {
    return <String, Object?>{'kind': kind, 'projects': projects};
  }
}

final class Scope implements JsonEncodable {
  const Scope({required this.workspaces, required this.projects});

  factory Scope.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    return Scope(
      workspaces: readField(fields, 'workspaces', WorkspaceScope.fromJson),
      projects: readField(fields, 'projects', ProjectScope.fromJson),
    );
  }

  final WorkspaceScope workspaces;
  final ProjectScope projects;

  @override
  JsonObject toJson() {
    return <String, Object?>{
      'workspaces': workspaces.toJson(),
      'projects': projects.toJson(),
    };
  }
}
