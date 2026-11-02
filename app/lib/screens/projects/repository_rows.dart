import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/presentation/identifier_text.dart';
import 'package:agent_orchestration/screens/projects/project_text.dart';
import 'package:agent_orchestration/widgets/lists/list_row_data.dart';
import 'package:agent_orchestration/widgets/lists/list_row_main.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';

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
  required Widget? end,
}) {
  final String place = describeDraftedRepositoryPlace(repository, deviceNames);

  return ListRowData(
    key: ValueKey<String>(repository.address),
    main: ListRowMain.monospace(
      title: describeRepositoryPath(repository.address),
      subtitle: <TextSegment>[TextSegment(place)],
    ),
    end: end,
  );
}
