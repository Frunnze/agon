import 'dart:math';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/repository_file_values.dart';

import '../../support/random_file_json.dart';
import 'codec_rows.dart';

const List<ConstructorRow> repositoryFileConstructorRows = <ConstructorRow>[
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'repository_branches_view',
      buildJson: randomRepositoryBranchesJson,
      decode: RepositoryBranchesView.fromJson,
    ),
    rebuild: _rebuildRepositoryBranchesView,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'available_repository_branches',
      buildJson: randomAvailableRepositoryBranchesJson,
      decode: RepositoryBranchesView.fromJson,
    ),
    rebuild: _rebuildRepositoryBranchesView,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'unavailable_repository_branches',
      buildJson: randomUnavailableRepositoryBranchesJson,
      decode: RepositoryBranchesView.fromJson,
    ),
    rebuild: _rebuildRepositoryBranchesView,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'file_runner',
      buildJson: randomFileRunnerJson,
      decode: FileRunner.fromJson,
    ),
    rebuild: _rebuildFileRunner,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'repository_holder',
      buildJson: randomRepositoryHolderJson,
      decode: RepositoryHolder.fromJson,
    ),
    rebuild: _rebuildRepositoryHolder,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'repository_entry',
      buildJson: randomRepositoryEntryJson,
      decode: RepositoryEntry.fromJson,
    ),
    rebuild: _rebuildRepositoryEntry,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'repository_folder_view',
      buildJson: randomRepositoryFolderJson,
      decode: RepositoryFolderView.fromJson,
    ),
    rebuild: _rebuildRepositoryFolderView,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'repository_file_view',
      buildJson: randomRepositoryFileJson,
      decode: RepositoryFileView.fromJson,
    ),
    rebuild: _rebuildRepositoryFileView,
  ),
];

Object? randomAvailableRepositoryBranchesJson(Random random) {
  return randomJsonOfKind<AvailableRepositoryBranches>(
    random: random,
    buildJson: randomRepositoryBranchesJson,
    decode: RepositoryBranchesView.fromJson,
  );
}

Object? randomUnavailableRepositoryBranchesJson(Random random) {
  return randomJsonOfKind<UnavailableRepositoryBranches>(
    random: random,
    buildJson: randomRepositoryBranchesJson,
    decode: RepositoryBranchesView.fromJson,
  );
}

JsonEncodable _rebuildRepositoryBranchesView(JsonEncodable value) {
  final RepositoryBranchesView branchesView = value as RepositoryBranchesView;
  return switch (branchesView) {
    AvailableRepositoryBranches(
      :final FileRunner runner,
      :final List<String> branches,
      :final List<String> taskBranches,
    ) =>
      AvailableRepositoryBranches(
        runner: runner,
        branches: branches,
        taskBranches: taskBranches,
      ),
    UnavailableRepositoryBranches(:final List<RepositoryHolder> holders) =>
      UnavailableRepositoryBranches(holders: holders),
  };
}

JsonEncodable _rebuildFileRunner(JsonEncodable value) {
  final FileRunner runner = value as FileRunner;
  return FileRunner(deviceId: runner.deviceId, name: runner.name);
}

JsonEncodable _rebuildRepositoryHolder(JsonEncodable value) {
  final RepositoryHolder holder = value as RepositoryHolder;
  return RepositoryHolder(
    deviceId: holder.deviceId,
    name: holder.name,
    lastSeen: holder.lastSeen,
  );
}

JsonEncodable _rebuildRepositoryEntry(JsonEncodable value) {
  final RepositoryEntry entry = value as RepositoryEntry;
  return RepositoryEntry(name: entry.name, kind: entry.kind, size: entry.size);
}

JsonEncodable _rebuildRepositoryFolderView(JsonEncodable value) {
  final RepositoryFolderView folder = value as RepositoryFolderView;
  return RepositoryFolderView(entries: folder.entries);
}

JsonEncodable _rebuildRepositoryFileView(JsonEncodable value) {
  final RepositoryFileView fileView = value as RepositoryFileView;
  return RepositoryFileView(
    path: fileView.path,
    size: fileView.size,
    preview: fileView.preview,
  );
}
