import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/node/node_command_failure.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/pairing.dart';

import '../../support/random_inputs.dart';
import 'support/node_backed_pairing_rig.dart';
import 'support/pairing_repository_harness.dart';
import 'support/simulated_node_replies.dart';
import 'support/simulated_pairing_node.dart';

const String _typePrefix = 'test_node_backed_pairing_repository';
const int _iterations = 12;
const int _neverJoins = 1000000;
const int _quietPolls = 6;
const int _largestPollsBeforeJoin = 3;
const int _largestFailedReads = 3;

Future<PairingSession> _startCatchingEscapes(
  PairingRig rig,
  List<Object> escaped,
) {
  return runZonedGuarded<Future<PairingSession>>(
    rig.repository.startPairing,
    (Object error, StackTrace _) => escaped.add(error),
  )!;
}

void _expectRequestNamesTheShownCode(PairingRig rig) {
  final PairingRequest? request = rig.repository.findPendingRequest();
  if (request == null) {
    return;
  }
  expect(request.codeUsed, rig.repository.findActiveSession()?.code);
}

void main() {
  test('${_typePrefix}_tick_countdown_property_notifies_while_live_with_'
      'a_request', () async {
    for (int i = 0; i < _iterations; i += 1) {
      final PairingRig rig = buildPairingRig(pollsBeforeJoin: 0);
      await startAndWaitForRequest(rig);
      final int notificationsAtRequest = rig.notifications.count;

      await waitForPolls(_quietPolls);

      expect(rig.notifications.count, greaterThan(notificationsAtRequest));
      rig.dispose();
    }
  });

  test('${_typePrefix}_tick_countdown_property_goes_quiet_after_'
      'expiry', () async {
    final Random random = seededRandom(78301);

    for (int i = 0; i < _iterations; i += 1) {
      final PairingRig rig = buildPairingRig(
        pollsBeforeJoin: pickOne(random, <int>[0, _neverJoins]),
      );
      final PairingSession session = await rig.repository.startPairing();
      rig.clock.moment = session.expiresAt.add(
        Duration(seconds: random.nextInt(60)),
      );
      await waitForPolls(_quietPolls);
      final int notificationsAtExpiry = rig.notifications.count;
      final int commandsAtExpiry = rig.node.commandNames.length;

      await waitForPolls(_quietPolls);

      expect(rig.repository.findActiveSession(), isNull);
      expect(rig.notifications.count, notificationsAtExpiry);
      expect(rig.node.commandNames.length, commandsAtExpiry);
      rig.dispose();
    }
  });

  test('${_typePrefix}_tick_countdown_property_reads_one_request_at_a_'
      'time', () async {
    for (int i = 0; i < _iterations; i += 1) {
      final PairingRig rig = buildPairingRig(pollsBeforeJoin: _neverJoins);
      rig.transport.holdNextReply(pairingRequestCommand);
      await rig.repository.startPairing();
      await rig.transport.heldReplyArrival;

      await waitForPolls(_quietPolls);
      expect(rig.node.countCommands(pairingRequestCommand), 1);

      rig.transport.releaseHeldReply();
      await waitUntil(() => rig.node.countCommands(pairingRequestCommand) > 1);
      rig.dispose();
    }
  });

  test('${_typePrefix}_read_pairing_request_property_maps_the_joining_'
      'device', () async {
    final Random random = seededRandom(78302);

    for (int i = 0; i < _iterations; i += 1) {
      final PairingRig rig = buildPairingRig(
        pollsBeforeJoin: random.nextInt(_largestPollsBeforeJoin),
      );

      await startAndWaitForRequest(rig);

      final PairingRequest? request = rig.repository.findPendingRequest();
      expect(request?.deviceName, 'joining-phone');
      expect(request?.role, DeviceRole.runner);
      expect(request?.keyKind, HardwareKeyKind.secureEnclave);
      expect(request?.fingerprintWords, orderedEquals(simulatedWords));
      expect(request?.codeUsed, rig.node.currentDisplayCode);
      expect(request?.link, isNull);
      rig.dispose();
    }
  });

  test('${_typePrefix}_read_pairing_request_property_a_shown_request_'
      'names_the_shown_code', () async {
    final Random random = seededRandom(78303);

    for (int i = 0; i < _iterations; i += 1) {
      final PairingRig rig = buildPairingRig(pollsBeforeJoin: 0);
      final bool holdsTheFirstRead = random.nextBool();
      if (holdsTheFirstRead) {
        rig.transport.holdNextReply(pairingRequestCommand);
      }
      await rig.repository.startPairing();
      if (holdsTheFirstRead) {
        await rig.transport.heldReplyArrival;
      }

      await rig.repository.startPairing();
      _expectRequestNamesTheShownCode(rig);
      if (holdsTheFirstRead) {
        rig.transport.releaseHeldReply();
      }

      for (int poll = 0; poll < _quietPolls; poll += 1) {
        await waitForPolls(1);
        _expectRequestNamesTheShownCode(rig);
      }
      await waitUntil(() => rig.repository.findPendingRequest() != null);
      _expectRequestNamesTheShownCode(rig);
      rig.dispose();
    }
  });

  test('${_typePrefix}_read_pairing_request_property_failures_escape_'
      'translated', () async {
    for (int i = 0; i < _iterations; i += 1) {
      final List<Object> escaped = <Object>[];
      final PairingRig rig = buildPairingRig(pollsBeforeJoin: 0);
      rig.node.failingCommands.add(pairingRequestCommand);

      await _startCatchingEscapes(rig, escaped);
      await waitUntil(() => escaped.isNotEmpty);

      for (final Object error in escaped) {
        expect(error, isNot(isA<NodeCommandFailure>()));
        expect(
          error,
          isA<StateError>().having(
            (StateError failure) => failure.message,
            'message',
            simulatedOutageMessage,
          ),
        );
      }
      rig.dispose();
    }
  });

  test('${_typePrefix}_finish_reading_request_property_reading_resumes_'
      'after_failures', () async {
    final Random random = seededRandom(78304);

    for (int i = 0; i < _iterations; i += 1) {
      final List<Object> escaped = <Object>[];
      final int failedReads = 1 + random.nextInt(_largestFailedReads);
      final PairingRig rig = buildPairingRig(pollsBeforeJoin: 0);
      rig.node.failingCommands.add(pairingRequestCommand);

      await _startCatchingEscapes(rig, escaped);
      await waitUntil(() => escaped.length >= failedReads);
      rig.node.failingCommands.clear();

      await waitUntil(() => rig.repository.findPendingRequest() != null);
      expect(rig.repository.findActiveSession(), isNotNull);
      rig.dispose();
    }
  });

  test('${_typePrefix}_finish_reading_request_property_every_empty_read_'
      'is_followed_by_another', () async {
    final Random random = seededRandom(78305);

    for (int i = 0; i < _iterations; i += 1) {
      final int pollsBeforeJoin = random.nextInt(_largestPollsBeforeJoin + 2);
      final PairingRig rig = buildPairingRig(pollsBeforeJoin: pollsBeforeJoin);

      await startAndWaitForRequest(rig);

      expect(
        rig.node.countCommands(pairingRequestCommand),
        pollsBeforeJoin + 1,
      );
      rig.dispose();
    }
  });

  test('${_typePrefix}_finish_reading_request_property_a_late_old_read_'
      'lets_the_new_code_read', () async {
    for (int i = 0; i < _iterations; i += 1) {
      final PairingRig rig = buildPairingRig(pollsBeforeJoin: _neverJoins);
      rig.transport.holdNextReply(pairingRequestCommand);
      await rig.repository.startPairing();
      await rig.transport.heldReplyArrival;
      await rig.repository.startPairing();

      rig.transport.releaseHeldReply();

      await waitUntil(() => rig.node.sentCodes.contains(rig.node.currentCode));
      rig.dispose();
    }
  });
}
