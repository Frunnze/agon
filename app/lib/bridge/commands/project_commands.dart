import 'package:agent_orchestration/bridge/codecs/approval_values.dart';
import 'package:agent_orchestration/bridge/codecs/catalog_views.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/workspace_values.dart';
import 'package:agent_orchestration/bridge/commands/node_command.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

final class ListProjectsCommand implements NodeCommand<List<ProjectView>> {
  const ListProjectsCommand({required this.workspaceId});

  final WorkspaceId workspaceId;

  @override
  String get name => 'list_projects';

  @override
  JsonObject get arguments {
    return <String, Object?>{'workspace_id': workspaceId.value};
  }

  @override
  List<ProjectView> decodeReply(Object? okValue) {
    return decodeList(okValue, ProjectView.fromJson);
  }
}

final class CreateProjectCommand implements NodeCommand<Project> {
  CreateProjectCommand({
    required this.workspaceId,
    required this.projectName,
    required List<Repository> repositories,
    required this.approvalPolicy,
  }) : repositories = List<Repository>.unmodifiable(repositories);

  final WorkspaceId workspaceId;
  final String projectName;
  final List<Repository> repositories;
  final ApprovalPolicy? approvalPolicy;

  @override
  String get name => 'create_project';

  @override
  JsonObject get arguments {
    return <String, Object?>{
      'workspace_id': workspaceId.value,
      'name': projectName,
      'repositories': encodeList(repositories),
      'approval_policy': approvalPolicy?.wireName,
    };
  }

  @override
  Project decodeReply(Object? okValue) => Project.fromJson(okValue);
}

final class ListRepositoriesCommand implements NodeCommand<List<Repository>> {
  const ListRepositoriesCommand({required this.projectId});

  final ProjectId projectId;

  @override
  String get name => 'list_repositories';

  @override
  JsonObject get arguments {
    return <String, Object?>{'project_id': projectId.value};
  }

  @override
  List<Repository> decodeReply(Object? okValue) {
    return decodeList(okValue, Repository.fromJson);
  }
}

final class CreateRepositoryCommand implements NodeCommand<Repository> {
  const CreateRepositoryCommand({
    required this.projectId,
    required this.repository,
  });

  final ProjectId projectId;
  final Repository repository;

  @override
  String get name => 'create_repository';

  @override
  JsonObject get arguments {
    return <String, Object?>{
      'project_id': projectId.value,
      'repository': repository.toJson(),
    };
  }

  @override
  Repository decodeReply(Object? okValue) => Repository.fromJson(okValue);
}

final class RemoveRepositoryCommand implements NodeCommand<List<Repository>> {
  const RemoveRepositoryCommand({
    required this.projectId,
    required this.address,
  });

  final ProjectId projectId;
  final String address;

  @override
  String get name => 'remove_repository';

  @override
  JsonObject get arguments {
    return <String, Object?>{
      'project_id': projectId.value,
      'address': address,
    };
  }

  @override
  List<Repository> decodeReply(Object? okValue) {
    return decodeList(okValue, Repository.fromJson);
  }
}

final class CheckLocalFolderCommand
    implements NodeCommand<CheckedLocalFolder> {
  const CheckLocalFolderCommand({required this.path});

  final String path;

  @override
  String get name => 'check_local_folder';

  @override
  JsonObject get arguments => <String, Object?>{'path': path};

  @override
  CheckedLocalFolder decodeReply(Object? okValue) {
    return CheckedLocalFolder.fromJson(okValue);
  }
}

final class CreateLocalFolderCommand
    implements NodeCommand<CheckedLocalFolder> {
  const CreateLocalFolderCommand({
    required this.parent,
    required this.folderName,
  });

  final String parent;
  final String folderName;

  @override
  String get name => 'create_local_folder';

  @override
  JsonObject get arguments {
    return <String, Object?>{'parent': parent, 'name': folderName};
  }

  @override
  CheckedLocalFolder decodeReply(Object? okValue) {
    return CheckedLocalFolder.fromJson(okValue);
  }
}
