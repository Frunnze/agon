import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/presentation/identifier_text.dart';
import 'package:agent_orchestration/screens/projects/project_text.dart';
import 'package:agent_orchestration/widgets/lists/list_row_data.dart';
import 'package:agent_orchestration/widgets/lists/list_row_main.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';

const String startedGitNote = 'Started git in this folder';

String describeDraftedRepositoryPlace(
  RepositoryDraft repository,
  DeviceNames deviceNames,
) {
  final String place = describeRepositoryPlace(
    repository.address,
    deviceNames,
  );
  return '$place · ${repository.defaultBranch}';
}

ListRowData buildRepositoryDraftRow({
  required RepositoryDraft repository,
  required DeviceNames deviceNames,
  required Set<String> gitStartedAddresses,
  required Widget? end,
}) {
  final String place = describeDraftedRepositoryPlace(repository, deviceNames);
  final bool hasStartedGit = gitStartedAddresses.contains(repository.address);
  final String subtitle = hasStartedGit ? '$place · $startedGitNote' : place;

  return ListRowData(
    key: ValueKey<String>(repository.address),
    main: ListRowMain.monospace(
      title: describeRepositoryPath(repository.address),
      subtitle: <TextSegment>[TextSegment(subtitle)],
    ),
    end: end,
  );
}

const String newFolderNote =
    'New folder · made with git when you create the project';
const ValueKey<String> _newFolderRowKey = ValueKey<String>('new-folder');

ListRowData buildNewFolderRow({
  required String folderPath,
  required Widget end,
}) {
  return ListRowData(
    key: _newFolderRowKey,
    main: ListRowMain.monospace(
      title: folderPath,
      subtitle: const <TextSegment>[TextSegment(newFolderNote)],
    ),
    end: end,
  );
}
