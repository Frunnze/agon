import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_pairing.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/pairing.dart';
import 'package:agent_orchestration/data/repository/pairing_repository.dart';

import '../../support/random_inputs.dart';
import '../node_backed/support/pairing_repository_harness.dart';
import 'support/pairing_inputs.dart';
import 'support/pairing_steps.dart';
import 'support/refusals.dart';

const String _typePrefix = 'test_fake_pairing_repository';
const String _acceptedOutcome = 'accepted';
const int _largestOffsetSeconds = 600;
const int _largestStepSeconds = 200;
const int _longestSequence = 12;

enum _CodeState { none, live, expired }

enum _Step { start, cancel, approve, reject, advance }

typedef _MovablePairing = ({
  FakePairingRepository pairing,
  FakeDeviceRepository devices,
  MovableClock clock,
});

_MovablePairing _buildMovablePairing({
  required PairingSession? session,
  required PairingRequest? request,
  required DateTime now,
}) {
  final MovableClock clock = MovableClock(now);
  final FakeDeviceRepository devices = FakeDeviceRepository(
    devices: galleryDevices,
    currentDeviceId: GalleryDeviceIds.airLaptop,
    peerAddressProblem: null,
    gitlessFolderPaths: const <String>{},
  );
  final FakePairingRepository pairing = FakePairingRepository(
    session: session,
    request: request,
    clock: clock,
    deviceRepository: devices,
    joinOutcome: galleryPairingOutcome,
    startedPairingRendezvousProblem: null,
  );
  return (pairing: pairing, devices: devices, clock: clock);
}

Duration _randomOffset(Random random) {
  return Duration(
    seconds: random.nextInt(2 * _largestOffsetSeconds) - _largestOffsetSeconds,
  );
}

PairingSession? _sessionIn(_CodeState state, Random random, DateTime now) {
  return switch (state) {
    _CodeState.none => null,
    _CodeState.live => liveSessionAt(now),
    _CodeState.expired => liveSessionAt(
      now
          .subtract(pairingLifetime)
          .subtract(Duration(seconds: random.nextInt(_largestOffsetSeconds))),
    ),
  };
}

String _describeRefusal(Object error) {
  if (error is StateError) {
    return error.message;
  }
  return '$error';
}

String _reportAccepted(Object? outcome) => _acceptedOutcome;

bool _isStateError(Object error) => error is StateError;

Future<String> _describeDecision(
  FakePairingRepository pairing,
  bool isApproval,
) {
  final Future<Object?> deciding = isApproval
      ? pairing.approvePairing(approverWorkspaceIds)
      : pairing.rejectPairing();
  final Future<String> accepted = deciding.then(_reportAccepted);
  return accepted.catchError(_describeRefusal, test: _isStateError);
}

Future<void> _runStep(Random random, _MovablePairing setup, _Step step) {
  final FakePairingRepository pairing = setup.pairing;
  if (step == _Step.advance) {
    setup.clock.moment = setup.clock.moment.add(
      Duration(seconds: random.nextInt(_largestStepSeconds)),
    );
    return Future<void>.value();
  }

  final List<WorkspaceId> chosen = <WorkspaceId>[
    pickOne(random, approverWorkspaceIds),
  ];
  return isRefused(
    () => switch (step) {
      _Step.start => pairing.startPairing(),
      _Step.cancel => pairing.cancelPairing(),
      _Step.approve => pairing.approvePairing(chosen),
      _Step.reject => pairing.rejectPairing(),
      _Step.advance => Future<Object?>.value(),
    },
    isRefusal: isPairingRefusal,
  );
}

void main() {
  test('${_typePrefix}_find_pending_request_property_shown_only_while_'
      'its_code_is_live', () {
    final Random random = seededRandom(81101);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime now = randomPairingMoment(random);
      final PairingSession? session = random.nextInt(4) == 0
          ? null
          : liveSessionAt(now.add(_randomOffset(random)));
      final PairingRequest request = randomPairingRequest(random);
      final _MovablePairing setup = _buildMovablePairing(
        session: session,
        request: request,
        now: now,
      );

      final PairingRequest? shown = setup.pairing.findPendingRequest();

      if (isLiveAt(session, now)) {
        expect(identical(shown, request), isTrue);
      } else {
        expect(shown, isNull, reason: 'session $session at $now');
      }
    }
  });

  test('${_typePrefix}_find_pending_request_property_disappears_exactly_'
      'at_expiry', () {
    final Random random = seededRandom(81102);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime now = randomPairingMoment(random);
      final PairingSession session = liveSessionAt(now);
      final PairingRequest request = randomPairingRequest(random);
      final _MovablePairing setup = _buildMovablePairing(
        session: session,
        request: request,
        now: now,
      );
      final Duration early = Duration(
        microseconds: 1 + random.nextInt(pairingLifetime.inMicroseconds - 1),
      );
      final Duration late = Duration(
        microseconds: random.nextInt(pairingLifetime.inMicroseconds),
      );

      setup.clock.moment = session.expiresAt.subtract(early);
      final PairingRequest? beforeExpiry = setup.pairing.findPendingRequest();
      setup.clock.moment = session.expiresAt.add(late);
      final PairingRequest? afterExpiry = setup.pairing.findPendingRequest();

      expect(identical(beforeExpiry, request), isTrue);
      expect(afterExpiry, isNull);
    }
  });

  test('${_typePrefix}_find_pending_request_property_never_without_a_'
      'live_code_over_random_steps', () async {
    final Random random = seededRandom(81103);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime now = randomPairingMoment(random);
      final _MovablePairing setup = _buildMovablePairing(
        session: liveSessionAt(now),
        request: randomPairingRequest(random),
        now: now,
      );
      final int stepCount = 1 + random.nextInt(_longestSequence);

      for (int index = 0; index < stepCount; index += 1) {
        final _Step step = pickOne(random, _Step.values);
        await _runStep(random, setup, step);

        final bool hasRequest = setup.pairing.findPendingRequest() != null;
        final bool isLive = setup.pairing.findActiveSession() != null;
        expect(hasRequest && !isLive, isFalse, reason: 'after $step');
      }
    }
  });

  test('${_typePrefix}_require_pending_request_property_an_expired_code_'
      'refuses_as_no_code_showing', () async {
    final Random random = seededRandom(81104);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime now = randomPairingMoment(random);
      final _MovablePairing setup = _buildMovablePairing(
        session: _sessionIn(_CodeState.expired, random, now),
        request: random.nextBool() ? randomPairingRequest(random) : null,
        now: now,
      );
      final int deviceCountBefore = setup.devices.listDevices().length;

      final String outcome = await _describeDecision(
        setup.pairing,
        random.nextBool(),
      );

      expect(outcome, noShowingPairingCode);
      expect(setup.devices.listDevices().length, deviceCountBefore);
    }
  });

  test('${_typePrefix}_require_pending_request_property_no_code_or_no_'
      'request_refuses_as_no_device_waiting', () async {
    final Random random = seededRandom(81105);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime now = randomPairingMoment(random);
      final bool hasCode = random.nextBool();
      final _MovablePairing setup = _buildMovablePairing(
        session: hasCode ? liveSessionAt(now) : null,
        request: hasCode || random.nextBool()
            ? null
            : randomPairingRequest(random),
        now: now,
      );
      final int deviceCountBefore = setup.devices.listDevices().length;

      final String outcome = await _describeDecision(
        setup.pairing,
        random.nextBool(),
      );

      expect(outcome, noDeviceWaitingToPair);
      expect(setup.devices.listDevices().length, deviceCountBefore);
    }
  });

  test('${_typePrefix}_require_pending_request_property_refusal_matches_'
      'what_the_screen_shows', () async {
    final Random random = seededRandom(81106);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime now = randomPairingMoment(random);
      final _CodeState codeState = pickOne(random, _CodeState.values);
      final _MovablePairing setup = _buildMovablePairing(
        session: _sessionIn(codeState, random, now),
        request: random.nextBool() ? randomPairingRequest(random) : null,
        now: now,
      );
      final bool isLive = setup.pairing.findActiveSession() != null;
      final bool hasRequest = setup.pairing.findPendingRequest() != null;
      final String expected = switch ((codeState, isLive, hasRequest)) {
        (_CodeState.expired, _, _) => noShowingPairingCode,
        (_, true, true) => _acceptedOutcome,
        _ => noDeviceWaitingToPair,
      };

      final String outcome = await _describeDecision(
        setup.pairing,
        random.nextBool(),
      );

      expect(outcome, expected, reason: '$codeState with $hasRequest');
    }
  });
}
