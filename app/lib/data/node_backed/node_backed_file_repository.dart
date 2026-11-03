import 'package:agent_orchestration/bridge/codecs/repository_file_values.dart'
    as node;
import 'package:agent_orchestration/bridge/commands/file_commands.dart'
    as node;
import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/repository_files.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';
import 'package:agent_orchestration/data/repository/file_repository.dart';

final class NodeBackedFileRepository implements FileRepository {
  const NodeBackedFileRepository({required this.channel});

  final NodeCommandChannel channel;

  @override
  Future<RepositoryFileSource> openRepository({
    required ProjectId projectId,
    required String repositoryAddress,
    required DeviceId? preferredRunnerId,
  }) async {
    final node.RepositoryBranchesView view = await executeNodeCommand(
      channel,
      node.ListRepositoryBranchesCommand(
        projectId: projectId,
        repositoryAddress: repositoryAddress,
        preferredRunnerId: preferredRunnerId,
      ),
    );
    return mapRepositoryFileSourceFromNode(view);
  }

  @override
  Future<List<RepositoryEntry>> listFolder({
    required RepositoryBranchLocation location,
    required String folder,
  }) async {
    final node.RepositoryFolderView view = await executeNodeCommand(
      channel,
      node.ListRepositoryFilesCommand(
        projectId: location.projectId,
        repositoryAddress: location.repositoryAddress,
        runnerId: location.runnerId,
        branch: location.branch,
        folder: folder,
      ),
    );

    final List<RepositoryEntry> entries = <RepositoryEntry>[];
    for (final node.RepositoryEntry entry in view.entries) {
      entries.add(mapRepositoryEntryFromNode(entry));
    }
    return List<RepositoryEntry>.unmodifiable(entries);
  }

  @override
  Future<RepositoryFile> readFile({
    required RepositoryBranchLocation location,
    required String path,
  }) async {
    final node.RepositoryFileView view = await executeNodeCommand(
      channel,
      node.ReadRepositoryFileCommand(
        projectId: location.projectId,
        repositoryAddress: location.repositoryAddress,
        runnerId: location.runnerId,
        branch: location.branch,
        path: path,
      ),
    );
    return mapRepositoryFileFromNode(view);
  }
}
