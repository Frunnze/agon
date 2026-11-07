import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/pairing.dart';

import '../../support/random_inputs.dart';
import 'support/node_backed_pairing_rig.dart';
import 'support/pairing_repository_harness.dart';
import 'support/simulated_pairing_node.dart';

const String _typePrefix = 'test_node_backed_pairing_repository';
const int _iterations = 15;
const int _neverJoins = 1000000;
const int _largestLabelCount = 4;
const int _largestPollsBeforeJoin = 3;
const int _quietPolls = 5;
const int _largestSecondsAround = 900;
const Duration _oneMicrosecond = Duration(microseconds: 1);

List<String> _randomLabels(Random random) {
  final int count = random.nextInt(_largestLabelCount + 1);
  return <String>[for (int i = 0; i < count; i += 1) randomText(random)];
}

Future<PairingOutcome> _joinWithValidName(PairingRig rig) {
  return rig.repository.joinWithCode(
    serverAddress: null,
    code: simulatedDisplayCode,
    deviceName: 'joining-phone',
    role: DeviceRole.runner,
  );
}

void main() {
  test('${_typePrefix}_constructor_property_starts_with_nothing_'
      'showing', () async {
    final Random random = seededRandom(78101);

    for (int i = 0; i < _iterations; i += 1) {
      final PairingRig rig = buildPairingRig(
        pollsBeforeJoin: random.nextInt(_largestPollsBeforeJoin),
        runnerLabels: _randomLabels(random),
      );

      await waitForPolls(_quietPolls);

      expect(rig.repository.findActiveSession(), isNull);
      expect(rig.repository.findPendingRequest(), isNull);
      expect(rig.repository.findWaitingJoin(), isNull);
      expect(rig.node.commandNames, isEmpty);
      expect(rig.notifications.count, 0);
      rig.dispose();
    }
  });

  test('${_typePrefix}_constructor_property_keeps_its_own_copy_of_the_'
      'labels', () async {
    final Random random = seededRandom(78102);

    for (int i = 0; i < _iterations; i += 1) {
      final List<String> labels = _randomLabels(random);
      final List<String> expected = List<String>.of(labels);
      final PairingRig rig = buildPairingRig(
        pollsBeforeJoin: 0,
        runnerLabels: labels,
      );
      labels.add(randomText(random));

      final PairingOutcome outcome = await rig.repository.createHostedAccount(
        workspaceName: 'home',
        deviceName: 'laptop',
        role: pickOne(random, DeviceRole.values),
      );

      expect(outcome.runnerLabels, orderedEquals(expected));
      rig.dispose();
    }
  });

  test('${_typePrefix}_constructor_property_labels_reach_every_join_'
      'outcome', () async {
    final Random random = seededRandom(78103);

    for (int i = 0; i < _iterations; i += 1) {
      final List<String> labels = _randomLabels(random);
      final PairingRig rig = buildPairingRig(
        pollsBeforeJoin: 0,
        joinPollsBeforeAnswer: random.nextInt(2),
        runnerLabels: labels,
      );

      final PairingOutcome outcome = await _joinWithValidName(rig);

      expect(outcome.runnerLabels, orderedEquals(labels));
      rig.dispose();
    }
  });

  test('${_typePrefix}_find_active_session_property_live_exactly_before_'
      'expiry', () async {
    final Random random = seededRandom(78104);

    for (int i = 0; i < _iterations; i += 1) {
      final PairingRig rig = buildPairingRig(pollsBeforeJoin: _neverJoins);
      final PairingSession started = await rig.repository.startPairing();
      final int seconds =
          random.nextInt(_largestSecondsAround * 2) - _largestSecondsAround;
      final DateTime moment = started.createdAt.add(
        Duration(seconds: seconds),
      );

      rig.clock.moment = moment;
      final bool isLive = started.expiresAt.isAfter(moment);
      expect(rig.repository.findActiveSession() != null, isLive);

      rig.clock.moment = started.expiresAt;
      expect(rig.repository.findActiveSession(), isNull);
      rig.clock.moment = started.expiresAt.subtract(_oneMicrosecond);
      expect(rig.repository.findActiveSession(), isNotNull);
      rig.dispose();
    }
  });

  test('${_typePrefix}_find_active_session_property_is_the_started_'
      'session', () async {
    final Random random = seededRandom(78105);

    for (int i = 0; i < _iterations; i += 1) {
      final PairingRig rig = buildPairingRig(pollsBeforeJoin: _neverJoins);
      final int startCount = 1 + random.nextInt(3);
      PairingSession? started;
      for (int start = 0; start < startCount; start += 1) {
        started = await rig.repository.startPairing();
      }

      final PairingSession? shown = rig.repository.findActiveSession();

      expect(shown?.code, rig.node.currentDisplayCode);
      expect(shown?.code, started?.code);
      expect(shown?.createdAt, started?.createdAt);
      expect(shown?.expiresAt, started?.expiresAt);
      rig.dispose();
    }
  });

  test('${_typePrefix}_find_active_session_property_reading_changes_'
      'nothing', () async {
    final Random random = seededRandom(78106);

    for (int i = 0; i < _iterations; i += 1) {
      final PairingRig rig = buildPairingRig(pollsBeforeJoin: _neverJoins);
      if (random.nextBool()) {
        await rig.repository.startPairing();
      }
      final int commandsBefore = rig.node.commandNames.length;
      final int notificationsBefore = rig.notifications.count;
      final PairingSession? first = rig.repository.findActiveSession();
      final int readCount = 1 + random.nextInt(5);

      for (int read = 0; read < readCount; read += 1) {
        expect(identical(rig.repository.findActiveSession(), first), isTrue);
      }

      expect(rig.node.commandNames.length, commandsBefore);
      expect(rig.notifications.count, notificationsBefore);
      rig.dispose();
    }
  });

  test('${_typePrefix}_find_pending_request_property_shows_after_the_'
      'joining_poll', () async {
    final Random random = seededRandom(78107);

    for (int i = 0; i < _iterations; i += 1) {
      final int pollsBeforeJoin = random.nextInt(_largestPollsBeforeJoin);
      final PairingRig rig = buildPairingRig(pollsBeforeJoin: pollsBeforeJoin);

      await startAndWaitForRequest(rig);

      final PairingRequest? request = rig.repository.findPendingRequest();
      expect(request?.codeUsed, rig.node.currentDisplayCode);
      expect(request?.deviceName, 'joining-phone');
      expect(
        rig.node.countCommands(pairingRequestCommand),
        pollsBeforeJoin + 1,
      );
      rig.dispose();
    }
  });

  test('${_typePrefix}_find_pending_request_property_stays_and_polling_'
      'stops', () async {
    for (int i = 0; i < _iterations; i += 1) {
      final PairingRig rig = buildPairingRig(pollsBeforeJoin: 0);
      await startAndWaitForRequest(rig);
      final PairingRequest? first = rig.repository.findPendingRequest();
      final int pollsAtRequest = rig.node.countCommands(pairingRequestCommand);

      await waitForPolls(_quietPolls);

      expect(identical(rig.repository.findPendingRequest(), first), isTrue);
      expect(rig.node.countCommands(pairingRequestCommand), pollsAtRequest);
      rig.dispose();
    }
  });

  test('${_typePrefix}_find_pending_request_property_a_new_code_starts_'
      'without_one', () async {
    final Random random = seededRandom(78109);

    for (int i = 0; i < _iterations; i += 1) {
      final PairingRig rig = buildPairingRig(
        pollsBeforeJoin: random.nextInt(_largestPollsBeforeJoin),
      );
      await startAndWaitForRequest(rig);

      await rig.repository.startPairing();

      expect(rig.repository.findPendingRequest(), isNull);
      await waitUntil(() => rig.repository.findPendingRequest() != null);
      expect(
        rig.repository.findPendingRequest()?.codeUsed,
        rig.node.currentDisplayCode,
      );
      rig.dispose();
    }
  });
}
