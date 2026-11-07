import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/node_backed/current_workspace_lookup.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';
import 'package:agent_orchestration/data/rules/scope_rules.dart';

typedef WorkspaceScopeReader<Scoped> = WorkspaceScope Function(Scoped record);

List<Scoped> listRecordsInCurrentWorkspace<Scoped>({
  required List<Scoped> records,
  required WorkspaceRepository workspaceRepository,
  required WorkspaceScopeReader<Scoped> readWorkspaceScope,
}) {
  final WorkspaceId? workspaceId = findCurrentWorkspaceId(workspaceRepository);
  if (workspaceId == null) {
    return List<Scoped>.unmodifiable(<Scoped>[]);
  }

  final List<Scoped> usableRecords = <Scoped>[];
  for (final Scoped record in records) {
    if (includesWorkspace(readWorkspaceScope(record), workspaceId)) {
      usableRecords.add(record);
    }
  }
  return List<Scoped>.unmodifiable(usableRecords);
}
