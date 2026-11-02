import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/pairing.dart';
import 'package:agent_orchestration/data/node_backed.dart';

import '../../support/random_inputs.dart';
import 'support/pairing_repository_harness.dart';
import 'support/simulated_pairing_node.dart';

const int _pairingIterations = 25;
const List<String> _joinAnswers = <String>['approved', 'rejected', 'expired'];

void main() {
  test('test_start_pairing_property_session_counts_down_to_expiry', () async {
    final Random random = seededRandom(9971);
    for (int i = 0; i < _pairingIterations; i += 1) {
      final MovableClock clock = MovableClock(pairingStart);
      final SimulatedPairingNode simulated = buildPairingNode(
        pollsBeforeJoin: 1000,
      );
      final NodeBackedPairingRepository repository = buildPairingRepository(
        simulated,
        clock,
      );
      int notifications = 0;
      repository.addListener(() => notifications += 1);

      final PairingSession session = await repository.startPairing();
      expect(session.code, simulatedDisplayCode);
      expect(session.createdAt, pairingStart);
      expect(session.expiresAt, pairingStart.add(const Duration(minutes: 5)));
      final int notificationsAfterStart = notifications;
      await waitUntil(() => notifications > notificationsAfterStart + 1);

      clock.moment = pairingStart.add(Duration(seconds: random.nextInt(600)));
      final bool isExpired = !session.expiresAt.isAfter(clock.moment);
      expect(repository.findActiveSession() == null, isExpired);
      if (isExpired) {
        await Future<void>.delayed(pairingWaitStep * 2);
        final int pollsAtExpiry = simulated.pairingRequestPollCount;
        await Future<void>.delayed(pairingWaitStep * 5);
        expect(simulated.pairingRequestPollCount, pollsAtExpiry);
      }
      repository.dispose();
    }
  });

  test('test_find_pending_request_property_appears_after_polling', () async {
    final Random random = seededRandom(9972);
    for (int i = 0; i < _pairingIterations; i += 1) {
      final int pollsBeforeJoin = random.nextInt(4);
      final SimulatedPairingNode simulated = buildPairingNode(
        pollsBeforeJoin: pollsBeforeJoin,
      );
      final NodeBackedPairingRepository repository = buildPairingRepository(
        simulated,
        FixedClock(pairingStart),
      );
      await repository.startPairing();
      expect(repository.findPendingRequest(), isNull);

      await waitUntil(() => repository.findPendingRequest() != null);
      final PairingRequest? request = repository.findPendingRequest();
      expect(request?.deviceName, 'joining-phone');
      expect(request?.role, DeviceRole.runner);
      expect(request?.keyKind, HardwareKeyKind.secureEnclave);
      expect(request?.codeUsed, simulatedDisplayCode);
      expect(request?.fingerprintWords, simulatedWords);
      expect(simulated.pairingRequestPollCount, pollsBeforeJoin + 1);
      repository.dispose();
    }
  });

  test('test_approve_pairing_property_returns_the_joined_device', () async {
    final Random random = seededRandom(9973);
    for (int i = 0; i < _pairingIterations; i += 1) {
      final SimulatedPairingNode simulated = buildPairingNode();
      final NodeBackedPairingRepository repository = buildPairingRepository(
        simulated,
        FixedClock(pairingStart),
      );
      await expectLater(
        repository.approvePairing(const <WorkspaceId>[WorkspaceId('home')]),
        throwsStateError,
      );
      await repository.startPairing();
      await waitUntil(() => repository.findPendingRequest() != null);
      await expectLater(
        repository.approvePairing(const <WorkspaceId>[]),
        throwsArgumentError,
      );

      final List<WorkspaceId> workspaces = <WorkspaceId>[
        for (int j = 0; j <= random.nextInt(3); j += 1) WorkspaceId('w-$j'),
      ];
      final Device device = await repository.approvePairing(workspaces);
      expect(device.sealingPublicKey, simulatedJoiningKey);
      expect(device.approvedBy?.value, simulatedApproverId);
      expect(simulated.approvedWorkspaceIds, workspaces);
      expect(repository.findActiveSession(), isNull);
      expect(repository.findPendingRequest(), isNull);
      repository.dispose();
    }
  });

  test('test_reject_pairing_property_closes_the_session', () async {
    for (int i = 0; i < _pairingIterations; i += 1) {
      final SimulatedPairingNode simulated = buildPairingNode();
      final NodeBackedPairingRepository repository = buildPairingRepository(
        simulated,
        FixedClock(pairingStart),
      );
      await expectLater(repository.rejectPairing(), throwsStateError);
      await repository.startPairing();
      await waitUntil(() => repository.findPendingRequest() != null);

      await repository.rejectPairing();

      expect(simulated.rejectedCount, 1);
      expect(repository.findActiveSession(), isNull);
      expect(repository.findPendingRequest(), isNull);
      repository.dispose();
    }
  });

  test('test_join_with_code_property_outcome_follows_join_state', () async {
    final Random random = seededRandom(9975);
    for (int i = 0; i < _pairingIterations; i += 1) {
      final String answer = pickOne(random, _joinAnswers);
      final int waits = random.nextInt(3);
      final SimulatedPairingNode simulated = buildPairingNode(
        joinPollsBeforeAnswer: waits,
        joinAnswer: answer,
      );
      final NodeBackedPairingRepository repository = buildPairingRepository(
        simulated,
        FixedClock(pairingStart),
      );
      final String? serverAddress = pickOne(random, <String?>[
        'http://127.0.0.1:7070',
        null,
      ]);
      final Future<PairingOutcome> joining = repository.joinWithCode(
        serverAddress: serverAddress,
        code: simulatedDisplayCode,
        deviceName: 'joining-phone',
        role: DeviceRole.runner,
      );

      if (answer == 'approved') {
        final PairingOutcome outcome = await joining;
        expect(outcome.deviceName, 'joining-phone');
        expect(outcome.workspaceNames, <String>['home']);
        expect(outcome.runnerLabels, pairingRunnerLabels);
        expect(outcome.approverName, simulatedApproverName);
      } else {
        await expectLater(joining, throwsStateError);
      }
      expect(simulated.joinStatusPollCount, waits + 1);
      expect(simulated.joinServerAddresses, <String?>[serverAddress]);
      await expectLater(
        repository.joinWithCode(
          serverAddress: 'ftp://server',
          code: randomText(random),
          deviceName: 'joining-phone',
          role: DeviceRole.client,
        ),
        throwsFormatException,
      );
      repository.dispose();
    }
  });

  test(
    'test_create_hosted_account_property_outcome_has_no_approver',
    () async {
      final Random random = seededRandom(9976);

      for (int i = 0; i < propertyIterations; i += 1) {
        final SimulatedPairingNode simulated = buildPairingNode();
        final NodeBackedPairingRepository repository = buildPairingRepository(
          simulated,
          FixedClock(pairingStart),
        );
        final String workspaceName = 'space-${random.nextInt(1000)}';
        final DeviceRole role = pickOne(random, DeviceRole.values);

        final PairingOutcome outcome = await repository.createHostedAccount(
          workspaceName: workspaceName,
          deviceName: 'laptop',
          role: role,
        );

        expect(outcome.approverName, isNull);
        expect(outcome.workspaceNames, <String>[workspaceName]);
        expect(outcome.runnerLabels, pairingRunnerLabels);
        await expectLater(
          repository.createHostedAccount(
            workspaceName: workspaceName,
            deviceName: 'laptop',
            role: role,
          ),
          throwsStateError,
        );
        await expectLater(
          repository.createHostedAccount(
            workspaceName: workspaceName,
            deviceName: 'Laptop ${randomText(random)}',
            role: role,
          ),
          throwsArgumentError,
        );
        repository.dispose();
      }
    },
  );
}
