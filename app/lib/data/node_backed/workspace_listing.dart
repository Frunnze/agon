import 'package:agent_orchestration/data/fakes/record_lists.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/node_backed/identifier_order.dart';
import 'package:agent_orchestration/data/rules/scope_rules.dart';

List<T> placeInWorkspaceListing<T>(
  List<T> listing, {
  required T record,
  required WorkspaceScope recordWorkspaces,
  required WorkspaceId listedWorkspaceId,
  required String Function(T listed) identify,
}) {
  if (includesWorkspace(recordWorkspaces, listedWorkspaceId)) {
    return placeInIdentifierOrder(listing, record: record, identify: identify);
  }

  final String identifier = identify(record);
  return removeRecord(
    listing,
    matches: (T listed) => identify(listed) == identifier,
  );
}
