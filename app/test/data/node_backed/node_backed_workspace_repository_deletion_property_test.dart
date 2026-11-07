import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/node_backed.dart';

import '../../support/random_inputs.dart';
import 'support/identifier_ordered_records.dart';
import 'support/out_of_order_replies.dart';
import 'support/simulated_catalog_node.dart';
import 'support/simulated_node_replies.dart';

const int _iterations = 40;
const int _largestUnseenWorkspaceCount = 3;
const String _workspaceKind = 'workspace';

typedef _UnseenWorkspaces = ({
  SimulatedCatalogNode node,
  IdentifierOrderedCatalogNode ordered,
  NodeBackedWorkspaceRepository workspaces,
  WorkspaceId listedWorkspaceId,
});

void _addWorkspace(Random random, SimulatedCatalogNode simulated) {
  final Map<String, Object?> workspace = simulated.addWorkspace(
    randomWordPhrase(random),
  );
  workspace['id'] = randomRecordIdentifier(random, _workspaceKind);
}

Future<_UnseenWorkspaces> _openWithUnseenWorkspaces(Random random) async {
  final SimulatedCatalogNode simulated = SimulatedCatalogNode(
    hasAccount: true,
  );
  _addWorkspace(random, simulated);
  final IdentifierOrderedCatalogNode ordered = IdentifierOrderedCatalogNode(
    simulated,
  );
  final NodeBackedWorkspaceRepository workspaces = await openRaceWorkspaces(
    buildSimulatedChannel(ordered.answer),
  );
  final int unseenCount = 1 + random.nextInt(_largestUnseenWorkspaceCount);
  for (int i = 0; i < unseenCount; i += 1) {
    _addWorkspace(random, simulated);
  }
  return (
    node: simulated,
    ordered: ordered,
    workspaces: workspaces,
    listedWorkspaceId: workspaces.listWorkspaces().single.id,
  );
}

List<String> _listNodeWorkspaceIds(SimulatedCatalogNode simulated) {
  final List<String> workspaceIds = <String>[
    for (final Map<String, Object?> workspace in simulated.workspaces)
      readSimulatedIdentifier(workspace),
  ];
  workspaceIds.sort();
  return workspaceIds;
}

List<String> _listShownWorkspaceIds(NodeBackedWorkspaceRepository workspaces) {
  return <String>[
    for (final Workspace workspace in workspaces.listWorkspaces())
      workspace.id.value,
  ];
}

void main() {
  test('test_node_backed_workspace_repository_delete_workspace_property_'
      'deleting_the_last_listed_one_never_fails', () async {
    final Random random = seededRandom(81801);
    for (int i = 0; i < _iterations; i += 1) {
      final _UnseenWorkspaces opened = await _openWithUnseenWorkspaces(random);

      await opened.workspaces.deleteWorkspace(opened.listedWorkspaceId);

      expect(opened.workspaces.listWorkspaces(), isNotEmpty);
      opened.workspaces.dispose();
    }
  });

  test('test_node_backed_workspace_repository_delete_workspace_property_'
      'deleting_the_last_listed_one_lists_what_the_node_kept', () async {
    final Random random = seededRandom(81802);
    for (int i = 0; i < _iterations; i += 1) {
      final _UnseenWorkspaces opened = await _openWithUnseenWorkspaces(random);

      await opened.workspaces.deleteWorkspace(opened.listedWorkspaceId);

      expect(
        _listShownWorkspaceIds(opened.workspaces),
        _listNodeWorkspaceIds(opened.node),
      );
      opened.workspaces.dispose();
    }
  });

  test('test_node_backed_workspace_repository_delete_workspace_property_'
      'deleting_the_last_listed_one_moves_to_a_kept_workspace', () async {
    final Random random = seededRandom(81803);
    for (int i = 0; i < _iterations; i += 1) {
      final _UnseenWorkspaces opened = await _openWithUnseenWorkspaces(random);

      await opened.workspaces.deleteWorkspace(opened.listedWorkspaceId);

      final WorkspaceId currentWorkspaceId = opened.workspaces
          .currentWorkspace()
          .id;
      expect(currentWorkspaceId, isNot(opened.listedWorkspaceId));
      expect(
        _listNodeWorkspaceIds(opened.node),
        contains(currentWorkspaceId.value),
      );
      opened.workspaces.dispose();
    }
  });
}
