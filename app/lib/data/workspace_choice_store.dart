import 'package:agent_orchestration/data/models/identifiers.dart';

abstract interface class WorkspaceChoiceStore {
  Future<WorkspaceId?> readChosenWorkspaceId();

  Future<void> saveChosenWorkspaceId(WorkspaceId workspaceId);
}
