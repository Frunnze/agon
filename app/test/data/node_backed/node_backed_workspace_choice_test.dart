import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/node_backed.dart';

import '../../support/memory_workspace_choice_store.dart';
import '../../support/random_inputs.dart';
import 'support/simulated_catalog_node.dart';

const int _largestWorkspaceCount = 4;

typedef _Fixture = ({
  SimulatedCatalogNode node,
  MemoryWorkspaceChoiceStore store,
  NodeBackedWorkspaceRepository repository,
});

_Fixture _buildFixture(Random random, {required bool isChoiceListed}) {
  final SimulatedCatalogNode simulated = SimulatedCatalogNode(
    hasAccount: true,
  );
  final int workspaceCount = 1 + random.nextInt(_largestWorkspaceCount);
  final List<WorkspaceId> workspaceIds = <WorkspaceId>[
    for (int i = 0; i < workspaceCount; i += 1)
      WorkspaceId(simulated.addWorkspace('workspace-$i')['id']! as String),
  ];
  final WorkspaceId remembered = isChoiceListed
      ? pickOne(random, workspaceIds)
      : const WorkspaceId('forgotten-workspace');
  final MemoryWorkspaceChoiceStore store = MemoryWorkspaceChoiceStore(
    chosenWorkspaceId: remembered,
  );
  final NodeBackedWorkspaceRepository repository =
      NodeBackedWorkspaceRepository(
        channel: simulated.channel,
        clock: FixedClock(DateTime.utc(2026, 10, 31, 12)),
        retryInterval: const Duration(seconds: 30),
        choiceStore: store,
      );
  return (node: simulated, store: store, repository: repository);
}

void main() {
  test('test_load_property_restores_the_remembered_workspace', () async {
    final Random random = seededRandom(10051);
    for (int i = 0; i < propertyIterations; i += 1) {
      final bool isChoiceListed = random.nextBool();
      final _Fixture fixture = _buildFixture(
        random,
        isChoiceListed: isChoiceListed,
      );

      await fixture.repository.load();

      final Workspace current = fixture.repository.currentWorkspace();
      if (isChoiceListed) {
        expect(current.id, fixture.store.chosenWorkspaceId);
      } else {
        expect(current.id, fixture.repository.listWorkspaces().first.id);
      }
      fixture.repository.dispose();
    }
  });

  test('test_switch_workspace_property_choice_is_remembered', () async {
    final Random random = seededRandom(10052);
    for (int i = 0; i < propertyIterations; i += 1) {
      final _Fixture fixture = _buildFixture(random, isChoiceListed: true);
      await fixture.repository.load();

      final Workspace chosen = pickOne(
        random,
        fixture.repository.listWorkspaces(),
      );
      await fixture.repository.switchWorkspace(chosen.id);

      expect(fixture.store.chosenWorkspaceId, chosen.id);
      expect(fixture.repository.currentWorkspace().id, chosen.id);
      fixture.repository.dispose();
    }
  });
}
