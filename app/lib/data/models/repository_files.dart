import 'dart:typed_data';

import 'package:agent_orchestration/data/models/identifiers.dart';

sealed class RepositoryFileSource {
  const RepositoryFileSource();
}

final class FilesFromRunner extends RepositoryFileSource {
  FilesFromRunner({
    required this.runnerId,
    required this.runnerName,
    required List<String> branches,
    required List<String> taskBranches,
  }) : branches = List<String>.unmodifiable(branches),
       taskBranches = List<String>.unmodifiable(taskBranches);

  final DeviceId runnerId;
  final String runnerName;
  final List<String> branches;
  final List<String> taskBranches;
}

final class FilesWithoutRunner extends RepositoryFileSource {
  FilesWithoutRunner({required List<RepositoryHolder> holders})
    : holders = List<RepositoryHolder>.unmodifiable(holders);

  final List<RepositoryHolder> holders;
}

final class RepositoryHolder {
  const RepositoryHolder({
    required this.deviceId,
    required this.name,
    required this.lastSeen,
  });

  final DeviceId deviceId;
  final String name;
  final DateTime lastSeen;
}

final class RepositoryBranchLocation {
  const RepositoryBranchLocation({
    required this.projectId,
    required this.repositoryAddress,
    required this.runnerId,
    required this.branch,
  });

  final ProjectId projectId;
  final String repositoryAddress;
  final DeviceId runnerId;
  final String branch;
}

enum RepositoryEntryKind { folder, file, link }

final class RepositoryEntry {
  const RepositoryEntry({
    required this.name,
    required this.kind,
    required this.size,
  });

  final String name;
  final RepositoryEntryKind kind;
  final int? size;
}

final class RepositoryFile {
  const RepositoryFile({
    required this.path,
    required this.size,
    required this.preview,
  });

  final String path;
  final int size;
  final FilePreview preview;
}

sealed class FilePreview {
  const FilePreview();
}

final class TextFilePreview extends FilePreview {
  const TextFilePreview(this.text);

  final String text;
}

final class ImageFilePreview extends FilePreview {
  const ImageFilePreview({
    required this.width,
    required this.height,
    required this.bytes,
  });

  final int width;
  final int height;
  final Uint8List bytes;
}

enum PreviewUnavailableReason { tooLarge, binary, link }

final class UnavailableFilePreview extends FilePreview {
  const UnavailableFilePreview(this.reason);

  final PreviewUnavailableReason reason;
}
