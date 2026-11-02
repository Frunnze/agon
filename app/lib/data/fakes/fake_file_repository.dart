import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/repository_files.dart';
import 'package:agent_orchestration/data/repository/file_repository.dart';

const String _pathSeparator = '/';
const String _rootFolder = '';

final class FakeRepositoryFile {
  const FakeRepositoryFile({
    required this.repositoryAddress,
    required this.path,
    required this.size,
    required this.preview,
  });

  final String repositoryAddress;
  final String path;
  final int size;
  final FilePreview preview;
}

final class FakeFileRepository implements FileRepository {
  FakeFileRepository({
    required Map<String, RepositoryFileSource> sources,
    required List<FakeRepositoryFile> files,
  }) : _sources = Map<String, RepositoryFileSource>.unmodifiable(sources),
       _files = List<FakeRepositoryFile>.unmodifiable(files);

  final Map<String, RepositoryFileSource> _sources;
  final List<FakeRepositoryFile> _files;

  @override
  Future<RepositoryFileSource> openRepository({
    required ProjectId projectId,
    required String repositoryAddress,
  }) async {
    final RepositoryFileSource? source = _sources[repositoryAddress];
    if (source == null) {
      return FilesWithoutRunner(holders: const <RepositoryHolder>[]);
    }
    return source;
  }

  @override
  Future<List<RepositoryEntry>> listFolder({
    required RepositoryBranchLocation location,
    required String folder,
  }) async {
    final String prefix = folder == _rootFolder
        ? _rootFolder
        : '$folder$_pathSeparator';
    final Map<String, RepositoryEntry> folders = <String, RepositoryEntry>{};
    final List<RepositoryEntry> files = <RepositoryEntry>[];

    for (final FakeRepositoryFile file in _files) {
      final bool isInside =
          file.repositoryAddress == location.repositoryAddress &&
          file.path.startsWith(prefix);
      if (!isInside) {
        continue;
      }
      final String rest = file.path.substring(prefix.length);
      final int separatorIndex = rest.indexOf(_pathSeparator);
      if (separatorIndex < 0) {
        files.add(_describeFile(rest, file.size));
      } else {
        final String name = rest.substring(0, separatorIndex);
        folders[name] = _describeFolder(name);
      }
    }

    if (folder != _rootFolder && folders.isEmpty && files.isEmpty) {
      throw StateError('the folder $folder does not exist');
    }
    return List<RepositoryEntry>.unmodifiable(<RepositoryEntry>[
      ..._sortByName(folders.values.toList()),
      ..._sortByName(files),
    ]);
  }

  @override
  Future<RepositoryFile> readFile({
    required RepositoryBranchLocation location,
    required String path,
  }) async {
    for (final FakeRepositoryFile file in _files) {
      final bool isRequested =
          file.repositoryAddress == location.repositoryAddress &&
          file.path == path;
      if (isRequested) {
        return RepositoryFile(
          path: file.path,
          size: file.size,
          preview: file.preview,
        );
      }
    }
    throw StateError('the file $path does not exist');
  }
}

RepositoryEntry _describeFile(String name, int size) {
  return RepositoryEntry(
    name: name,
    kind: RepositoryEntryKind.file,
    size: size,
  );
}

RepositoryEntry _describeFolder(String name) {
  return RepositoryEntry(
    name: name,
    kind: RepositoryEntryKind.folder,
    size: null,
  );
}

List<RepositoryEntry> _sortByName(List<RepositoryEntry> entries) {
  final List<RepositoryEntry> sorted = List<RepositoryEntry>.of(entries);
  sorted.sort(_compareNames);
  return sorted;
}

int _compareNames(RepositoryEntry first, RepositoryEntry second) {
  final int ignoringCase = first.name.toLowerCase().compareTo(
    second.name.toLowerCase(),
  );
  if (ignoringCase != 0) {
    return ignoringCase;
  }
  return first.name.compareTo(second.name);
}
