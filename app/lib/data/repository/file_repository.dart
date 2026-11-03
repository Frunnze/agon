import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/repository_files.dart';

abstract interface class FileRepository {
  Future<RepositoryFileSource> openRepository({
    required ProjectId projectId,
    required String repositoryAddress,
    required DeviceId? preferredRunnerId,
  });

  Future<List<RepositoryEntry>> listFolder({
    required RepositoryBranchLocation location,
    required String folder,
  });

  Future<RepositoryFile> readFile({
    required RepositoryBranchLocation location,
    required String path,
  });
}
