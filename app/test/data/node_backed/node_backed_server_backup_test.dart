import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/change_values.dart' as node;
import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/models/app_server_group.dart';
import 'package:agent_orchestration/data/node_backed.dart';

import '../../support/memory_workspace_choice_store.dart';
import '../../support/random_inputs.dart';
import 'support/simulated_catalog_node.dart';
import 'support/simulated_server_group.dart';

const Duration _retryInterval = Duration(seconds: 30);
final DateTime _now = DateTime.utc(2026, 10, 31, 12);
const int _sequenceIterations = 60;
const int _stepsPerSequence = 8;

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

SimulatedCatalogNode _buildRandomNode(Random random) {
  final SimulatedCatalogNode simulated = SimulatedCatalogNode(
    hasAccount: true,
  );
  simulated.addWorkspace('home');
  simulated.serverGroup.canKeepBackup = random.nextBool();
  if (random.nextBool()) {
    simulated.serverGroup.foundGroup();
  }
  return simulated;
}

List<String> _describeMembers(AppServerGroup group) {
  return <String>[
    for (final AppServerMember member in group.members)
      '${member.deviceId.value} ${member.standing.name}',
  ];
}

List<String> _describeNodeServers(SimulatedCatalogNode simulated) {
  return <String>[
    for (final Map<String, Object?> server in simulated.serverGroup.servers)
      '${server['device_id']} ${server['standing']}',
  ];
}

void _expectMirrorsNode(
  NodeBackedWorkspaceRepository repository,
  SimulatedCatalogNode simulated,
) {
  final AppServerGroup group = repository.findAppServerGroup();
  expect(_describeMembers(group), _describeNodeServers(simulated));
  expect(
    group.thisDeviceStanding.name,
    simulated.serverGroup.thisDeviceStanding,
  );
  expect(group.canKeepBackup, simulated.serverGroup.canKeepBackup);
}

void main() {
  test('test_find_app_server_group_property_mirrors_node_status', () async {
    final Random random = seededRandom(9711);

    for (int i = 0; i < _sequenceIterations; i += 1) {
      final SimulatedCatalogNode simulated = _buildRandomNode(random);
      final NodeBackedWorkspaceRepository repository = _buildRepository(
        simulated,
      );

      expect(repository.findAppServerGroup, throwsStateError);
      await repository.load();

      _expectMirrorsNode(repository, simulated);
      repository.dispose();
    }
  });

  test('test_start_server_backup_property_follows_node_answers', () async {
    final Random random = seededRandom(9712);

    for (int i = 0; i < _sequenceIterations; i += 1) {
      final SimulatedCatalogNode simulated = _buildRandomNode(random);
      final NodeBackedWorkspaceRepository repository = _buildRepository(
        simulated,
      );
      await repository.load();
      int notifications = 0;
      repository.addListener(() => notifications += 1);

      for (int step = 0; step < _stepsPerSequence; step += 1) {
        final List<String> before = _describeMembers(
          repository.findAppServerGroup(),
        );
        final int notificationsBefore = notifications;
        final bool isAllowed =
            simulated.serverGroup.canKeepBackup &&
            simulated.serverGroup.servers.isNotEmpty &&
            simulated.serverGroup.thisDeviceStanding == 'none';

        if (isAllowed) {
          final AppServerGroup started = await repository.startServerBackup();
          expect(started.thisDeviceStanding, ThisDeviceStanding.backup);
          expect(_describeMembers(started).last, '$simulatedDeviceId backup');
          expect(notifications, notificationsBefore + 1);
        } else {
          await expectLater(repository.startServerBackup(), throwsStateError);
          expect(_describeMembers(repository.findAppServerGroup()), before);
        }
        _expectMirrorsNode(repository, simulated);

        if (random.nextBool()) {
          final AppServerGroup stopped = await repository.stopServerBackup();
          expect(stopped.thisDeviceStanding, ThisDeviceStanding.none);
          expect(
            _describeMembers(stopped),
            isNot(contains('$simulatedDeviceId backup')),
          );
          _expectMirrorsNode(repository, simulated);
        }
      }
      repository.dispose();
    }
  });

  test('test_stop_server_backup_property_refused_while_active', () async {
    final Random random = seededRandom(9713);

    for (int i = 0; i < _sequenceIterations; i += 1) {
      final SimulatedCatalogNode simulated = _buildRandomNode(random);
      simulated.serverGroup.makeThisDeviceActive();
      final NodeBackedWorkspaceRepository repository = _buildRepository(
        simulated,
      );
      await repository.load();
      final List<String> before = _describeMembers(
        repository.findAppServerGroup(),
      );

      await expectLater(
        repository.stopServerBackup(),
        throwsA(
          isA<StateError>().having(
            (StateError problem) => problem.message,
            'message',
            simulatedActiveServerMessage,
          ),
        ),
      );
      expect(_describeMembers(repository.findAppServerGroup()), before);
      expect(
        repository.findAppServerGroup().thisDeviceStanding,
        ThisDeviceStanding.active,
      );
      repository.dispose();
    }
  });

  test('test_apply_change_property_server_group_reloads_status', () async {
    final Random random = seededRandom(9714);
    final SimulatedCatalogNode simulated = SimulatedCatalogNode(
      hasAccount: true,
    );
    final NodeBackedWorkspaceRepository repository = _buildRepository(
      simulated,
    );
    await repository.load();

    for (int i = 0; i < propertyIterations; i += 1) {
      simulated.serverGroup.canKeepBackup = random.nextBool();
      simulated.serverGroup.foundGroup();
      await repository.applyChange(
        const node.AreaChanged(area: node.ChangeArea.serverGroup),
      );

      _expectMirrorsNode(repository, simulated);
    }
    repository.dispose();
  });
}
