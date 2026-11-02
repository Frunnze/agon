import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/repository_file_values.dart';
import 'package:agent_orchestration/bridge/commands/node_command.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

const String _projectIdField = 'project_id';
const String _repositoryAddressField = 'repository_address';
const String _runnerIdField = 'runner_id';
const String _branchField = 'branch';

final class ListRepositoryBranchesCommand
    implements NodeCommand<RepositoryBranchesView> {
  const ListRepositoryBranchesCommand({
    required this.projectId,
    required this.repositoryAddress,
  });

  final ProjectId projectId;
  final String repositoryAddress;

  @override
  String get name => 'list_repository_branches';

  @override
  JsonObject get arguments {
    return <String, Object?>{
      _projectIdField: projectId.value,
      _repositoryAddressField: repositoryAddress,
    };
  }

  @override
  RepositoryBranchesView decodeReply(Object? okValue) {
    return RepositoryBranchesView.fromJson(okValue);
  }
}

final class ListRepositoryFilesCommand
    implements NodeCommand<RepositoryFolderView> {
  const ListRepositoryFilesCommand({
    required this.projectId,
    required this.repositoryAddress,
    required this.runnerId,
    required this.branch,
    required this.folder,
  });

  final ProjectId projectId;
  final String repositoryAddress;
  final DeviceId runnerId;
  final String branch;
  final String folder;

  @override
  String get name => 'list_repository_files';

  @override
  JsonObject get arguments {
    return <String, Object?>{
      _projectIdField: projectId.value,
      _repositoryAddressField: repositoryAddress,
      _runnerIdField: runnerId.value,
      _branchField: branch,
      'folder': folder,
    };
  }

  @override
  RepositoryFolderView decodeReply(Object? okValue) {
    return RepositoryFolderView.fromJson(okValue);
  }
}

final class ReadRepositoryFileCommand
    implements NodeCommand<RepositoryFileView> {
  const ReadRepositoryFileCommand({
    required this.projectId,
    required this.repositoryAddress,
    required this.runnerId,
    required this.branch,
    required this.path,
  });

  final ProjectId projectId;
  final String repositoryAddress;
  final DeviceId runnerId;
  final String branch;
  final String path;

  @override
  String get name => 'read_repository_file';

  @override
  JsonObject get arguments {
    return <String, Object?>{
      _projectIdField: projectId.value,
      _repositoryAddressField: repositoryAddress,
      _runnerIdField: runnerId.value,
      _branchField: branch,
      'path': path,
    };
  }

  @override
  RepositoryFileView decodeReply(Object? okValue) {
    return RepositoryFileView.fromJson(okValue);
  }
}
