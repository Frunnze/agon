import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/pairing.dart';

import '../../../support/random_inputs.dart';
import 'pairing_inputs.dart';
import 'refusals.dart';

enum PairingStep { start, cancel, approve, reject }

typedef PairingObservation = ({bool isLive, bool hasRequest});

PairingObservation observePairing(PairingSetup setup) {
  return (
    isLive: setup.pairing.findActiveSession() != null,
    hasRequest: setup.pairing.findPendingRequest() != null,
  );
}

bool isPairingRefusal(Object error) {
  return error is StateError || error is ArgumentError;
}

Future<bool> _runStep(
  PairingSetup setup,
  PairingStep step,
  List<WorkspaceId> workspaces,
) {
  return switch (step) {
    PairingStep.start => isRefused(
      setup.pairing.startPairing,
      isRefusal: isPairingRefusal,
    ),
    PairingStep.cancel => isRefused(
      setup.pairing.cancelPairing,
      isRefusal: isPairingRefusal,
    ),
    PairingStep.approve => isRefused(
      () => setup.pairing.approvePairing(workspaces),
      isRefusal: isPairingRefusal,
    ),
    PairingStep.reject => isRefused(
      setup.pairing.rejectPairing,
      isRefusal: isPairingRefusal,
    ),
  };
}

bool _isAcceptedByModel(PairingStep step, PairingObservation before) {
  return switch (step) {
    PairingStep.start => true,
    PairingStep.cancel => before.isLive,
    PairingStep.approve => before.isLive && before.hasRequest,
    PairingStep.reject => before.isLive && before.hasRequest,
  };
}

PairingObservation _expectedAfter({
  required PairingStep step,
  required PairingObservation before,
  required bool isAccepted,
}) {
  if (!isAccepted) {
    return before;
  }
  if (step == PairingStep.start) {
    return (isLive: true, hasRequest: false);
  }
  return (isLive: false, hasRequest: false);
}

Future<PairingStep> checkRandomPairingStep(
  Random random,
  PairingSetup setup,
) async {
  final PairingStep step = pickOne(random, PairingStep.values);
  final PairingObservation before = observePairing(setup);
  final int notificationsBefore = setup.notifications.count;
  final bool isAccepted = _isAcceptedByModel(step, before);

  final bool isRefused = await _runStep(
    setup,
    step,
    randomApproverWorkspaces(random),
  );

  expect(isRefused, !isAccepted, reason: '$step after $before');
  expect(
    observePairing(setup),
    _expectedAfter(step: step, before: before, isAccepted: isAccepted),
    reason: '$step after $before',
  );
  final int expectedNotifications = isAccepted ? 1 : 0;
  expect(
    setup.notifications.count - notificationsBefore,
    expectedNotifications,
    reason: '$step after $before',
  );
  return step;
}

PairingSetup buildRandomPairingSetup(Random random) {
  final DateTime now = randomPairingMoment(random);
  final PairingSession? session = random.nextBool()
      ? randomPairingSession(random, now)
      : null;
  final PairingRequest? request = random.nextBool()
      ? randomPairingRequest(random)
      : null;
  return buildPairingSetup(session: session, request: request, now: now);
}

Future<void> decidePairingRandomly(Random random, PairingSetup setup) async {
  if (random.nextBool()) {
    await setup.pairing.rejectPairing();
    return;
  }
  await setup.pairing.approvePairing(randomApproverWorkspaces(random));
}
