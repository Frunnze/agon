import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/data/models/pairing.dart';
import 'package:agent_orchestration/data/node_backed.dart';

import '../../bridge/support/scripted_node_transport.dart';
import '../../support/random_inputs.dart';
import 'support/pairing_repository_harness.dart';
import 'support/simulated_node_replies.dart';
import 'support/simulated_pairing_node.dart';

const int _pairingIterations = 25;
const int _largestStartCount = 5;
const int _neverJoins = 1000000;
const String _statusCommand = 'status';

String? _randomProblem(Random random) {
  if (random.nextBool()) {
    return null;
  }
  return randomText(random);
}

final class _RecordingPairingNode {
  _RecordingPairingNode({required this.simulated, required this.statusReply});

  final SimulatedPairingNode simulated;
  final String statusReply;
  final List<String> commandNames = <String>[];

  late final NodeCommandChannel channel = buildSimulatedChannel(answer);

  String answer(String inputJson) {
    final JsonObject command = decodeObject(jsonDecode(inputJson));
    final String commandName = decodeText(command['command']);
    commandNames.add(commandName);

    if (commandName == _statusCommand) {
      return statusReply;
    }
    return simulated.answer(inputJson);
  }
}

NodeBackedPairingRepository _buildRecordedRepository(
  _RecordingPairingNode recording,
) {
  return NodeBackedPairingRepository(
    channel: recording.channel,
    clock: MovableClock(pairingStart),
    pollInterval: pairingWaitStep,
    runnerLabels: pairingRunnerLabels,
  );
}

String _randomStatusReply(Random random) {
  if (random.nextBool()) {
    return encodeErrorReply(simulatedOutageMessage);
  }
  return encodeSuccessReply(<String, Object?>{
    'server_reachable': random.nextBool(),
    'rendezvous_problem': randomText(random),
  });
}

void main() {
  test(
    'test_start_pairing_property_session_carries_rendezvous_problem',
    () async {
      final Random random = seededRandom(73601);

      for (int i = 0; i < _pairingIterations; i += 1) {
        final String? problem = _randomProblem(random);
        final SimulatedPairingNode simulated = buildPairingNode(
          pollsBeforeJoin: _neverJoins,
        );
        simulated.rendezvousProblem = problem;
        final NodeBackedPairingRepository repository = buildPairingRepository(
          simulated,
          MovableClock(pairingStart),
        );

        final PairingSession session = await repository.startPairing();

        expect(session.rendezvousProblem, problem);
        expect(repository.findActiveSession()?.rendezvousProblem, problem);
        repository.dispose();
      }
    },
  );

  test('test_start_pairing_property_asks_the_node_only_to_start', () async {
    final Random random = seededRandom(73602);

    for (int i = 0; i < _pairingIterations; i += 1) {
      final SimulatedPairingNode simulated = buildPairingNode(
        pollsBeforeJoin: _neverJoins,
      );
      simulated.rendezvousProblem = _randomProblem(random);
      final _RecordingPairingNode recording = _RecordingPairingNode(
        simulated: simulated,
        statusReply: _randomStatusReply(random),
      );
      final NodeBackedPairingRepository repository = _buildRecordedRepository(
        recording,
      );

      await repository.startPairing();

      expect(recording.commandNames, equals(<String>['start_pairing']));
      repository.dispose();
    }
  });

  test(
    'test_start_pairing_property_status_never_changes_the_problem',
    () async {
      final Random random = seededRandom(73604);

      for (int i = 0; i < _pairingIterations; i += 1) {
        final String? problem = _randomProblem(random);
        final SimulatedPairingNode simulated = buildPairingNode(
          pollsBeforeJoin: _neverJoins,
        );
        simulated.rendezvousProblem = problem;
        final _RecordingPairingNode recording = _RecordingPairingNode(
          simulated: simulated,
          statusReply: _randomStatusReply(random),
        );
        final NodeBackedPairingRepository repository =
            _buildRecordedRepository(recording);

        final PairingSession session = await repository.startPairing();

        expect(session.rendezvousProblem, problem);
        expect(session.code, simulatedDisplayCode);
        repository.dispose();
      }
    },
  );

  test(
    'test_start_pairing_property_each_new_code_shows_its_own_problem',
    () async {
      final Random random = seededRandom(73603);

      for (int i = 0; i < _pairingIterations; i += 1) {
        final SimulatedPairingNode simulated = buildPairingNode(
          pollsBeforeJoin: _neverJoins,
        );
        final NodeBackedPairingRepository repository = buildPairingRepository(
          simulated,
          MovableClock(pairingStart),
        );
        final int startCount = 1 + random.nextInt(_largestStartCount);

        for (int start = 0; start < startCount; start += 1) {
          final String? problem = _randomProblem(random);
          simulated.rendezvousProblem = problem;

          await repository.startPairing();

          expect(repository.findActiveSession()?.rendezvousProblem, problem);
        }
        repository.dispose();
      }
    },
  );
}
