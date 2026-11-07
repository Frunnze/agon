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

const String _thisDeviceText = 'this-device';
const String _unknownDevicePrefix = 'unknown-';
const int _sequenceIterations = 40;
const int _largestOtherDeviceCount = 5;
const int _longestSequence = 10;
const int _unknownTargetOdds = 6;

enum _MembershipAction { revoke, join, leave }

enum _Outcome { succeeded, refusedWithStateError, refusedAsMissingRecord }

typedef _MembershipStep = ({
  _MembershipAction action,
  DeviceId deviceId,
  WorkspaceId workspaceId,
});

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
  final int otherCount = random.nextInt(_largestOtherDeviceCount);
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

DeviceId _pickTarget(Random random, List<Device> devices) {
  if (random.nextInt(_unknownTargetOdds) == 0) {
    return DeviceId('$_unknownDevicePrefix${randomUuidText(random)}');
  }
  return pickOne(random, devices).id;
}

WorkspaceId _pickWorkspace(Random random, List<Device> devices) {
  final List<WorkspaceId> joinedSomewhere = <WorkspaceId>[
    for (final Device device in devices) ...device.workspaces,
  ];
  if (joinedSomewhere.isEmpty || random.nextBool()) {
    return WorkspaceId(randomUuidText(random));
  }
  return pickOne(random, joinedSomewhere);
}

_MembershipStep _pickStep(
  Random random,
  List<Device> devices,
  _MembershipAction action,
) {
  return (
    action: action,
    deviceId: _pickTarget(random, devices),
    workspaceId: _pickWorkspace(random, devices),
  );
}

Future<Device> _applyStep(DeviceRepository repository, _MembershipStep step) {
  switch (step.action) {
    case _MembershipAction.revoke:
      return repository.revokeDevice(step.deviceId);
    case _MembershipAction.join:
      return repository.addDeviceToWorkspace(step.deviceId, step.workspaceId);
    case _MembershipAction.leave:
      return repository.removeDeviceFromWorkspace(
        step.deviceId,
        step.workspaceId,
      );
  }
}

_Outcome _reportSucceeded(Device changed) => _Outcome.succeeded;

_Outcome _reportStateError(Object error) => _Outcome.refusedWithStateError;

_Outcome _reportMissingRecord(Object error) => _Outcome.refusedAsMissingRecord;

bool _isStateError(Object error) => error is StateError;

bool _isMissingRecord(Object error) => error is RecordNotFound;

Future<_Outcome> _runStep(DeviceRepository repository, _MembershipStep step) {
  final Future<_Outcome> succeeded = _applyStep(
    repository,
    step,
  ).then(_reportSucceeded);
  final Future<_Outcome> stateChecked = succeeded.catchError(
    _reportStateError,
    test: _isStateError,
  );
  return stateChecked.catchError(_reportMissingRecord, test: _isMissingRecord);
}

List<Object?> _describeDevices(List<Device> devices) {
  final List<Object?> descriptions = <Object?>[];
  for (final Device device in devices) {
    final List<String> workspaceValues = <String>[
      for (final WorkspaceId workspaceId in device.workspaces)
        workspaceId.value,
    ];
    descriptions.add(<Object?>[
      device.id.value,
      device.revoked,
      workspaceValues,
    ]);
  }
  return descriptions;
}

Future<Set<_Outcome>> _runAgreeingSequences(
  Random random,
  List<_MembershipAction> actions,
) async {
  final Set<_Outcome> seenOutcomes = <_Outcome>{};
  for (int i = 0; i < _sequenceIterations; i += 1) {
    final _Pair pair = await _buildPair(random);
    final int stepCount = 1 + random.nextInt(_longestSequence);

    for (int stepNumber = 0; stepNumber < stepCount; stepNumber += 1) {
      final _MembershipStep step = _pickStep(
        random,
        pair.fake.listDevices(),
        pickOne(random, actions),
      );
      final _Outcome fakeOutcome = await _runStep(pair.fake, step);
      final _Outcome nodeOutcome = await _runStep(pair.nodeBacked, step);

      expect(fakeOutcome, nodeOutcome, reason: '$step');
      expect(
        _describeDevices(pair.fake.listDevices()),
        _describeDevices(pair.nodeBacked.listDevices()),
      );
      seenOutcomes.add(fakeOutcome);
    }
  }
  return seenOutcomes;
}

void main() {
  test('test_revoke_device_property_refuses_the_same_steps_as_the_node_'
      'backed_repository', () async {
    final Set<_Outcome> seenOutcomes = await _runAgreeingSequences(
      seededRandom(71401),
      const <_MembershipAction>[_MembershipAction.revoke],
    );

    expect(seenOutcomes, _Outcome.values.toSet());
  });

  test('test_add_device_to_workspace_property_refuses_the_same_steps_as_the_'
      'node_backed_repository', () async {
    final Set<_Outcome> seenOutcomes = await _runAgreeingSequences(
      seededRandom(71402),
      const <_MembershipAction>[_MembershipAction.join],
    );

    expect(seenOutcomes, _Outcome.values.toSet());
  });

  test('test_remove_device_from_workspace_property_refuses_the_same_steps_as_'
      'the_node_backed_repository', () async {
    final Set<_Outcome> seenOutcomes = await _runAgreeingSequences(
      seededRandom(71403),
      const <_MembershipAction>[_MembershipAction.leave],
    );

    expect(seenOutcomes, <_Outcome>{
      _Outcome.succeeded,
      _Outcome.refusedAsMissingRecord,
    });
  });

  test('test_fake_device_repository_property_mixed_membership_sequences_end_'
      'like_the_node_backed_repository', () async {
    final Set<_Outcome> seenOutcomes = await _runAgreeingSequences(
      seededRandom(71404),
      _MembershipAction.values,
    );

    expect(seenOutcomes, _Outcome.values.toSet());
  });
}
