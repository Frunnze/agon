import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/pairing.dart';

import '../../support/random_inputs.dart';
import 'support/node_backed_pairing_rig.dart';

const String _typePrefix = 'test_node_backed_pairing_repository';
const int _iterations = 12;
const int _neverJoins = 1000000;
const int _quietPolls = 6;
const int _largestRestarts = 3;
const int _largestPollsBeforeJoin = 3;

enum _PairingState { fresh, live, requested, expired, cancelled }

Future<void> _guardEscapes(
  Future<void> Function() action,
  List<Object> escaped,
) {
  return runZonedGuarded<Future<void>>(
    action,
    (Object error, StackTrace _) => escaped.add(error),
  )!;
}

Future<void> _bringTo(PairingRig rig, _PairingState state) async {
  switch (state) {
    case _PairingState.fresh:
      return;
    case _PairingState.live:
      await rig.repository.startPairing();
    case _PairingState.requested:
      await startAndWaitForRequest(rig);
    case _PairingState.expired:
      final PairingSession session = await rig.repository.startPairing();
      rig.clock.moment = session.expiresAt;
    case _PairingState.cancelled:
      await rig.repository.startPairing();
      await rig.repository.cancelPairing();
  }
}

Future<void> _startWithAHeldRead(PairingRig rig, List<Object> escaped) async {
  rig.transport.holdNextReply(pairingRequestCommand);
  await _guardEscapes(rig.repository.startPairing, escaped);
  await rig.transport.heldReplyArrival;
}

Future<void> _releaseTheHeldRead(PairingRig rig) async {
  rig.transport.releaseHeldReply();
  await waitForPolls(_quietPolls);
}

void main() {
  test('${_typePrefix}_is_current_code_property_an_old_code_failure_'
      'stays_quiet', () async {
    for (int i = 0; i < _iterations; i += 1) {
      final List<Object> escaped = <Object>[];
      final PairingRig rig = buildPairingRig(pollsBeforeJoin: _neverJoins);
      rig.node.failingCommands.add(pairingRequestCommand);
      await _startWithAHeldRead(rig, escaped);
      rig.node.failingCommands.clear();

      await _guardEscapes(rig.repository.startPairing, escaped);
      await _releaseTheHeldRead(rig);

      expect(escaped, isEmpty);
      expect(rig.repository.findActiveSession(), isNotNull);
      rig.dispose();
    }
  });

  test('${_typePrefix}_is_current_code_property_a_cancelled_code_never_'
      'shows_its_request', () async {
    for (int i = 0; i < _iterations; i += 1) {
      final List<Object> escaped = <Object>[];
      final PairingRig rig = buildPairingRig(pollsBeforeJoin: 0);
      await _startWithAHeldRead(rig, escaped);

      await _guardEscapes(rig.repository.cancelPairing, escaped);
      await _releaseTheHeldRead(rig);

      expect(escaped, isEmpty);
      expect(rig.repository.findActiveSession(), isNull);
      expect(rig.repository.findPendingRequest(), isNull);
      rig.dispose();
    }
  });

  test('${_typePrefix}_is_current_code_property_after_a_restart_only_'
      'the_new_code_is_sent', () async {
    final Random random = seededRandom(78401);

    for (int i = 0; i < _iterations; i += 1) {
      final PairingRig rig = buildPairingRig(
        pollsBeforeJoin: pickOne(random, <int>[0, 1, _neverJoins]),
      );
      final int restarts = 1 + random.nextInt(_largestRestarts);
      for (int start = 0; start < restarts; start += 1) {
        await rig.repository.startPairing();
        await waitForPolls(random.nextInt(3));
      }
      final int codesBefore = rig.node.sentCodes.length;

      await waitForPolls(_quietPolls);

      final List<Object?> laterCodes = rig.node.sentCodes.sublist(codesBefore);
      expect(laterCodes, everyElement(rig.node.currentCode));
      rig.dispose();
    }
  });

  test('${_typePrefix}_dispose_property_stops_polling_in_every_'
      'state', () async {
    final Random random = seededRandom(78402);

    for (int i = 0; i < _iterations; i += 1) {
      final PairingRig rig = buildPairingRig(
        pollsBeforeJoin: random.nextInt(_largestPollsBeforeJoin),
      );
      await _bringTo(rig, pickOne(random, _PairingState.values));

      rig.dispose();
      final int commandsAtDispose = rig.node.commandNames.length;
      await waitForPolls(_quietPolls);

      expect(rig.node.commandNames.length, commandsAtDispose);
    }
  });

  test('${_typePrefix}_dispose_property_a_late_read_stays_quiet', () async {
    for (int i = 0; i < _iterations; i += 1) {
      final List<Object> escaped = <Object>[];
      final PairingRig rig = buildPairingRig(pollsBeforeJoin: 0);
      await _startWithAHeldRead(rig, escaped);

      rig.dispose();
      await _releaseTheHeldRead(rig);

      expect(escaped, isEmpty);
      expect(rig.repository.findPendingRequest(), isNull);
    }
  });

  test('${_typePrefix}_dispose_property_forgets_the_session', () async {
    final Random random = seededRandom(78403);

    for (int i = 0; i < _iterations; i += 1) {
      final PairingRig rig = buildPairingRig(pollsBeforeJoin: 0);
      await _bringTo(rig, pickOne(random, _PairingState.values));

      rig.dispose();

      expect(rig.repository.findActiveSession(), isNull);
      expect(rig.repository.findPendingRequest(), isNull);
      expect(rig.repository.findWaitingJoin(), isNull);
    }
  });
}
