import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/repository/device_repository.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../bridge/support/node_json_primitives.dart';
import '../../bridge/support/random_catalog_json.dart';
import '../../support/random_inputs.dart';
import '../node_backed/support/node_backed_harness.dart';
import '../node_backed/support/simulated_device_node.dart';

const String _typePrefix = 'test_fake_device_repository';
const String _thisDeviceText = 'this-device';
const int _iterations = 60;
const int _largestOtherDeviceCount = 4;
const int _longestSequence = 8;

typedef _Pair = ({
  FakeDeviceRepository fake,
  NodeBackedDeviceRepository nodeBacked,
});

Future<_Pair> _buildPair(Random random) async {
  final SimulatedDeviceNode simulated = SimulatedDeviceNode(
    thisDeviceId: _thisDeviceText,
  );
  final Map<String, Object?> thisDevice = randomDeviceJson(random);
  thisDevice['id'] = _thisDeviceText;
  thisDevice['revoked'] = false;
  simulated.devices[_thisDeviceText] = thisDevice;
  final int otherCount = random.nextInt(_largestOtherDeviceCount + 1);
  for (int i = 0; i < otherCount; i += 1) {
    simulated.addDeviceFromElsewhere(random);
  }
  final NodeBackedDeviceRepository nodeBacked = NodeBackedDeviceRepository(
    channel: buildSimulatedChannel(simulated.answer),
  );
  await nodeBacked.load();
  final FakeDeviceRepository fake = FakeDeviceRepository(
    devices: nodeBacked.listDevices(),
    currentDeviceId: const DeviceId(_thisDeviceText),
    peerAddressProblem: null,
    gitlessFolderPaths: const <String>{},
  );
  return (fake: fake, nodeBacked: nodeBacked);
}

String _describeJoined(Device joined) => 'joined ${joined.workspaces.length}';

String _describeRefused(Object error) => 'refused';

String _describeMissing(Object error) {
  final RecordNotFound missing = error as RecordNotFound;
  return 'missing ${missing.identifier}';
}

String _readMessage(Object error) => (error as StateError).message;

String _reportAccepted(Device joined) => 'accepted';

bool _isStateError(Object error) => error is StateError;

bool _isMissingRecord(Object error) => error is RecordNotFound;

Future<String> _describeOutcome(
  DeviceRepository repository,
  DeviceId deviceId,
  WorkspaceId workspaceId,
) {
  final Future<String> joined = repository
      .addDeviceToWorkspace(deviceId, workspaceId)
      .then(_describeJoined);
  final Future<String> refused = joined.catchError(
    _describeRefused,
    test: _isStateError,
  );
  return refused.catchError(_describeMissing, test: _isMissingRecord);
}

Future<String> _readRefusalMessage(
  DeviceRepository repository,
  DeviceId deviceId,
  WorkspaceId workspaceId,
) {
  final Future<String> accepted = repository
      .addDeviceToWorkspace(deviceId, workspaceId)
      .then(_reportAccepted);
  return accepted.catchError(_readMessage, test: _isStateError);
}

List<WorkspaceId> _keysOf(FakeDeviceRepository fake) {
  return fake.currentDevice().workspaces;
}

WorkspaceId _pickKeyedOrForeign(Random random, FakeDeviceRepository fake) {
  final List<WorkspaceId> keys = _keysOf(fake);
  if (keys.isEmpty || random.nextBool()) {
    return WorkspaceId(randomUuidText(random));
  }
  return pickOne(random, keys);
}

void main() {
  test('${_typePrefix}_add_device_to_workspace_property_refuses_a_foreign_'
      'workspace_with_the_node_message', () async {
    final Random random = seededRandom(92501);

    for (int i = 0; i < _iterations; i += 1) {
      final _Pair pair = await _buildPair(random);
      final Device target = pickOne(random, pair.fake.listDevices());
      final WorkspaceId foreign = WorkspaceId(randomUuidText(random));

      final String fromFake = await _readRefusalMessage(
        pair.fake,
        target.id,
        foreign,
      );
      final String fromNode = await _readRefusalMessage(
        pair.nodeBacked,
        target.id,
        foreign,
      );

      expect(fromFake, fromNode);
      expect(fromFake, contains(foreign.value));
    }
  });

  test('${_typePrefix}_add_device_to_workspace_property_join_sequences_'
      'agree_with_the_node', () async {
    final Random random = seededRandom(92502);
    final Set<String> seenKinds = <String>{};

    for (int i = 0; i < _iterations; i += 1) {
      final _Pair pair = await _buildPair(random);
      final int stepCount = 1 + random.nextInt(_longestSequence);

      for (int step = 0; step < stepCount; step += 1) {
        final Device target = pickOne(random, pair.fake.listDevices());
        final WorkspaceId workspaceId = _pickKeyedOrForeign(random, pair.fake);

        final String fromFake = await _describeOutcome(
          pair.fake,
          target.id,
          workspaceId,
        );
        final String fromNode = await _describeOutcome(
          pair.nodeBacked,
          target.id,
          workspaceId,
        );

        expect(fromFake, fromNode);
        seenKinds.add(fromFake);
      }
    }

    expect(seenKinds, contains('refused'));
    expect(seenKinds.any((String kind) => kind.startsWith('joined')), isTrue);
  });

  test('${_typePrefix}_add_device_to_workspace_property_an_unknown_device_'
      'is_missing_in_both_before_any_key_check', () async {
    final Random random = seededRandom(92503);

    for (int i = 0; i < _iterations; i += 1) {
      final _Pair pair = await _buildPair(random);
      final DeviceId unknown = DeviceId('unknown-${randomUuidText(random)}');
      final WorkspaceId workspaceId = _pickKeyedOrForeign(random, pair.fake);

      final String fromFake = await _describeOutcome(
        pair.fake,
        unknown,
        workspaceId,
      );
      final String fromNode = await _describeOutcome(
        pair.nodeBacked,
        unknown,
        workspaceId,
      );

      expect(fromFake, fromNode);
      expect(fromFake, 'missing ${unknown.value}');
    }
  });
}
