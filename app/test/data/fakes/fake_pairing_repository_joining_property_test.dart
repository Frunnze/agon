import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_pairing.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/pairing.dart';
import 'package:agent_orchestration/data/rules/naming.dart';
import 'package:agent_orchestration/data/rules/setup_input_rules.dart';

import '../../support/random_inputs.dart';
import 'support/pairing_inputs.dart';
import 'support/pairing_steps.dart';
import 'support/refusals.dart';

const String _typePrefix = 'test_fake_pairing_repository';
const String _validCode = '4F7-K2Q';
const String _validServerAddress = 'https://relay.acme.dev';

String _randomNameCandidate(Random random) {
  final String validName = randomDeviceName(random);
  return pickOne(random, <String>[
    validName,
    validName.toUpperCase(),
    ' $validName',
    '$validName ',
    '',
    randomText(random),
    randomWordPhrase(random),
    validName * (1 + random.nextInt(8)),
  ]);
}

String _randomCodeCandidate(Random random) {
  return pickOne(random, <String>[_validCode, '4f7 k2q', randomText(random)]);
}

String? _randomServerCandidate(Random random) {
  return pickOne(random, <String?>[
    null,
    _validServerAddress,
    randomText(random),
  ]);
}

bool _isJoinRefusal(Object error) {
  return error is ArgumentError || error is FormatException;
}

void main() {
  test('${_typePrefix}_join_with_code_property_refuses_names_the_node_'
      'refuses', () async {
    final Random random = seededRandom(65301);

    for (int i = 0; i < propertyIterations; i += 1) {
      final PairingSetup setup = buildRandomPairingSetup(random);
      final String deviceName = _randomNameCandidate(random);

      final bool wasRefused = await isRefused(
        () => setup.pairing.joinWithCode(
          serverAddress: null,
          code: _validCode,
          deviceName: deviceName,
          role: pickOne(random, DeviceRole.values),
        ),
        isRefusal: _isJoinRefusal,
      );

      expect(
        wasRefused,
        describeNameProblem(deviceName) != null,
        reason: deviceName,
      );
    }
  });

  test('${_typePrefix}_join_with_code_property_outcome_keeps_the_device_'
      'and_role', () async {
    final Random random = seededRandom(65302);

    for (int i = 0; i < propertyIterations; i += 1) {
      final PairingSetup setup = buildRandomPairingSetup(random);
      final String deviceName = randomDeviceName(random);
      final DeviceRole role = pickOne(random, DeviceRole.values);

      final PairingOutcome outcome = await setup.pairing.joinWithCode(
        serverAddress: pickOne(random, <String?>[null, _validServerAddress]),
        code: _validCode,
        deviceName: deviceName,
        role: role,
      );

      expect(outcome.deviceName, deviceName);
      expect(outcome.role, role);
      expect(outcome.workspaceNames, galleryPairingOutcome.workspaceNames);
      expect(outcome.runnerLabels, galleryPairingOutcome.runnerLabels);
      expect(outcome.approverName, galleryPairingOutcome.approverName);
    }
  });

  test('${_typePrefix}_join_with_code_property_bad_codes_and_addresses_'
      'change_nothing', () async {
    final Random random = seededRandom(65303);

    for (int i = 0; i < propertyIterations; i += 1) {
      final PairingSetup setup = buildRandomPairingSetup(random);
      final PairingObservation before = observePairing(setup);
      final String code = _randomCodeCandidate(random);
      final String? serverAddress = _randomServerCandidate(random);
      final String? problem = describeJoinInputProblem(
        serverAddress: serverAddress,
        code: code,
      );

      final Future<PairingOutcome> joining = setup.pairing.joinWithCode(
        serverAddress: serverAddress,
        code: code,
        deviceName: randomDeviceName(random),
        role: pickOne(random, DeviceRole.values),
      );

      if (problem == null) {
        await joining;
      } else {
        await expectLater(joining, throwsFormatException);
      }
      expect(observePairing(setup), before);
      expect(setup.notifications.count, 0);
    }
  });

  test('${_typePrefix}_create_hosted_account_property_refuses_names_the_'
      'node_refuses', () async {
    final Random random = seededRandom(65304);

    for (int i = 0; i < propertyIterations; i += 1) {
      final PairingSetup setup = buildRandomPairingSetup(random);
      final String workspaceName = _randomNameCandidate(random);
      final String deviceName = _randomNameCandidate(random);
      final bool isEitherInvalid =
          describeNameProblem(workspaceName) != null ||
          describeNameProblem(deviceName) != null;

      final bool wasRefused = await isRefused(
        () => setup.pairing.createHostedAccount(
          workspaceName: workspaceName,
          deviceName: deviceName,
          role: pickOne(random, DeviceRole.values),
        ),
        isRefusal: _isJoinRefusal,
      );

      expect(
        wasRefused,
        isEitherInvalid,
        reason: '$workspaceName $deviceName',
      );
    }
  });

  test('${_typePrefix}_create_hosted_account_property_first_device_of_'
      'its_workspace', () async {
    final Random random = seededRandom(65305);

    for (int i = 0; i < propertyIterations; i += 1) {
      final PairingSetup setup = buildRandomPairingSetup(random);
      final String workspaceName = randomDeviceName(random);
      final String deviceName = randomDeviceName(random);
      final DeviceRole role = pickOne(random, DeviceRole.values);

      final PairingOutcome outcome = await setup.pairing.createHostedAccount(
        workspaceName: workspaceName,
        deviceName: deviceName,
        role: role,
      );

      expect(outcome.workspaceNames, <String>[workspaceName]);
      expect(outcome.deviceName, deviceName);
      expect(outcome.role, role);
      expect(outcome.approverName, isNull);
      expect(outcome.runnerLabels, galleryPairingOutcome.runnerLabels);
    }
  });

  test('${_typePrefix}_create_hosted_account_property_leaves_pairing_'
      'alone', () async {
    final Random random = seededRandom(65306);

    for (int i = 0; i < propertyIterations; i += 1) {
      final PairingSetup setup = buildRandomPairingSetup(random);
      final PairingObservation before = observePairing(setup);

      await isRefused(
        () => setup.pairing.createHostedAccount(
          workspaceName: _randomNameCandidate(random),
          deviceName: _randomNameCandidate(random),
          role: pickOne(random, DeviceRole.values),
        ),
        isRefusal: _isJoinRefusal,
      );

      expect(observePairing(setup), before);
      expect(setup.notifications.count, 0);
      expect(setup.pairing.findWaitingJoin(), isNull);
    }
  });
}
