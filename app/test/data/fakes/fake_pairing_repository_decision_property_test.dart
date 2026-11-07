import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/pairing.dart';

import '../../support/random_inputs.dart';
import 'support/pairing_inputs.dart';
import 'support/pairing_steps.dart';

const String _typePrefix = 'test_fake_pairing_repository';
const int _largestExpiredAgeSeconds = 900;

PairingSetup _buildExpiredSetup(Random random) {
  final DateTime now = randomPairingMoment(random);
  final Duration overdue = Duration(
    seconds: random.nextInt(_largestExpiredAgeSeconds),
  );
  final DateTime expiresAt = now.subtract(overdue);
  final PairingSession expired = PairingSession(
    code: randomText(random),
    createdAt: expiresAt.subtract(pairingLifetime),
    expiresAt: expiresAt,
    rendezvousProblem: null,
  );
  return buildPairingSetup(
    session: random.nextBool() ? expired : null,
    request: randomPairingRequest(random),
    now: now,
  );
}

void main() {
  test('${_typePrefix}_find_pending_request_property_cleared_by_every_'
      'ending', () async {
    final Random random = seededRandom(65201);

    for (int i = 0; i < propertyIterations; i += 1) {
      final PairingSetup setup = buildWaitingPairingSetup(random);
      final int ending = random.nextInt(4);

      switch (ending) {
        case 0:
          await setup.pairing.startPairing();
        case 1:
          await setup.pairing.cancelPairing();
        default:
          await decidePairingRandomly(random, setup);
      }

      expect(setup.pairing.findPendingRequest(), isNull);
    }
  });

  test('${_typePrefix}_find_pending_request_property_survives_refused_'
      'approvals', () async {
    final Random random = seededRandom(65202);

    for (int i = 0; i < propertyIterations; i += 1) {
      final PairingSetup setup = buildWaitingPairingSetup(random);
      final PairingRequest? before = setup.pairing.findPendingRequest();
      final List<WorkspaceId> refusedChoice = random.nextBool()
          ? const <WorkspaceId>[]
          : <WorkspaceId>[
              ...randomApproverWorkspaces(random),
              foreignWorkspaceId,
            ];

      await expectLater(
        setup.pairing.approvePairing(refusedChoice),
        throwsArgumentError,
      );

      expect(identical(setup.pairing.findPendingRequest(), before), isTrue);
      expect(setup.pairing.findActiveSession(), isNotNull);
      expect(setup.notifications.count, 0);
    }
  });

  test('${_typePrefix}_find_pending_request_property_reads_are_quiet', () {
    final Random random = seededRandom(65203);

    for (int i = 0; i < propertyIterations; i += 1) {
      final PairingSetup setup = buildWaitingPairingSetup(random);

      final PairingRequest? first = setup.pairing.findPendingRequest();
      final PairingRequest? second = setup.pairing.findPendingRequest();

      expect(identical(first, second), isTrue);
      expect(setup.notifications.count, 0);
    }
  });

  test('${_typePrefix}_approve_pairing_property_device_carries_the_'
      'request', () async {
    final Random random = seededRandom(65204);

    for (int i = 0; i < propertyIterations; i += 1) {
      final PairingSetup setup = buildWaitingPairingSetup(random);
      final PairingRequest request = setup.pairing.findPendingRequest()!;
      final int deviceCountBefore = setup.devices.listDevices().length;

      final Device device = await setup.pairing.approvePairing(
        randomApproverWorkspaces(random),
      );

      expect(device.name, request.deviceName);
      expect(device.role, request.role);
      expect(device.keyKind, request.keyKind);
      expect(device.approvedBy, setup.devices.currentDevice().id);
      expect(device.pairedAt, setup.now);
      expect(device.revoked, isFalse);
      expect(setup.devices.findDevice(device.id).name, request.deviceName);
      expect(setup.devices.listDevices().length, deviceCountBefore + 1);
    }
  });

  test('${_typePrefix}_approve_pairing_property_grants_each_workspace_'
      'once', () async {
    final Random random = seededRandom(65205);

    for (int i = 0; i < propertyIterations; i += 1) {
      final PairingSetup setup = buildWaitingPairingSetup(random);
      final List<WorkspaceId> chosen = randomApproverWorkspaces(random);

      final Device device = await setup.pairing.approvePairing(chosen);

      expect(device.workspaces, listDistinctInOrder(chosen));
    }
  });

  test('${_typePrefix}_approve_pairing_property_refuses_workspaces_the_'
      'approver_lacks', () async {
    final Random random = seededRandom(65206);

    for (int i = 0; i < propertyIterations; i += 1) {
      final PairingSetup setup = buildWaitingPairingSetup(random);
      final int deviceCountBefore = setup.devices.listDevices().length;
      final List<WorkspaceId> chosen = <WorkspaceId>[
        ...randomApproverWorkspaces(random),
        foreignWorkspaceId,
      ]..shuffle(random);

      await expectLater(
        setup.pairing.approvePairing(chosen),
        throwsArgumentError,
      );

      expect(setup.devices.listDevices().length, deviceCountBefore);
      expect(setup.pairing.findPendingRequest(), isNotNull);
    }
  });

  test('${_typePrefix}_reject_pairing_property_closes_without_a_'
      'device', () async {
    final Random random = seededRandom(65207);

    for (int i = 0; i < propertyIterations; i += 1) {
      final PairingSetup setup = buildWaitingPairingSetup(random);
      final int deviceCountBefore = setup.devices.listDevices().length;

      await setup.pairing.rejectPairing();

      expect(setup.pairing.findActiveSession(), isNull);
      expect(setup.pairing.findPendingRequest(), isNull);
      expect(setup.devices.listDevices().length, deviceCountBefore);
    }
  });

  test('${_typePrefix}_reject_pairing_property_a_second_reject_is_'
      'refused', () async {
    final Random random = seededRandom(65208);

    for (int i = 0; i < propertyIterations; i += 1) {
      final PairingSetup setup = buildWaitingPairingSetup(random);

      await setup.pairing.rejectPairing();

      await expectLater(setup.pairing.rejectPairing(), throwsStateError);
      expect(setup.notifications.count, 1);
    }
  });

  test('${_typePrefix}_reject_pairing_property_refuses_once_the_code_'
      'expired', () async {
    final Random random = seededRandom(65209);

    for (int i = 0; i < propertyIterations; i += 1) {
      final PairingSetup setup = _buildExpiredSetup(random);
      final PairingRequest? before = setup.pairing.findPendingRequest();

      await expectLater(setup.pairing.rejectPairing(), throwsStateError);

      expect(identical(setup.pairing.findPendingRequest(), before), isTrue);
      expect(setup.notifications.count, 0);
    }
  });

  test('${_typePrefix}_require_pending_request_property_refuses_without_'
      'a_request', () async {
    final Random random = seededRandom(65210);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime now = randomPairingMoment(random);
      final PairingSetup setup = buildPairingSetup(
        session: liveSessionAt(now),
        request: null,
        now: now,
      );
      final int deviceCountBefore = setup.devices.listDevices().length;

      await expectLater(
        setup.pairing.approvePairing(randomApproverWorkspaces(random)),
        throwsStateError,
      );
      await expectLater(setup.pairing.rejectPairing(), throwsStateError);

      expect(setup.pairing.findActiveSession(), isNotNull);
      expect(setup.devices.listDevices().length, deviceCountBefore);
    }
  });

  test('${_typePrefix}_require_pending_request_property_refuses_once_the_'
      'code_expired', () async {
    final Random random = seededRandom(65211);

    for (int i = 0; i < propertyIterations; i += 1) {
      final PairingSetup setup = _buildExpiredSetup(random);
      final int deviceCountBefore = setup.devices.listDevices().length;

      await expectLater(
        setup.pairing.approvePairing(randomApproverWorkspaces(random)),
        throwsStateError,
      );

      expect(setup.devices.listDevices().length, deviceCountBefore);
      expect(setup.pairing.findPendingRequest(), isNotNull);
    }
  });

  test('${_typePrefix}_require_pending_request_property_empty_choice_is_'
      'refused_first', () async {
    final Random random = seededRandom(65212);

    for (int i = 0; i < propertyIterations; i += 1) {
      final PairingSetup setup = random.nextBool()
          ? buildWaitingPairingSetup(random)
          : _buildExpiredSetup(random);

      await expectLater(
        setup.pairing.approvePairing(const <WorkspaceId>[]),
        throwsArgumentError,
      );

      expect(setup.pairing.findPendingRequest(), isNotNull);
    }
  });
}
