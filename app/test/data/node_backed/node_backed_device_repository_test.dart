import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/change_values.dart' as node;
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/repository/app_server_refusal.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../bridge/support/node_json_primitives.dart';
import '../../bridge/support/random_catalog_json.dart';
import '../../support/random_inputs.dart';
import 'support/node_backed_harness.dart';
import 'support/simulated_device_node.dart';

const int _sequenceIterations = 25;
const int _stepsPerSequence = 10;
const String _thisDeviceId = 'this-device';

enum _DeviceStep { revoke, addWorkspace, removeWorkspace, pairedElsewhere }

typedef _Fixture = ({
  SimulatedDeviceNode node,
  NodeBackedDeviceRepository repository,
});

_Fixture _buildFixture(Random random) {
  final SimulatedDeviceNode simulated = SimulatedDeviceNode(
    thisDeviceId: _thisDeviceId,
  );
  final Map<String, Object?> thisDevice = randomDeviceJson(random);
  thisDevice['id'] = _thisDeviceId;
  thisDevice['revoked'] = false;
  simulated.devices[_thisDeviceId] = thisDevice;
  final NodeBackedDeviceRepository repository = NodeBackedDeviceRepository(
    channel: buildSimulatedChannel(simulated.answer),
  );
  return (node: simulated, repository: repository);
}

void _expectMirrorsNode(_Fixture fixture) {
  final List<Device> devices = fixture.repository.listDevices();
  expect(
    devices.map((Device device) => device.id.value),
    fixture.node.devices.keys,
  );
  for (final Device device in devices) {
    final Map<String, Object?> wire = fixture.node.devices[device.id.value]!;
    expect(device.revoked, wire['revoked']);
    expect(
      device.workspaces.map((WorkspaceId workspace) => workspace.value),
      wire['workspaces'],
    );
  }
  expect(fixture.repository.currentDevice().id.value, _thisDeviceId);
}

Matcher _expectedRevokeOutcome(Device device) {
  final bool isThisDevice = device.id.value == _thisDeviceId;
  if (isThisDevice || device.revoked) {
    return throwsStateError;
  }
  return completes;
}

Matcher _expectedJoinOutcome({
  required Device device,
  required WorkspaceId workspaceId,
  required Device thisDevice,
}) {
  final bool isMember = device.workspaces.contains(workspaceId);
  final bool holdsKey = thisDevice.workspaces.contains(workspaceId);
  if (!holdsKey || device.revoked || isMember) {
    return throwsStateError;
  }
  return completes;
}

Matcher _expectedLeaveOutcome(Device device, WorkspaceId workspaceId) {
  if (device.workspaces.contains(workspaceId)) {
    return completes;
  }
  return throwsA(isA<AppServerRefusal>());
}

WorkspaceId _pickWorkspace(Random random, List<WorkspaceId> known) {
  if (known.isEmpty || random.nextInt(3) == 0) {
    return WorkspaceId(randomUuidText(random));
  }
  return pickOne(random, known);
}

Future<void> _takeStep(Random random, _Fixture fixture) async {
  final NodeBackedDeviceRepository repository = fixture.repository;
  final Device device = pickOne(random, repository.listDevices());
  final Device thisDevice = repository.currentDevice();
  final WorkspaceId workspaceId = _pickWorkspace(random, <WorkspaceId>[
    ...device.workspaces,
    ...thisDevice.workspaces,
  ]);

  switch (pickOne(random, _DeviceStep.values)) {
    case _DeviceStep.revoke:
      await expectLater(
        repository.revokeDevice(device.id),
        _expectedRevokeOutcome(device),
      );
    case _DeviceStep.addWorkspace:
      await expectLater(
        repository.addDeviceToWorkspace(device.id, workspaceId),
        _expectedJoinOutcome(
          device: device,
          workspaceId: workspaceId,
          thisDevice: thisDevice,
        ),
      );
    case _DeviceStep.removeWorkspace:
      await expectLater(
        repository.removeDeviceFromWorkspace(device.id, workspaceId),
        _expectedLeaveOutcome(device, workspaceId),
      );
    case _DeviceStep.pairedElsewhere:
      fixture.node.addDeviceFromElsewhere(random);
      await repository.applyChange(
        const node.AreaChanged(area: node.ChangeArea.devices),
      );
  }
}

void main() {
  test('test_apply_change_property_devices_mirror_the_node', () async {
    final Random random = seededRandom(9941);
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final _Fixture fixture = _buildFixture(random);
      await fixture.repository.load();
      _expectMirrorsNode(fixture);

      for (int step = 0; step < _stepsPerSequence; step += 1) {
        await _takeStep(random, fixture);
        _expectMirrorsNode(fixture);
      }
    }
  });

  test('test_add_device_to_workspace_property_device_joins_it', () async {
    final Random random = seededRandom(9942);
    final _Fixture fixture = _buildFixture(random);
    final List<Object?> heldWorkspaces =
        fixture.node.devices[_thisDeviceId]!['workspaces']! as List<Object?>;
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final WorkspaceId workspaceId = WorkspaceId(randomUuidText(random));
      heldWorkspaces.add(workspaceId.value);
      final String joinerId = fixture.node.addDeviceFromElsewhere(random);
      fixture.node.devices[joinerId]!['revoked'] = false;
      await fixture.repository.load();

      final Device joined = await fixture.repository.addDeviceToWorkspace(
        DeviceId(joinerId),
        workspaceId,
      );
      expect(joined.workspaces, contains(workspaceId));

      final Device left = await fixture.repository.removeDeviceFromWorkspace(
        DeviceId(joinerId),
        workspaceId,
      );
      expect(left.workspaces, isNot(contains(workspaceId)));
    }
  });

  test('test_revoke_device_property_device_is_revoked', () async {
    final Random random = seededRandom(9943);
    final _Fixture fixture = _buildFixture(random);
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final String deviceId = fixture.node.addDeviceFromElsewhere(random);
      await fixture.repository.load();
      final bool wasRevoked = fixture.repository
          .findDevice(DeviceId(deviceId))
          .revoked;
      if (wasRevoked) {
        await expectLater(
          fixture.repository.revokeDevice(DeviceId(deviceId)),
          throwsStateError,
        );
      } else {
        final Device revoked = await fixture.repository.revokeDevice(
          DeviceId(deviceId),
        );
        expect(revoked.revoked, isTrue);
      }
      expect(
        fixture.repository.findDevice(DeviceId(deviceId)).revoked,
        isTrue,
      );
      await expectLater(
        fixture.repository.revokeDevice(const DeviceId(_thisDeviceId)),
        throwsStateError,
      );
    }
  });

  test('test_current_device_property_needs_a_loaded_list', () {
    final Random random = seededRandom(9944);
    final _Fixture fixture = _buildFixture(random);
    expect(fixture.repository.currentDevice, throwsStateError);
    for (int i = 0; i < propertyIterations; i += 1) {
      expect(
        () => fixture.repository.findDevice(DeviceId(randomText(random))),
        throwsA(isA<RecordNotFound>()),
      );
    }
  });

  test('test_apply_change_property_other_areas_send_nothing', () async {
    final Random random = seededRandom(9945);
    final _Fixture fixture = _buildFixture(random);
    for (final node.ChangeArea area in node.ChangeArea.values) {
      final bool isWatched =
          area == node.ChangeArea.devices ||
          area == node.ChangeArea.workspaces;
      if (!isWatched) {
        await fixture.repository.applyChange(node.AreaChanged(area: area));
      }
    }
    expect(fixture.node.receivedCommands, isEmpty);
  });

  test('test_load_property_reads_the_peer_problem', () async {
    final Random random = seededRandom(9946);
    for (int i = 0; i < propertyIterations; i += 1) {
      final _Fixture fixture = _buildFixture(random);
      final String? problem = random.nextBool()
          ? 'no relay ${randomText(random)}'
          : null;
      fixture.node.peerProblem = problem;

      await fixture.repository.load();

      expect(fixture.repository.findPeerAddressProblem(), problem);
    }
  });
}
