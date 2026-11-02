import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/account_values.dart' as node;
import 'package:agent_orchestration/bridge/codecs/pairing_values.dart' as node;
import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/pairing.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';
import 'package:agent_orchestration/data/node_backed.dart';

import '../../bridge/support/random_account_json.dart';
import '../../support/random_inputs.dart';
import 'support/simulated_pairing_node.dart';

const Duration _pollInterval = Duration(milliseconds: 1);
const int _joinIterations = 20;
const int _largestWaitingPolls = 3;
const int _fewestWaitingPolls = simulatedPollsBeforeReveal + 1;
const int _largestWordCount = 5;
const List<String> _joinAnswers = <String>['approved', 'rejected', 'expired'];

final class _WaitingJoinRecorder {
  _WaitingJoinRecorder(this.repository);

  final NodeBackedPairingRepository repository;
  final List<WaitingJoin?> seen = <WaitingJoin?>[];

  void record() => seen.add(repository.findWaitingJoin());
}

void main() {
  test('test_map_waiting_join_from_node_property_words_only_once_known', () {
    final Random random = seededRandom(10021);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.PendingJoin pending = node.PendingJoin.fromJson(
        randomPendingJoinJson(random),
      );
      final List<String> words = List<String>.generate(
        random.nextInt(_largestWordCount),
        (int position) => randomText(random),
      );
      final node.JoinWaiting status = node.JoinWaiting(
        fingerprintWords: words,
      );

      final WaitingJoin? waiting = mapWaitingJoinFromNode(pending, status);

      if (status.fingerprintWords.isEmpty) {
        expect(waiting, isNull);
      } else {
        expect(waiting?.code, pending.displayCode);
        expect(waiting?.fingerprintWords, status.fingerprintWords);
      }
    }
  });

  test(
    'test_join_with_code_property_words_shown_only_while_waiting',
    () async {
      final Random random = seededRandom(10022);
      for (int i = 0; i < _joinIterations; i += 1) {
        final String answer = pickOne(random, _joinAnswers);
        final SimulatedPairingNode simulated = SimulatedPairingNode(
          startedAt: '2026-10-31T12:00:00Z',
          expiresAt: '2026-10-31T12:05:00Z',
          pollsBeforeJoin: 0,
          joinPollsBeforeAnswer:
              _fewestWaitingPolls + random.nextInt(_largestWaitingPolls),
          joinAnswer: answer,
        );
        final NodeBackedPairingRepository repository =
            NodeBackedPairingRepository(
              channel: simulated.channel,
              clock: FixedClock(DateTime.utc(2026, 10, 31, 12)),
              pollInterval: _pollInterval,
              runnerLabels: const <String>[],
            );
        final _WaitingJoinRecorder recorder = _WaitingJoinRecorder(repository);
        repository.addListener(recorder.record);
        expect(repository.findWaitingJoin(), isNull);

        final Future<PairingOutcome> joining = repository.joinWithCode(
          serverAddress: 'http://127.0.0.1:7070',
          code: simulatedDisplayCode,
          deviceName: 'joining-phone',
          role: DeviceRole.runner,
        );
        if (answer == 'approved') {
          await joining;
        } else {
          await expectLater(joining, throwsStateError);
        }

        final WaitingJoin shown = recorder.seen.whereType<WaitingJoin>().first;
        expect(shown.fingerprintWords, simulatedWords);
        expect(shown.code, simulatedDisplayCode);
        expect(recorder.seen.last, isNull);
        expect(repository.findWaitingJoin(), isNull);
        repository.dispose();
      }
    },
  );
}
