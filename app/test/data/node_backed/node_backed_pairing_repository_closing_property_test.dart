import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/pairing.dart';

import '../../support/random_inputs.dart';
import 'support/node_backed_pairing_rig.dart';
import 'support/simulated_pairing_node.dart';

const String _typePrefix = 'test_node_backed_pairing_repository';
const int _iterations = 15;
const int _quietPolls = 5;
const int _largestRestarts = 3;
const List<WorkspaceId> _homeWorkspaces = <WorkspaceId>[WorkspaceId('home')];

enum _Closing { approve, reject, cancel }

Future<void> _close(PairingRig rig, _Closing closing) async {
  switch (closing) {
    case _Closing.approve:
      await rig.repository.approvePairing(_homeWorkspaces);
    case _Closing.reject:
      await rig.repository.rejectPairing();
    case _Closing.cancel:
      await rig.repository.cancelPairing();
  }
}

String _commandOfClosing(_Closing closing) {
  return switch (closing) {
    _Closing.approve => approvePairingCommand,
    _Closing.reject => rejectPairingCommand,
    _Closing.cancel => cancelPairingCommand,
  };
}

void main() {
  test('${_typePrefix}_close_session_property_every_decision_clears_'
      'and_notifies', () async {
    final Random random = seededRandom(78208);

    for (int i = 0; i < _iterations; i += 1) {
      final PairingRig rig = buildPairingRig(pollsBeforeJoin: 0);
      await startAndWaitForRequest(rig);
      final int notificationsBefore = rig.notifications.count;

      await _close(rig, pickOne(random, _Closing.values));

      expect(rig.repository.findActiveSession(), isNull);
      expect(rig.repository.findPendingRequest(), isNull);
      expect(rig.notifications.count, greaterThan(notificationsBefore));
      rig.dispose();
    }
  });

  test('${_typePrefix}_close_session_property_stops_polling', () async {
    final Random random = seededRandom(78209);

    for (int i = 0; i < _iterations; i += 1) {
      final PairingRig rig = buildPairingRig(pollsBeforeJoin: 0);
      await startAndWaitForRequest(rig);
      final _Closing closing = pickOne(random, _Closing.values);

      await _close(rig, closing);
      final int commandsAfterClose = rig.node.commandNames.length;
      final int notificationsAfterClose = rig.notifications.count;
      await waitForPolls(_quietPolls);

      expect(rig.node.commandNames.length, commandsAfterClose);
      expect(rig.notifications.count, notificationsAfterClose);
      expect(rig.node.countCommands(_commandOfClosing(closing)), 1);
      rig.dispose();
    }
  });

  test('${_typePrefix}_close_session_property_a_new_start_polls_'
      'again', () async {
    final Random random = seededRandom(78210);

    for (int i = 0; i < _iterations; i += 1) {
      final PairingRig rig = buildPairingRig(pollsBeforeJoin: 0);
      await startAndWaitForRequest(rig);
      await _close(rig, pickOne(random, _Closing.values));

      await startAndWaitForRequest(rig);

      expect(
        rig.repository.findPendingRequest()?.codeUsed,
        rig.node.currentDisplayCode,
      );
      rig.dispose();
    }
  });

  test('${_typePrefix}_close_session_of_code_property_a_late_cancel_'
      'keeps_a_newer_session', () async {
    await expectANewerSessionSurvives(
      (PairingRig rig) => rig.repository.cancelPairing(),
      cancelPairingCommand,
    );
  });

  test('${_typePrefix}_close_session_of_code_property_a_late_approval_'
      'still_returns_the_device', () async {
    for (int i = 0; i < _iterations; i += 1) {
      final PairingRig rig = buildPairingRig(pollsBeforeJoin: 0);
      await startAndWaitForRequest(rig);
      rig.transport.holdNextReply(approvePairingCommand);
      final Future<Device> approving = rig.repository.approvePairing(
        _homeWorkspaces,
      );
      await rig.transport.heldReplyArrival;
      await rig.repository.startPairing();

      rig.transport.releaseHeldReply();
      final Device device = await approving;

      expect(device.sealingPublicKey, orderedEquals(simulatedJoiningKey));
      expect(rig.repository.findActiveSession(), isNotNull);
      rig.dispose();
    }
  });

  test('${_typePrefix}_close_session_of_code_property_the_shown_code_'
      'closes', () async {
    final Random random = seededRandom(78211);

    for (int i = 0; i < _iterations; i += 1) {
      final PairingRig rig = buildPairingRig(pollsBeforeJoin: 0);
      final int restarts = 1 + random.nextInt(_largestRestarts);
      for (int start = 0; start < restarts; start += 1) {
        await startAndWaitForRequest(rig);
      }
      final PairingSession? shown = rig.repository.findActiveSession();

      await _close(rig, pickOne(random, _Closing.values));

      expect(shown?.code, rig.node.currentDisplayCode);
      expect(rig.repository.findActiveSession(), isNull);
      expect(rig.repository.findPendingRequest(), isNull);
      rig.dispose();
    }
  });
}
