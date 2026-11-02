import 'dart:convert';
import 'dart:typed_data';

import 'package:agent_orchestration/bridge/codecs/repository_file_values.dart'
    as node;
import 'package:agent_orchestration/data/models/repository_files.dart';

RepositoryHolder mapRepositoryHolderFromNode(node.RepositoryHolder holder) {
  return RepositoryHolder(
    deviceId: holder.deviceId,
    name: holder.name,
    lastSeen: holder.lastSeen,
  );
}

RepositoryFileSource mapRepositoryFileSourceFromNode(
  node.RepositoryBranchesView view,
) {
  switch (view) {
    case node.AvailableRepositoryBranches():
      return FilesFromRunner(
        runnerId: view.runner.deviceId,
        runnerName: view.runner.name,
        branches: view.branches,
        taskBranches: view.taskBranches,
      );
    case node.UnavailableRepositoryBranches():
      final List<RepositoryHolder> holders = <RepositoryHolder>[];
      for (final node.RepositoryHolder holder in view.holders) {
        holders.add(mapRepositoryHolderFromNode(holder));
      }
      return FilesWithoutRunner(holders: holders);
  }
}

RepositoryEntryKind mapRepositoryEntryKindFromNode(
  node.RepositoryEntryKind kind,
) {
  return switch (kind) {
    node.RepositoryEntryKind.folder => RepositoryEntryKind.folder,
    node.RepositoryEntryKind.file => RepositoryEntryKind.file,
    node.RepositoryEntryKind.link => RepositoryEntryKind.link,
  };
}

RepositoryEntry mapRepositoryEntryFromNode(node.RepositoryEntry entry) {
  return RepositoryEntry(
    name: entry.name,
    kind: mapRepositoryEntryKindFromNode(entry.kind),
    size: entry.size,
  );
}

FilePreview mapFilePreviewFromNode(node.FilePreview preview) {
  switch (preview) {
    case node.TextPreview(:final String text):
      return TextFilePreview(text);
    case node.ImagePreview():
      final Uint8List bytes = base64Decode(preview.base64Content);
      return ImageFilePreview(
        width: preview.width,
        height: preview.height,
        bytes: bytes,
      );
    case node.TooLargePreview():
      return const UnavailableFilePreview(PreviewUnavailableReason.tooLarge);
    case node.BinaryPreview():
      return const UnavailableFilePreview(PreviewUnavailableReason.binary);
    case node.LinkPreview():
      return const UnavailableFilePreview(PreviewUnavailableReason.link);
  }
}

RepositoryFile mapRepositoryFileFromNode(node.RepositoryFileView file) {
  return RepositoryFile(
    path: file.path,
    size: file.size,
    preview: mapFilePreviewFromNode(file.preview),
  );
}
