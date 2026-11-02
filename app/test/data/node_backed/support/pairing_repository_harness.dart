import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/node_backed.dart';

import 'simulated_pairing_node.dart';

const Duration _pollInterval = Duration(milliseconds: 1);
const Duration pairingWaitStep = Duration(milliseconds: 2);
const int _waitLimit = 500;
const List<String> pairingRunnerLabels = <String>['mac', 'gpu'];
const Duration _pairingLifetime = Duration(minutes: 5);
final DateTime pairingStart = DateTime.utc(2026, 10, 31, 12);

final class MovableClock implements Clock {
  MovableClock(this.moment);

  DateTime moment;

  @override
  DateTime now() => moment;
}

SimulatedPairingNode buildPairingNode({
  int pollsBeforeJoin = 0,
  int joinPollsBeforeAnswer = 0,
  String joinAnswer = 'approved',
}) {
  return SimulatedPairingNode(
    startedAt: pairingStart.toIso8601String(),
    expiresAt: pairingStart.add(_pairingLifetime).toIso8601String(),
    pollsBeforeJoin: pollsBeforeJoin,
    joinPollsBeforeAnswer: joinPollsBeforeAnswer,
    joinAnswer: joinAnswer,
  );
}

NodeBackedPairingRepository buildPairingRepository(
  SimulatedPairingNode simulated,
  Clock clock,
) {
  return NodeBackedPairingRepository(
    channel: simulated.channel,
    clock: clock,
    pollInterval: _pollInterval,
    runnerLabels: pairingRunnerLabels,
  );
}

Future<void> waitUntil(bool Function() condition) async {
  for (int i = 0; i < _waitLimit; i += 1) {
    if (condition()) {
      return;
    }
    await Future<void>.delayed(pairingWaitStep);
  }
  fail('the condition did not hold in time');
}
