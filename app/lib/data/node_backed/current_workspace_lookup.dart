import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';

WorkspaceId? findCurrentWorkspaceId(WorkspaceRepository repository) {
  if (repository.listWorkspaces().isEmpty) {
    return null;
  }
  return repository.currentWorkspace().id;
}
