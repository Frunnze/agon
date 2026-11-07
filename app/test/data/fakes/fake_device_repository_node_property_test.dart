import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/repository/device_repository.dart';

import '../../bridge/support/random_catalog_json.dart';
import '../../support/random_inputs.dart';
import '../node_backed/support/node_backed_harness.dart';
import '../node_backed/support/simulated_device_node.dart';

const String _thisDeviceText = 'this-device';
const int _sequenceIterations = 40;
const int _largestOtherDeviceCount = 5;
const int _longestSequence = 10;
const String _workspaceSeparator = '|';

typedef _Pair = ({
  FakeDeviceRepository fake,
  NodeBackedDeviceRepository nodeBacked,
});

typedef _DeviceView = ({String id, bool revoked, String workspaces});

typedef _Change = Future<Device> Function(DeviceRepository repository);

Future<_Pair> _buildPair(Random random, {required String? peerProblem}) async {
  final SimulatedDeviceNode simulated = SimulatedDeviceNode(
    thisDeviceId: _thisDeviceText,
  );
  final Map<String, Object?> thisDevice = randomDeviceJson(random);
  thisDevice['id'] = _thisDeviceText;
  thisDevice['revoked'] = false;
  simulated.devices[_thisDeviceText] = thisDevice;
  final int otherCount = random.nextInt(_largestOtherDeviceCount);
  for (int i = 0; i < otherCount; i += 1) {
    simulated.addDeviceFromElsewhere(random);
  }
  simulated.peerProblem = peerProblem;

  final NodeBackedDeviceRepository nodeBacked = NodeBackedDeviceRepository(
    channel: buildSimulatedChannel(simulated.answer),
  );
  await nodeBacked.load();
  final FakeDeviceRepository fake = FakeDeviceRepository(
    devices: nodeBacked.listDevices(),
    currentDeviceId: const DeviceId(_thisDeviceText),
    peerAddressProblem: peerProblem,
    gitlessFolderPaths: const <String>{},
  );
  return (fake: fake, nodeBacked: nodeBacked);
}

_DeviceView _describeDevice(Device device) {
  return (
    id: device.id.value,
    revoked: device.revoked,
    workspaces: <String>[
      for (final WorkspaceId workspaceId in device.workspaces)
        workspaceId.value,
    ].join(_workspaceSeparator),
  );
}

List<_DeviceView> _describeDevices(List<Device> devices) {
  final List<_DeviceView> views = <_DeviceView>[];
  for (final Device device in devices) {
    views.add(_describeDevice(device));
  }
  return views;
}

_Change? _pickValidChange(Random random, FakeDeviceRepository fake) {
  final Device device = pickOne(random, fake.listDevices());
  final bool canRevoke = device.id.value != _thisDeviceText && !device.revoked;
  final bool canLeave = device.workspaces.isNotEmpty;

  if (canRevoke && random.nextBool()) {
    return (DeviceRepository repository) => repository.revokeDevice(device.id);
  }
  if (canLeave && random.nextBool()) {
    final WorkspaceId left = pickOne(random, device.workspaces);
    return (DeviceRepository repository) =>
        repository.removeDeviceFromWorkspace(device.id, left);
  }
  final List<WorkspaceId> joinable = <WorkspaceId>[
    for (final WorkspaceId held in fake.currentDevice().workspaces)
      if (!device.revoked && !device.workspaces.contains(held)) held,
  ];
  if (joinable.isEmpty) {
    return null;
  }
  final WorkspaceId joined = pickOne(random, joinable);
  return (DeviceRepository repository) =>
      repository.addDeviceToWorkspace(device.id, joined);
}

Future<void> _changeBoth(Random random, _Pair pair) async {
  final _Change? change = _pickValidChange(random, pair.fake);
  if (change == null) {
    return;
  }

  final Device fromFake = await change(pair.fake);
  final Device fromNode = await change(pair.nodeBacked);

  expect(_describeDevice(fromFake), _describeDevice(fromNode));
}

void main() {
  test(
    'test_fake_device_repository_property_changes_agree_with_the_node_backed_'
    'repository',
    () async {
      final Random random = seededRandom(64401);

      for (int i = 0; i < _sequenceIterations; i += 1) {
        final _Pair pair = await _buildPair(random, peerProblem: null);
        final int stepCount = 1 + random.nextInt(_longestSequence);

        for (int step = 0; step < stepCount; step += 1) {
          await _changeBoth(random, pair);

          expect(
            _describeDevices(pair.fake.listDevices()),
            orderedEquals(_describeDevices(pair.nodeBacked.listDevices())),
          );
        }
      }
    },
  );

  test(
    'test_current_device_property_agrees_with_the_node_backed_repository',
    () async {
      final Random random = seededRandom(64402);

      for (int i = 0; i < _sequenceIterations; i += 1) {
        final _Pair pair = await _buildPair(random, peerProblem: null);
        final int stepCount = random.nextInt(_longestSequence);
        for (int step = 0; step < stepCount; step += 1) {
          await _changeBoth(random, pair);
        }

        expect(
          _describeDevice(pair.fake.currentDevice()),
          _describeDevice(pair.nodeBacked.currentDevice()),
        );
      }
    },
  );

  test('test_find_peer_address_problem_property_agrees_with_the_node_backed_'
      'repository', () async {
    final Random random = seededRandom(64403);

    for (int i = 0; i < _sequenceIterations; i += 1) {
      final String? problem = random.nextBool()
          ? null
          : 'no relay ${randomText(random)}';
      final _Pair pair = await _buildPair(random, peerProblem: problem);
      final int stepCount = random.nextInt(_longestSequence);
      for (int step = 0; step < stepCount; step += 1) {
        await _changeBoth(random, pair);
      }

      expect(
        pair.fake.findPeerAddressProblem(),
        pair.nodeBacked.findPeerAddressProblem(),
      );
    }
  });

  test(
    'test_find_device_property_agrees_with_the_node_backed_repository',
    () async {
      final Random random = seededRandom(64404);

      for (int i = 0; i < _sequenceIterations; i += 1) {
        final _Pair pair = await _buildPair(random, peerProblem: null);
        final int stepCount = random.nextInt(_longestSequence);
        for (int step = 0; step < stepCount; step += 1) {
          await _changeBoth(random, pair);
        }

        for (final Device listed in pair.nodeBacked.listDevices()) {
          expect(
            _describeDevice(pair.fake.findDevice(listed.id)),
            _describeDevice(pair.nodeBacked.findDevice(listed.id)),
          );
        }
      }
    },
  );
}
