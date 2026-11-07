import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_pairing.dart';
import 'package:agent_orchestration/data/models/pairing.dart';
import 'package:agent_orchestration/data/repository/pairing_repository.dart';

import '../../support/random_inputs.dart';
import '../fakes/support/pairing_inputs.dart';
import 'support/node_backed_pairing_rig.dart';
import 'support/pairing_repository_harness.dart';

const String _typePrefix = 'test_node_backed_pairing_repository';
const int _sequenceIterations = 12;
const int _longestSequence = 10;
const int _neverJoins = 1000000;
const int _largestStepSeconds = 200;
const int _largestPollsBeforeJoin = 2;
const int _largestSecondsFromExpiry = 300;
const String _acceptedOutcome = 'accepted';
const String _noDeviceWaiting = 'No device is waiting to be paired';
const String _noCodeOutcome = 'StateError: $noShowingPairingCode';

enum _Step { start, cancel, approve, reject, advance, awaitRequest }

typedef _Observation = ({bool isLive, bool hasRequest});

FakePairingRepository _buildFake({
  required MovableClock clock,
  required PairingSession? session,
  required PairingRequest? request,
}) {
  final FakeDeviceRepository devices = FakeDeviceRepository(
    devices: galleryDevices,
    currentDeviceId: GalleryDeviceIds.airLaptop,
    peerAddressProblem: null,
    gitlessFolderPaths: const <String>{},
  );
  return FakePairingRepository(
    session: session,
    request: request,
    clock: clock,
    deviceRepository: devices,
    joinOutcome: galleryPairingOutcome,
    startedPairingRendezvousProblem: null,
  );
}

Future<Object?> _runStep(PairingRepository repository, _Step step) {
  return switch (step) {
    _Step.start => repository.startPairing(),
    _Step.cancel => repository.cancelPairing(),
    _Step.approve => repository.approvePairing(approverWorkspaceIds),
    _Step.reject => repository.rejectPairing(),
    _Step.advance || _Step.awaitRequest => Future<Object?>.value(),
  };
}

String _reportAccepted(Object? stepResult) => _acceptedOutcome;

bool _isStateError(Object error) => error is StateError;

String _describeRefusal(Object error) {
  if (error is StateError) {
    return 'StateError: ${error.message}';
  }
  return '$error';
}

Future<String> _describeOutcome(PairingRepository repository, _Step step) {
  final Future<String> accepted = _runStep(
    repository,
    step,
  ).then(_reportAccepted);
  return accepted.catchError(_describeRefusal, test: _isStateError);
}

_Observation _observe(PairingRepository repository) {
  return (
    isLive: repository.findActiveSession() != null,
    hasRequest: repository.findPendingRequest() != null,
  );
}

String _expectedOutcome(
  _Step step,
  _Observation before, {
  required bool isCodeShown,
}) {
  final bool hasExpiredCode = isCodeShown && !before.isLive;
  return switch (step) {
    _Step.start || _Step.advance || _Step.awaitRequest => _acceptedOutcome,
    _Step.cancel => before.isLive ? _acceptedOutcome : _noCodeOutcome,
    _Step.approve || _Step.reject when hasExpiredCode => _noCodeOutcome,
    _Step.approve ||
    _Step.reject when !before.hasRequest => 'StateError: $_noDeviceWaiting',
    _Step.approve || _Step.reject => _acceptedOutcome,
  };
}

bool _isCodeShownAfter(
  _Step step,
  String outcome, {
  required bool wasCodeShown,
}) {
  if (outcome != _acceptedOutcome) {
    return wasCodeShown;
  }
  return switch (step) {
    _Step.start => true,
    _Step.cancel || _Step.approve || _Step.reject => false,
    _Step.advance || _Step.awaitRequest => wasCodeShown,
  };
}

_Observation _expectedAfter(_Step step, _Observation before, String outcome) {
  if (outcome != _acceptedOutcome) {
    return before;
  }
  return switch (step) {
    _Step.start => (isLive: true, hasRequest: false),
    _Step.cancel ||
    _Step.approve ||
    _Step.reject => (isLive: false, hasRequest: false),
    _Step.advance || _Step.awaitRequest => before,
  };
}

bool _matchesPairingModel({
  required _Observation actual,
  required _Observation expected,
}) {
  if (actual == expected) {
    return true;
  }

  final bool mayJoinMeanwhile = expected.isLive && !expected.hasRequest;
  final bool hasJoinedMeanwhile = actual.isLive && actual.hasRequest;
  return mayJoinMeanwhile && hasJoinedMeanwhile;
}

Future<void> _moveTime(Random random, MovableClock clock) async {
  clock.moment = clock.moment.add(
    Duration(seconds: random.nextInt(_largestStepSeconds)),
  );
  await waitForPolls(2);
}

void main() {
  test('${_typePrefix}_start_pairing_property_agrees_with_the_fake_over_'
      'random_steps', () async {
    final Random random = seededRandom(78701);

    for (int i = 0; i < _sequenceIterations; i += 1) {
      final PairingRig rig = buildPairingRig(pollsBeforeJoin: _neverJoins);
      final FakePairingRepository fake = _buildFake(
        clock: rig.clock,
        session: null,
        request: null,
      );
      final int stepCount = 1 + random.nextInt(_longestSequence);

      for (int index = 0; index < stepCount; index += 1) {
        final _Step step = pickOne(random, _Step.values);
        if (step == _Step.advance) {
          await _moveTime(random, rig.clock);
        }
        final String nodeOutcome = await _describeOutcome(
          rig.repository,
          step,
        );
        final String fakeOutcome = await _describeOutcome(fake, step);

        expect(nodeOutcome, fakeOutcome, reason: '$step');
        expect(_observe(rig.repository), _observe(fake), reason: '$step');
        final PairingSession? nodeSession = rig.repository.findActiveSession();
        final PairingSession? fakeSession = fake.findActiveSession();
        expect(nodeSession?.createdAt, fakeSession?.createdAt);
        expect(nodeSession?.expiresAt, fakeSession?.expiresAt);
      }
      rig.dispose();
      fake.dispose();
    }
  });

  test('${_typePrefix}_cancel_pairing_property_follows_the_pairing_model_'
      'over_random_steps', () async {
    final Random random = seededRandom(78702);

    for (int i = 0; i < _sequenceIterations; i += 1) {
      final PairingRig rig = buildPairingRig(
        pollsBeforeJoin: 1 + random.nextInt(_largestPollsBeforeJoin),
      );
      final int stepCount = 1 + random.nextInt(_longestSequence);
      bool isCodeShown = false;

      for (int index = 0; index < stepCount; index += 1) {
        final _Step step = pickOne(random, _Step.values);
        if (step == _Step.advance) {
          await _moveTime(random, rig.clock);
        }
        final _Observation before = _observe(rig.repository);
        if (step == _Step.awaitRequest && before.isLive) {
          await waitUntil(() => rig.repository.findPendingRequest() != null);
        }
        final _Observation ready = _observe(rig.repository);
        final String expected = _expectedOutcome(
          step,
          ready,
          isCodeShown: isCodeShown,
        );

        final String outcome = await _describeOutcome(rig.repository, step);
        isCodeShown = _isCodeShownAfter(
          step,
          outcome,
          wasCodeShown: isCodeShown,
        );

        expect(outcome, expected, reason: '$step after $ready');
        final _Observation actual = _observe(rig.repository);
        final _Observation expectedAfter = _expectedAfter(
          step,
          ready,
          outcome,
        );
        expect(
          _matchesPairingModel(actual: actual, expected: expectedAfter),
          isTrue,
          reason: '$step after $ready: $actual, expected $expectedAfter',
        );
      }
      rig.dispose();
    }
  });

  test('${_typePrefix}_approve_pairing_property_agrees_with_the_fake_'
      'around_expiry', () async {
    final Random random = seededRandom(78703);

    for (int i = 0; i < _sequenceIterations * 2; i += 1) {
      final PairingRig rig = buildPairingRig(pollsBeforeJoin: 0);
      await startAndWaitForRequest(rig);
      final PairingSession session = rig.repository.findActiveSession()!;
      final FakePairingRepository fake = _buildFake(
        clock: rig.clock,
        session: session,
        request: randomPairingRequest(random),
      );
      final int secondsFromExpiry =
          random.nextInt(_largestSecondsFromExpiry * 2) -
          _largestSecondsFromExpiry;
      rig.clock.moment = session.expiresAt.add(
        Duration(seconds: secondsFromExpiry),
      );
      final _Step decision = pickOne(random, <_Step>[
        _Step.approve,
        _Step.reject,
      ]);

      final String nodeOutcome = await _describeOutcome(
        rig.repository,
        decision,
      );
      final String fakeOutcome = await _describeOutcome(fake, decision);

      expect(nodeOutcome, fakeOutcome);
      expect(_observe(rig.repository), _observe(fake));
      rig.dispose();
      fake.dispose();
    }
  });
}
