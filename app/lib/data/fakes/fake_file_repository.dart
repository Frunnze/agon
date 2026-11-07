import 'dart:math';

import 'package:agent_orchestration/data/fakes/control_characters.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/repository_files.dart';
import 'package:agent_orchestration/data/repository/file_repository.dart';

const String _pathSeparator = '/';
const String _rootFolder = '';
const String _currentFolder = '.';
const String _parentFolder = '..';
const String _foreignSeparator = '\\';

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
    required DeviceId? preferredRunnerId,
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
    final String normalizedFolder = _normalizeRepositoryPath(folder);
    final String prefix = normalizedFolder == _rootFolder
        ? _rootFolder
        : '$normalizedFolder$_pathSeparator';
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

    final bool isMissing = folders.isEmpty && files.isEmpty;
    if (normalizedFolder != _rootFolder && isMissing) {
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
    final String normalizedPath = _normalizeRepositoryPath(path);
    for (final FakeRepositoryFile file in _files) {
      final bool isRequested =
          file.repositoryAddress == location.repositoryAddress &&
          file.path == normalizedPath;
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
  final int ignoringCase = _compareCodePoints(
    first.name.toLowerCase(),
    second.name.toLowerCase(),
  );
  if (ignoringCase != 0) {
    return ignoringCase;
  }
  return _compareCodePoints(first.name, second.name);
}

int _compareCodePoints(String first, String second) {
  final List<int> firstCodePoints = first.runes.toList();
  final List<int> secondCodePoints = second.runes.toList();
  final int sharedLength = min(
    firstCodePoints.length,
    secondCodePoints.length,
  );

  for (int i = 0; i < sharedLength; i += 1) {
    final int difference = firstCodePoints[i] - secondCodePoints[i];
    if (difference != 0) {
      return difference;
    }
  }
  return firstCodePoints.length - secondCodePoints.length;
}

String _normalizeRepositoryPath(String path) {
  final bool isAbsolute = path.startsWith(_pathSeparator);
  final bool hasForbiddenCharacter =
      path.contains(_foreignSeparator) || hasControlCharacter(path);
  if (isAbsolute || hasForbiddenCharacter) {
    throw StateError('the path $path cannot name a place in the repository');
  }

  final List<String> keptParts = <String>[];
  for (final String part in path.split(_pathSeparator)) {
    if (part == _parentFolder) {
      throw StateError('the path $path leaves the repository');
    }
    if (part.isNotEmpty && part != _currentFolder) {
      keptParts.add(part);
    }
  }
  return keptParts.join(_pathSeparator);
}
