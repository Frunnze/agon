import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/pairing.dart';
import 'package:agent_orchestration/data/repository/pairing_repository.dart';

import '../../support/random_inputs.dart';
import 'support/node_backed_pairing_rig.dart';
import 'support/simulated_node_replies.dart';

const String _typePrefix = 'test_node_backed_pairing_repository';
const int _iterations = 15;
const int _neverJoins = 1000000;
const int _quietPolls = 5;
const int _largestRestarts = 3;
const String _noDeviceWaiting = 'No device is waiting to be paired';
const List<WorkspaceId> _homeWorkspaces = <WorkspaceId>[WorkspaceId('home')];

enum _Decision { approve, reject }

Future<void> _decide(PairingRig rig, _Decision decision) async {
  switch (decision) {
    case _Decision.approve:
      await rig.repository.approvePairing(_homeWorkspaces);
    case _Decision.reject:
      await rig.repository.rejectPairing();
  }
}

String _commandOf(_Decision decision) {
  return switch (decision) {
    _Decision.approve => approvePairingCommand,
    _Decision.reject => rejectPairingCommand,
  };
}

void main() {
  for (final _Decision decision in _Decision.values) {
    final String member = '${decision.name}_pairing';

    test('${_typePrefix}_${member}_property_refuses_once_the_code_'
        'expired', () async {
      final Random random = seededRandom(78201 + decision.index);

      for (int i = 0; i < _iterations; i += 1) {
        final PairingRig rig = buildPairingRig(pollsBeforeJoin: 0);
        await startAndWaitForRequest(rig);
        final PairingSession? session = rig.repository.findActiveSession();
        final int secondsLate = random.nextInt(600);
        rig.clock.moment = session!.expiresAt.add(
          Duration(seconds: secondsLate),
        );
        final PairingRequest? request = rig.repository.findPendingRequest();

        await expectLater(
          _decide(rig, decision),
          throwsA(
            isA<StateError>().having(
              (StateError error) => error.message,
              'message',
              noShowingPairingCode,
            ),
          ),
        );

        expect(rig.node.countCommands(_commandOf(decision)), 0);
        expect(
          identical(rig.repository.findPendingRequest(), request),
          isTrue,
        );
        rig.dispose();
      }
    });

    test('${_typePrefix}_${member}_property_late_reply_keeps_a_newer_'
        'session', () async {
      await expectANewerSessionSurvives(
        (PairingRig rig) => _decide(rig, decision),
        _commandOf(decision),
      );
    });

    test('${_typePrefix}_${member}_property_node_refusal_keeps_the_'
        'session', () async {
      for (int i = 0; i < _iterations; i += 1) {
        final PairingRig rig = buildPairingRig(pollsBeforeJoin: 0);
        await startAndWaitForRequest(rig);
        final PairingSession? session = rig.repository.findActiveSession();
        final PairingRequest? request = rig.repository.findPendingRequest();
        rig.node.failingCommands.add(_commandOf(decision));

        await expectLater(
          _decide(rig, decision),
          throwsA(
            isA<StateError>().having(
              (StateError error) => error.message,
              'message',
              simulatedOutageMessage,
            ),
          ),
        );

        expect(identical(rig.repository.findActiveSession(), session), isTrue);
        expect(
          identical(rig.repository.findPendingRequest(), request),
          isTrue,
        );
        await waitForPolls(_quietPolls);
        expect(rig.repository.findPendingRequest(), isNotNull);
        rig.dispose();
      }
    });
  }

  test('${_typePrefix}_require_pending_join_property_no_request_asks_'
      'nothing', () async {
    final Random random = seededRandom(78205);

    for (int i = 0; i < _iterations; i += 1) {
      final PairingRig rig = buildPairingRig(pollsBeforeJoin: _neverJoins);
      if (random.nextBool()) {
        await rig.repository.startPairing();
      }
      final _Decision decision = pickOne(random, _Decision.values);

      await expectLater(
        _decide(rig, decision),
        throwsA(
          isA<StateError>().having(
            (StateError error) => error.message,
            'message',
            _noDeviceWaiting,
          ),
        ),
      );

      expect(rig.node.countCommands(_commandOf(decision)), 0);
      rig.dispose();
    }
  });

  test('${_typePrefix}_require_pending_join_property_sends_the_current_'
      'code', () async {
    final Random random = seededRandom(78206);

    for (int i = 0; i < _iterations; i += 1) {
      final PairingRig rig = buildPairingRig(pollsBeforeJoin: 0);
      final int restarts = 1 + random.nextInt(_largestRestarts);
      for (int start = 0; start < restarts; start += 1) {
        await startAndWaitForRequest(rig);
      }

      await _decide(rig, pickOne(random, _Decision.values));

      expect(rig.node.sentCodes.last, rig.node.currentCode);
      rig.dispose();
    }
  });

  test('${_typePrefix}_require_pending_join_property_refusal_changes_'
      'nothing', () async {
    final Random random = seededRandom(78207);

    for (int i = 0; i < _iterations; i += 1) {
      final PairingRig rig = buildPairingRig(pollsBeforeJoin: _neverJoins);
      await rig.repository.startPairing();
      final PairingSession? session = rig.repository.findActiveSession();

      await expectLater(
        _decide(rig, pickOne(random, _Decision.values)),
        throwsStateError,
      );

      expect(identical(rig.repository.findActiveSession(), session), isTrue);
      expect(rig.repository.findPendingRequest(), isNull);
      expect(rig.node.countCommands(startPairingCommand), 1);
      rig.dispose();
    }
  });
}
