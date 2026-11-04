import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/folder_picker.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/repository/device_repository.dart';
import 'package:agent_orchestration/data/repository/project_repository.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';
import 'package:agent_orchestration/screens/new_items/draft_review.dart';
import 'package:agent_orchestration/screens/projects/project_form.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';

final class ProjectDraftReview implements DraftReview {
  const ProjectDraftReview({
    required this.projectRepository,
    required this.workspaceRepository,
    required this.deviceRepository,
    required this.folderPicker,
    required this.navigation,
  });

  final ProjectRepository projectRepository;
  final WorkspaceRepository workspaceRepository;
  final DeviceRepository deviceRepository;
  final FolderPicker? folderPicker;
  final AppNavigation navigation;

  @override
  Widget buildForm(DraftedItem item, DraftFormCallbacks callbacks) {
    return ProjectForm(
      initialProject: _requireProject(item),
      deviceRepository: deviceRepository,
      folderPicker: folderPicker,
      onChanged: callbacks.onChanged,
      actions: buildReviewActions<DraftedProject>(
        onCancelled: callbacks.onCancelled,
        onApproved: callbacks.onApproved,
      ),
    );
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
}
