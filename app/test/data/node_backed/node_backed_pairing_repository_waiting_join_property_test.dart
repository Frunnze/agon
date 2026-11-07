import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/pairing.dart';

import '../../support/random_inputs.dart';
import 'support/node_backed_pairing_rig.dart';
import 'support/simulated_pairing_node.dart';

const String _typePrefix = 'test_node_backed_pairing_repository';
const int _iterations = 15;
const int _fewestWaitsWithWords = simulatedPollsBeforeReveal + 1;
const int _largestExtraWaits = 3;
const List<String> _joinAnswers = <String>['approved', 'rejected', 'expired'];

typedef _SeenWaitingJoin = ({WaitingJoin? waitingJoin, int statusPolls});

final class _WaitingJoinRecorder {
  _WaitingJoinRecorder(this.rig) {
    rig.repository.addListener(record);
  }

  final PairingRig rig;
  final List<_SeenWaitingJoin> seen = <_SeenWaitingJoin>[];

  void record() {
    seen.add((
      waitingJoin: rig.repository.findWaitingJoin(),
      statusPolls: rig.node.simulated.joinStatusPollCount,
    ));
  }

  List<WaitingJoin> listShown() {
    final List<WaitingJoin> shown = <WaitingJoin>[];
    for (final _SeenWaitingJoin entry in seen) {
      final WaitingJoin? waitingJoin = entry.waitingJoin;
      if (waitingJoin != null && !shown.any(_isSameObject(waitingJoin))) {
        shown.add(waitingJoin);
      }
    }
    return shown;
  }
}

bool Function(WaitingJoin) _isSameObject(WaitingJoin waitingJoin) {
  return (WaitingJoin candidate) => identical(candidate, waitingJoin);
}

void _forgetTheJoinEnd(Object? joinEnd) {}

bool _isStateError(Object error) => error is StateError;

Future<void> _joinAndIgnoreTheAnswer(PairingRig rig) {
  final Future<PairingOutcome> joining = rig.repository.joinWithCode(
    serverAddress: null,
    code: simulatedDisplayCode,
    deviceName: 'joining-phone',
    role: DeviceRole.runner,
  );
  final Future<void> ended = joining.then(_forgetTheJoinEnd);
  return ended.catchError(_forgetTheJoinEnd, test: _isStateError);
}

PairingRig _buildJoiningRig(Random random, {required int fewestWaits}) {
  return buildPairingRig(
    pollsBeforeJoin: 0,
    joinPollsBeforeAnswer: fewestWaits + random.nextInt(_largestExtraWaits),
    joinAnswer: pickOne(random, _joinAnswers),
  );
}

void main() {
  test('${_typePrefix}_find_waiting_join_property_null_without_a_'
      'join', () async {
    final Random random = seededRandom(78601);

    for (int i = 0; i < _iterations; i += 1) {
      final PairingRig rig = buildPairingRig(pollsBeforeJoin: 0);
      final _WaitingJoinRecorder recorder = _WaitingJoinRecorder(rig);
      if (random.nextBool()) {
        await startAndWaitForRequest(rig);
      }
      if (random.nextBool()) {
        await rig.repository.createHostedAccount(
          workspaceName: 'home',
          deviceName: 'laptop',
          role: DeviceRole.client,
        );
      }

      expect(rig.repository.findWaitingJoin(), isNull);
      expect(recorder.listShown(), isEmpty);
      rig.dispose();
    }
  });

  test('${_typePrefix}_find_waiting_join_property_shows_the_typed_code_'
      'and_words', () async {
    final Random random = seededRandom(78602);

    for (int i = 0; i < _iterations; i += 1) {
      final PairingRig rig = _buildJoiningRig(
        random,
        fewestWaits: _fewestWaitsWithWords,
      );
      final _WaitingJoinRecorder recorder = _WaitingJoinRecorder(rig);

      await _joinAndIgnoreTheAnswer(rig);

      final List<WaitingJoin> shown = recorder.listShown();
      expect(shown, hasLength(1));
      expect(shown.single.code, simulatedDisplayCode);
      expect(shown.single.fingerprintWords, orderedEquals(simulatedWords));
      rig.dispose();
    }
  });

  test('${_typePrefix}_find_waiting_join_property_cleared_when_the_join_'
      'ends', () async {
    final Random random = seededRandom(78603);

    for (int i = 0; i < _iterations; i += 1) {
      final PairingRig rig = _buildJoiningRig(random, fewestWaits: 0);
      final _WaitingJoinRecorder recorder = _WaitingJoinRecorder(rig);

      await _joinAndIgnoreTheAnswer(rig);

      expect(rig.repository.findWaitingJoin(), isNull);
      expect(recorder.seen, isNotEmpty);
      expect(recorder.seen.last.waitingJoin, isNull);
      rig.dispose();
    }
  });

  test('${_typePrefix}_show_waiting_join_property_shown_once_per_'
      'join', () async {
    final Random random = seededRandom(78604);

    for (int i = 0; i < _iterations; i += 1) {
      final PairingRig rig = _buildJoiningRig(
        random,
        fewestWaits: _fewestWaitsWithWords,
      );
      final _WaitingJoinRecorder recorder = _WaitingJoinRecorder(rig);
      final int joinCount = 1 + random.nextInt(2);

      for (int join = 0; join < joinCount; join += 1) {
        await _joinAndIgnoreTheAnswer(rig);
      }

      expect(recorder.listShown(), hasLength(joinCount));
      rig.dispose();
    }
  });

  test('${_typePrefix}_show_waiting_join_property_hidden_until_the_words_'
      'arrive', () async {
    final Random random = seededRandom(78605);

    for (int i = 0; i < _iterations; i += 1) {
      final PairingRig rig = _buildJoiningRig(random, fewestWaits: 0);
      final _WaitingJoinRecorder recorder = _WaitingJoinRecorder(rig);

      await _joinAndIgnoreTheAnswer(rig);

      for (final _SeenWaitingJoin entry in recorder.seen) {
        if (entry.waitingJoin != null) {
          expect(entry.statusPolls, greaterThan(simulatedPollsBeforeReveal));
        }
      }
      rig.dispose();
    }
  });

  test('${_typePrefix}_show_waiting_join_property_never_shown_for_an_'
      'early_answer', () async {
    final Random random = seededRandom(78606);

    for (int i = 0; i < _iterations; i += 1) {
      final PairingRig rig = buildPairingRig(
        pollsBeforeJoin: 0,
        joinPollsBeforeAnswer: random.nextInt(_fewestWaitsWithWords),
        joinAnswer: pickOne(random, _joinAnswers),
      );
      final _WaitingJoinRecorder recorder = _WaitingJoinRecorder(rig);

      await _joinAndIgnoreTheAnswer(rig);

      expect(recorder.listShown(), isEmpty);
      rig.dispose();
    }
  });
}
