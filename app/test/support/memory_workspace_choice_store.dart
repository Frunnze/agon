import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/workspace_choice_store.dart';

final class MemoryWorkspaceChoiceStore implements WorkspaceChoiceStore {
  MemoryWorkspaceChoiceStore({required this.chosenWorkspaceId});

  WorkspaceId? chosenWorkspaceId;

  @override
  Future<WorkspaceId?> readChosenWorkspaceId() async => chosenWorkspaceId;

  @override
  Future<void> saveChosenWorkspaceId(WorkspaceId workspaceId) async {
    chosenWorkspaceId = workspaceId;
  }
}
