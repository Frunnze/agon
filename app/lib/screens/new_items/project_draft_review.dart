import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/repository/device_repository.dart';
import 'package:agent_orchestration/data/repository/project_repository.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/screens/new_items/draft_review.dart';
import 'package:agent_orchestration/screens/projects/agent_access_choices.dart';
import 'package:agent_orchestration/screens/projects/repository_rows.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/widgets/fact_list.dart';
import 'package:agent_orchestration/widgets/lists/list_row_data.dart';
import 'package:agent_orchestration/widgets/lists/responsive_list.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';

final class ProjectDraftReview implements DraftReview {
  const ProjectDraftReview({
    required this.projectRepository,
    required this.workspaceRepository,
    required this.deviceRepository,
    required this.navigation,
  });

  final ProjectRepository projectRepository;
  final WorkspaceRepository workspaceRepository;
  final DeviceRepository deviceRepository;
  final AppNavigation navigation;

  @override
  List<Fact> describeFacts(DraftedItem item) {
    final DraftedProject project = _requireProject(item);
    final DeviceNames deviceNames = DeviceNames(
      deviceRepository.listDevices(),
    );

    return <Fact>[
      Fact(
        term: 'Name',
        description: <TextSegment>[TextSegment.monospace(project.name)],
      ),
      if (project.repositories.isEmpty)
        describeMutedFact('Repos', noneChosenText)
      else
        Fact.content(
          term: 'Repos',
          content: _buildRepositoryList(project.repositories, deviceNames),
        ),
      describeTextFact(
        'What agents can do',
        describeAgentAccessChoiceTitle(project.agentAccess),
      ),
    ];
  }

  @override
  Future<void> approve(DraftedItem item) async {
    final DraftedProject drafted = _requireProject(item);
    final Project project = await projectRepository.createProject(
      drafted.toProjectDraft(workspaceRepository.currentWorkspace().id),
    );
    navigation.replaceRoute(ProjectRoute(project.id));
  }

  DraftedProject _requireProject(DraftedItem item) {
    if (item is! DraftedProject) {
      throw ArgumentError.value(item, 'item', 'Not a project draft');
    }
    return item;
  }

  Widget _buildRepositoryList(
    List<RepositoryDraft> repositories,
    DeviceNames deviceNames,
  ) {
    return ResponsiveList.plain(
      rows: <ListRowData>[
        for (final RepositoryDraft repository in repositories)
          buildRepositoryDraftRow(
            repository: repository,
            deviceNames: deviceNames,
            end: null,
          ),
      ],
    );
  }
}
