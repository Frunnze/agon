import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/pairing.dart';
import 'package:agent_orchestration/data/rules/naming.dart';

import '../../support/random_inputs.dart';
import '../fakes/support/pairing_inputs.dart';
import 'support/node_backed_pairing_rig.dart';
import 'support/pairing_repository_harness.dart';

const String _typePrefix = 'test_node_backed_pairing_repository';
const int _iterations = 15;
const int _neverJoins = 1000000;
const int _quietPolls = 5;

void main() {
  test('${_typePrefix}_create_hosted_account_property_bad_names_refused_'
      'before_the_node', () async {
    final Random random = seededRandom(78507);

    for (int i = 0; i < _iterations; i += 1) {
      final bool isDeviceNameBad = random.nextBool();
      final String deviceName = isDeviceNameBad
          ? randomBadName(random)
          : randomDeviceName(random);
      final String workspaceName = isDeviceNameBad
          ? randomDeviceName(random)
          : randomBadName(random);
      final PairingRig rig = buildPairingRig(pollsBeforeJoin: 0);

      final String refusal = await describeArgumentRefusal(
        rig.repository.createHostedAccount(
          workspaceName: workspaceName,
          deviceName: deviceName,
          role: pickOne(random, DeviceRole.values),
        ),
      );

      expect(
        refusal,
        describeNameProblem(deviceName) ?? describeNameProblem(workspaceName),
      );
      expect(rig.node.commandNames, isEmpty);
      rig.dispose();
    }
  });

  test('${_typePrefix}_create_hosted_account_property_agrees_with_the_'
      'fake', () async {
    final Random random = seededRandom(78508);

    for (int i = 0; i < _iterations; i += 1) {
      final String deviceName = randomDeviceName(random);
      final String workspaceName = randomDeviceName(random);
      final PairingRig rig = buildPairingRig(pollsBeforeJoin: 0);
      final PairingSetup fake = buildPairingSetup(
        session: null,
        request: null,
        now: pairingStart,
      );

      final PairingOutcome nodeOutcome = await rig.repository
          .createHostedAccount(
            workspaceName: workspaceName,
            deviceName: deviceName,
            role: DeviceRole.client,
          );
      final PairingOutcome fakeOutcome = await fake.pairing
          .createHostedAccount(
            workspaceName: workspaceName,
            deviceName: deviceName,
            role: DeviceRole.client,
          );

      expect(nodeOutcome.deviceName, fakeOutcome.deviceName);
      expect(nodeOutcome.role, fakeOutcome.role);
      expect(nodeOutcome.workspaceNames, fakeOutcome.workspaceNames);
      expect(nodeOutcome.approverName, isNull);
      expect(fakeOutcome.approverName, isNull);
      rig.dispose();
    }
  });

  test('${_typePrefix}_create_hosted_account_property_leaves_the_pairing_'
      'session_alone', () async {
    final Random random = seededRandom(78509);

    for (int i = 0; i < _iterations; i += 1) {
      final PairingRig rig = buildPairingRig(pollsBeforeJoin: _neverJoins);
      final PairingSession session = await rig.repository.startPairing();

      await rig.repository.createHostedAccount(
        workspaceName: randomDeviceName(random),
        deviceName: randomDeviceName(random),
        role: pickOne(random, DeviceRole.values),
      );
      final int pollsAfterAccount = rig.node.countCommands(
        pairingRequestCommand,
      );
      await waitForPolls(_quietPolls);

      expect(identical(rig.repository.findActiveSession(), session), isTrue);
      expect(
        rig.node.countCommands(pairingRequestCommand),
        greaterThan(pollsAfterAccount),
      );
      rig.dispose();
    }
  });
}
