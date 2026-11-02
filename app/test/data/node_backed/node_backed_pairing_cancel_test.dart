import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/node_backed.dart';

import '../../support/random_inputs.dart';
import 'support/late_answer_transport.dart';
import 'support/pairing_repository_harness.dart';
import 'support/simulated_pairing_node.dart';

const int _cancelIterations = 25;
const Duration _pastExpiry = Duration(minutes: 6);
const String _pairingRequestCommand = 'pairing_request';

void main() {
  test('test_cancel_pairing_property_sends_the_code_and_closes', () async {
    final Random random = seededRandom(9981);
    for (int i = 0; i < _cancelIterations; i += 1) {
      final bool waitsForRequest = random.nextBool();
      final SimulatedPairingNode simulated = buildPairingNode(
        pollsBeforeJoin: random.nextInt(3),
      );
      final NodeBackedPairingRepository repository = buildPairingRepository(
        simulated,
        FixedClock(pairingStart),
      );
      int notifications = 0;
      repository.addListener(() => notifications += 1);
      await repository.startPairing();
      if (waitsForRequest) {
        await waitUntil(() => repository.findPendingRequest() != null);
      }
      final int notificationsBeforeCancel = notifications;

      await repository.cancelPairing();

      expect(simulated.cancelledCodes, <Object?>[simulatedPairingCode]);
      expect(repository.findActiveSession(), isNull);
      expect(repository.findPendingRequest(), isNull);
      expect(notifications, greaterThan(notificationsBeforeCancel));
      final int pollsAfterCancel = simulated.pairingRequestPollCount;
      await Future<void>.delayed(pairingWaitStep * 5);
      expect(simulated.pairingRequestPollCount, pollsAfterCancel);
      repository.dispose();
    }
  });

  test('test_cancel_pairing_property_read_in_flight_never_escapes', () async {
    for (int i = 0; i < _cancelIterations; i += 1) {
      final SimulatedPairingNode simulated = buildPairingNode(
        pollsBeforeJoin: 1000,
      );
      final LateAnswerTransport transport = LateAnswerTransport(
        answer: simulated.answer,
        heldCommandName: _pairingRequestCommand,
      );
      final NodeBackedPairingRepository repository =
          NodeBackedPairingRepository(
            channel: NodeCommandChannel(transport: transport),
            clock: FixedClock(pairingStart),
            pollInterval: pairingWaitStep,
            runnerLabels: pairingRunnerLabels,
          );
      await repository.startPairing();
      await waitUntil(() => transport.isHoldingCommand);

      await repository.cancelPairing();
      transport.releaseHeldCommand();
      await Future<void>.delayed(pairingWaitStep * 5);

      expect(repository.findActiveSession(), isNull);
      expect(repository.findPendingRequest(), isNull);
      repository.dispose();
    }
  });

  test('test_cancel_pairing_property_needs_a_showing_code', () async {
    final Random random = seededRandom(9982);
    for (int i = 0; i < _cancelIterations; i += 1) {
      final MovableClock clock = MovableClock(pairingStart);
      final SimulatedPairingNode simulated = buildPairingNode(
        pollsBeforeJoin: 1000,
      );
      final NodeBackedPairingRepository repository = buildPairingRepository(
        simulated,
        clock,
      );
      if (random.nextBool()) {
        await repository.startPairing();
        clock.moment = pairingStart.add(_pastExpiry);
      }

      await expectLater(repository.cancelPairing(), throwsStateError);

      expect(simulated.cancelledCodes, isEmpty);
      repository.dispose();
    }
  });
}
