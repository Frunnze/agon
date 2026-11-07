import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/node_backed.dart';

import '../../support/memory_workspace_choice_store.dart';
import '../../support/random_inputs.dart';
import 'support/simulated_catalog_node.dart';

const int _sequenceIterations = 40;
const int _largestWorkspaceCount = 5;
const Duration _retryInterval = Duration(seconds: 30);
final DateTime _now = DateTime.utc(2026, 11, 7, 9);

final class _NotificationCounter {
  int notifications = 0;

  void record() {
    notifications += 1;
  }
}

NodeBackedWorkspaceRepository _buildRepository(
  SimulatedCatalogNode simulated,
) {
  return NodeBackedWorkspaceRepository(
    channel: simulated.channel,
    clock: FixedClock(_now),
    retryInterval: _retryInterval,
    choiceStore: MemoryWorkspaceChoiceStore(chosenWorkspaceId: null),
  );
}

SimulatedCatalogNode _buildNodeWithWorkspaces(int workspaceCount) {
  final SimulatedCatalogNode simulated = SimulatedCatalogNode(
    hasAccount: true,
  );
  for (int i = 0; i < workspaceCount; i += 1) {
    simulated.addWorkspace('workspace-$i');
  }
  return simulated;
}

Set<WorkspaceId> _listWorkspaceIds(NodeBackedWorkspaceRepository repository) {
  return <WorkspaceId>{
    for (final Workspace workspace in repository.listWorkspaces())
      workspace.id,
  };
}

void main() {
  test(
    'test_find_current_workspace_id_property_names_the_switched_workspace',
    () async {
      final Random random = seededRandom(72301);
      for (int i = 0; i < _sequenceIterations; i += 1) {
        final int workspaceCount = 1 + random.nextInt(_largestWorkspaceCount);
        final NodeBackedWorkspaceRepository repository = _buildRepository(
          _buildNodeWithWorkspaces(workspaceCount),
        );
        await repository.load();
        final Workspace chosen = pickOne(random, repository.listWorkspaces());

        await repository.switchWorkspace(chosen.id);

        expect(findCurrentWorkspaceId(repository), chosen.id);
        repository.dispose();
      }
    },
  );

  test('test_find_current_workspace_id_property_none_before_any_load', () {
    final Random random = seededRandom(72302);
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final int workspaceCount = random.nextInt(_largestWorkspaceCount);
      final NodeBackedWorkspaceRepository repository = _buildRepository(
        _buildNodeWithWorkspaces(workspaceCount),
      );

      expect(findCurrentWorkspaceId(repository), isNull);
      repository.dispose();
    }
  });

  test(
    'test_find_current_workspace_id_property_follows_removed_workspaces',
    () async {
      final Random random = seededRandom(72303);
      for (int i = 0; i < _sequenceIterations; i += 1) {
        final int workspaceCount = 1 + random.nextInt(_largestWorkspaceCount);
        final SimulatedCatalogNode simulated = _buildNodeWithWorkspaces(
          workspaceCount,
        );
        final NodeBackedWorkspaceRepository repository = _buildRepository(
          simulated,
        );
        await repository.load();
        final Workspace chosen = pickOne(random, repository.listWorkspaces());
        await repository.switchWorkspace(chosen.id);

        simulated.workspaces.removeWhere(
          (Map<String, Object?> workspace) => random.nextBool(),
        );
        await repository.load();

        final WorkspaceId? current = findCurrentWorkspaceId(repository);
        final Set<WorkspaceId> listed = _listWorkspaceIds(repository);
        expect(current == null, listed.isEmpty);
        if (current != null) {
          expect(listed, contains(current));
        }
        if (listed.contains(chosen.id)) {
          expect(current, chosen.id);
        }
        repository.dispose();
      }
    },
  );

  test(
    'test_find_current_workspace_id_property_reads_without_side_effects',
    () async {
      final Random random = seededRandom(72304);
      for (int i = 0; i < _sequenceIterations; i += 1) {
        final int workspaceCount = random.nextInt(_largestWorkspaceCount);
        final NodeBackedWorkspaceRepository repository = _buildRepository(
          _buildNodeWithWorkspaces(workspaceCount),
        );
        await repository.load();
        final _NotificationCounter counter = _NotificationCounter();
        repository.addListener(counter.record);

        final WorkspaceId? first = findCurrentWorkspaceId(repository);
        final WorkspaceId? second = findCurrentWorkspaceId(repository);

        expect(second, first);
        expect(counter.notifications, 0);
        repository.removeListener(counter.record);
        repository.dispose();
      }
    },
  );
}
