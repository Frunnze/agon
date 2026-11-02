import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/change_values.dart' as node;
import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../support/memory_workspace_choice_store.dart';
import '../../support/random_inputs.dart';
import 'support/simulated_catalog_node.dart';

const Duration _retryInterval = Duration(seconds: 30);
final DateTime _now = DateTime.utc(2026, 10, 31, 12);
const int _sequenceIterations = 60;

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

List<String> _listWorkspaceIds(NodeBackedWorkspaceRepository repository) {
  return <String>[
    for (final Workspace workspace in repository.listWorkspaces())
      workspace.id.value,
  ];
}

List<String> _listNodeWorkspaceIds(SimulatedCatalogNode simulated) {
  return <String>[
    for (final Map<String, Object?> workspace in simulated.workspaces)
      workspace['id'] as String,
  ];
}

void main() {
  test('test_load_property_mirrors_node_workspaces', () async {
    final Random random = seededRandom(9601);
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final SimulatedCatalogNode simulated = SimulatedCatalogNode(
        hasAccount: random.nextBool(),
      );
      final int workspaceCount = random.nextInt(4);
      for (int j = 0; j < workspaceCount; j += 1) {
        simulated.addWorkspace('workspace-$j');
      }
      final NodeBackedWorkspaceRepository repository = _buildRepository(
        simulated,
      );

      await repository.load();

      if (simulated.hasAccount) {
        expect(
          _listWorkspaceIds(repository),
          _listNodeWorkspaceIds(simulated),
        );
        expect(
          repository.findAppServerStatus().address,
          simulatedServerAddress,
        );
      } else {
        expect(repository.listWorkspaces(), isEmpty);
        expect(repository.findAppServerStatus, throwsStateError);
      }
      if (repository.listWorkspaces().isEmpty) {
        expect(repository.currentWorkspace, throwsStateError);
      }
      repository.dispose();
    }
  });

  test('test_current_workspace_property_stays_a_listed_workspace', () async {
    final Random random = seededRandom(9602);
    final SimulatedCatalogNode simulated = SimulatedCatalogNode(
      hasAccount: true,
    );
    simulated.addWorkspace('home');
    final NodeBackedWorkspaceRepository repository = _buildRepository(
      simulated,
    );
    await repository.load();

    for (int i = 0; i < propertyIterations; i += 1) {
      switch (random.nextInt(4)) {
        case 0:
          final Workspace chosen = pickOne(
            random,
            repository.listWorkspaces(),
          );
          await repository.switchWorkspace(chosen.id);
          expect(repository.currentWorkspace().id, chosen.id);
        case 1:
          await expectLater(
            repository.switchWorkspace(WorkspaceId('missing-$i')),
            throwsA(isA<RecordNotFound>()),
          );
        case 2:
          final Workspace created = await repository.createWorkspace(
            name: 'created-$i',
          );
          expect(created.name, 'created-$i');
        case 3:
          simulated.addWorkspace('elsewhere-$i');
          await repository.applyChange(
            const node.AreaChanged(area: node.ChangeArea.workspaces),
          );
      }
      expect(_listWorkspaceIds(repository), _listNodeWorkspaceIds(simulated));
      expect(
        _listWorkspaceIds(repository),
        contains(repository.currentWorkspace().id.value),
      );
    }
    repository.dispose();
  });

  test('test_create_workspace_property_rejects_bad_names', () async {
    final Random random = seededRandom(9603);
    final SimulatedCatalogNode simulated = SimulatedCatalogNode(
      hasAccount: true,
    );
    final NodeBackedWorkspaceRepository repository = _buildRepository(
      simulated,
    );
    await repository.load();

    for (int i = 0; i < propertyIterations; i += 1) {
      final String name = 'Bad Name ${randomText(random)}';
      await expectLater(
        repository.createWorkspace(name: name),
        throwsArgumentError,
      );
      expect(simulated.workspaces, isEmpty);
    }
    repository.dispose();
  });

  test('test_retry_app_server_property_follows_reachability', () async {
    final Random random = seededRandom(9604);
    final SimulatedCatalogNode simulated = SimulatedCatalogNode(
      hasAccount: true,
    );
    final NodeBackedWorkspaceRepository repository = _buildRepository(
      simulated,
    );
    await repository.load();

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime before = repository.findAppServerStatus().lastConnectedAt;
      simulated.isServerReachable = random.nextBool();
      final AppServerStatus status = await repository.retryAppServer();
      expect(
        status.state == AppServerState.online,
        simulated.isServerReachable,
      );
      expect(repository.findAppServerStatus().state, status.state);
      expect(status.retryInterval, _retryInterval);
      if (!simulated.isServerReachable) {
        expect(status.lastConnectedAt, before);
      }
    }
    repository.dispose();
  });

  test('test_apply_change_property_ignores_unrelated_areas', () async {
    final Random random = seededRandom(9605);
    final SimulatedCatalogNode simulated = SimulatedCatalogNode(
      hasAccount: true,
    );
    final NodeBackedWorkspaceRepository repository = _buildRepository(
      simulated,
    );
    await repository.load();
    const Set<node.ChangeArea> watched = <node.ChangeArea>{
      node.ChangeArea.account,
      node.ChangeArea.workspaces,
      node.ChangeArea.serverGroup,
    };

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> before = _listWorkspaceIds(repository);
      simulated.addWorkspace('remote-$i');
      final node.ChangeArea area = pickOne(random, node.ChangeArea.values);
      await repository.applyChange(node.AreaChanged(area: area));
      if (watched.contains(area)) {
        expect(
          _listWorkspaceIds(repository),
          _listNodeWorkspaceIds(simulated),
        );
      } else {
        expect(_listWorkspaceIds(repository), before);
      }
    }
    repository.dispose();
  });

  test('test_load_property_failure_keeps_the_local_copy', () async {
    final SimulatedCatalogNode simulated = SimulatedCatalogNode(
      hasAccount: true,
    );
    simulated.addWorkspace('home');
    final NodeBackedWorkspaceRepository repository = _buildRepository(
      simulated,
    );
    await repository.load();

    for (int i = 0; i < propertyIterations; i += 1) {
      simulated.addWorkspace('unseen-$i');
      simulated.failingCommands.add('list_workspaces');
      await expectLater(repository.load(), throwsStateError);
      expect(repository.listWorkspaces().length, 1);
      simulated.failingCommands.clear();
    }
    repository.dispose();
  });

  test(
    'test_find_current_workspace_id_property_none_without_workspaces',
    () async {
      final Random random = seededRandom(9800);
      for (int i = 0; i < 40; i += 1) {
        final SimulatedCatalogNode simulated = SimulatedCatalogNode(
          hasAccount: true,
        );
        final int count = random.nextInt(3);
        for (int j = 0; j < count; j += 1) {
          simulated.addWorkspace('workspace-$j');
        }
        final NodeBackedWorkspaceRepository repository = _buildRepository(
          simulated,
        );
        await repository.load();
        final WorkspaceId? current = findCurrentWorkspaceId(repository);
        if (count == 0) {
          expect(current, isNull);
        } else {
          expect(current, repository.currentWorkspace().id);
        }
        repository.dispose();
      }
    },
  );
}
